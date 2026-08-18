#!/bin/bash
set -e

# CodeAgent Setup Script (Standard Version)
# This script configures CodeAgent with user-provided settings

# Redirect all output to both console and log file
LOG_FILE="/var/log/codeagent_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Variables passed from Terraform
MODEL_API_KEY='${model_api_key}'
GITLAB_BASE_URL='${gitlab_base_url}'
GITLAB_WEBHOOK_SECRET='${gitlab_webhook_secret}'
GITLAB_TOKEN='${gitlab_token}'
CNB_BASE_URL='${cnb_base_url}'
CNB_API_URL='${cnb_api_url}'
CNB_WEBHOOK_SECRET='${cnb_webhook_secret}'
CNB_TOKEN='${cnb_token}'

echo "=========================================="
echo "Starting CodeAgent Standard configuration..."
echo "Log file: $LOG_FILE"
echo "=========================================="

# 1. Update API_KEY in supervisor config
echo "----------------------------------------"
echo "Step 1: Updating API_KEY in supervisor config..."
echo "----------------------------------------"

SUPERVISOR_CONF="/etc/supervisor/conf.d/codeagent.conf"
if [ ! -f "$SUPERVISOR_CONF" ]; then
    echo "ERROR: $SUPERVISOR_CONF not found!"
    echo "Listing /etc/supervisor/conf.d/ contents:"
    ls -la /etc/supervisor/conf.d/ || echo "Directory does not exist"
    exit 1
fi

echo "Found supervisor config at: $SUPERVISOR_CONF"
sed -i.bak "s/\"fake_token\"/\"$MODEL_API_KEY\"/g" "$SUPERVISOR_CONF"
echo "✓ API_KEY updated successfully"

# 2. Install yq if not present
echo "----------------------------------------"
echo "Step 2: Installing yq (YAML processor)..."
echo "----------------------------------------"

if ! command -v yq &> /dev/null; then
    echo "yq not found, installing via apt..."
    apt-get update -qq
    apt-get install -y yq
    echo "✓ yq installed successfully"
else
    echo "✓ yq already installed"
fi

# 3. Update GitLab configuration in codeagent.yaml
echo "----------------------------------------"
echo "Step 3: Updating GitLab configuration..."
echo "----------------------------------------"

CODEAGENT_CONF="/home/codeagent/codeagent/_package/conf/codeagent.yaml"
if [ ! -f "$CODEAGENT_CONF" ]; then
    echo "ERROR: $CODEAGENT_CONF not found!"
    exit 1
fi

echo "Found CodeAgent config at: $CODEAGENT_CONF"

# Check if GitLab configuration is provided
if [ -n "$GITLAB_BASE_URL" ]; then
    echo "Configuring GitLab..."

    # Backup original file
    cp "$CODEAGENT_CONF" "$CODEAGENT_CONF.bak"

    # Use yq to update GitLab configuration
    yq -i -y ".platforms.gitlab.instances.com.base_url = \"$GITLAB_BASE_URL\"" "$CODEAGENT_CONF"
    echo "✓ Updated base_url to: $GITLAB_BASE_URL"

    # Update webhook_secret if provided
    if [ -n "$GITLAB_WEBHOOK_SECRET" ]; then
        yq -i -y ".platforms.gitlab.instances.com.webhook_secret = \"$GITLAB_WEBHOOK_SECRET\"" "$CODEAGENT_CONF"
        echo "✓ Updated webhook_secret"
    fi

    # Update token if provided
    if [ -n "$GITLAB_TOKEN" ]; then
        yq -i -y ".platforms.gitlab.instances.com.token = \"$GITLAB_TOKEN\"" "$CODEAGENT_CONF"
        echo "✓ Updated GitLab token"
    fi

    echo "✓ GitLab configuration updated successfully"
else
    echo "No GitLab configuration provided, skipping..."
fi

# 4. Update CNB platform configuration in codeagent.yaml
echo "----------------------------------------"
echo "Step 4: Updating CNB platform configuration..."
echo "----------------------------------------"

# Check if CNB configuration is provided
if [ -n "$CNB_BASE_URL" ] && [ -n "$CNB_API_URL" ]; then
    echo "Configuring CNB platform..."

    # Backup if not already backed up
    if [ ! -f "$CODEAGENT_CONF.bak.cnb" ]; then
        cp "$CODEAGENT_CONF" "$CODEAGENT_CONF.bak.cnb"
    fi

    # Use yq to update CNB configuration
    yq -i -y ".platforms.cnb.instances.cool.base_url = \"$CNB_BASE_URL\"" "$CODEAGENT_CONF"
    yq -i -y ".platforms.cnb.instances.cool.api_url = \"$CNB_API_URL\"" "$CODEAGENT_CONF"
    yq -i -y ".platforms.cnb.instances.cool.webhook_secret = \"$CNB_WEBHOOK_SECRET\"" "$CODEAGENT_CONF"
    yq -i -y ".platforms.cnb.instances.cool.token = \"$CNB_TOKEN\"" "$CODEAGENT_CONF"

    echo "✓ CNB configuration updated via yq"
    echo "✓ CNB platform configuration completed"
    echo "  - Base URL: $CNB_BASE_URL"
    echo "  - API URL: $CNB_API_URL"
    echo "  - Webhook secret: [HIDDEN]"
    echo "  - Token: [HIDDEN]"
else
    echo "No CNB configuration provided, skipping..."
fi

# 5. Restart CodeAgent service via supervisor
echo "----------------------------------------"
echo "Step 5: Restarting CodeAgent service..."
echo "----------------------------------------"

if ! command -v supervisorctl &> /dev/null; then
    echo "ERROR: supervisorctl command not found!"
    exit 1
fi

supervisorctl reread 
supervisorctl update
echo "✓ CodeAgent service restarted successfully"

# 6. Verify services
echo "----------------------------------------"
echo "Step 6: Verifying services..."
echo "----------------------------------------"

echo "Supervisor status:"
supervisorctl status codeagent

echo ""
echo "=========================================="
echo "CodeAgent Standard configuration completed!"
echo "=========================================="
echo ""
echo "Service Information:"
echo "  - CodeAgent service is running via Supervisor"
echo "  - Configuration log: $LOG_FILE"
echo ""
echo "Next Steps:"
echo "  1. Check service status: supervisorctl status codeagent"
echo "  2. View service logs: supervisorctl tail -f codeagent"
echo "  3. View setup log: cat $LOG_FILE"
echo "=========================================="
