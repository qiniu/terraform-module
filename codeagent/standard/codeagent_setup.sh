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

# 2. Update GitLab configuration in codeagent.yaml
echo "----------------------------------------"
echo "Step 2: Updating GitLab configuration..."
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

    # Replace base_url (find the line with "base_url: https://gitlab.com" and replace)
    sed -i "s|base_url: https://gitlab.com|base_url: $GITLAB_BASE_URL|g" "$CODEAGENT_CONF"
    echo "✓ Updated base_url to: $GITLAB_BASE_URL"

    # Replace webhook_secret (find the line with webhook_secret and replace the value)
    if [ -n "$GITLAB_WEBHOOK_SECRET" ]; then
        sed -i "s|webhook_secret: \".*\"|webhook_secret: \"$GITLAB_WEBHOOK_SECRET\"|g" "$CODEAGENT_CONF"
        echo "✓ Updated webhook_secret"
    fi

    # Replace token (find the line with token starting with "glpat-" and replace)
    if [ -n "$GITLAB_TOKEN" ]; then
        sed -i "s|token: \"glpat-.*\"|token: \"$GITLAB_TOKEN\"|g" "$CODEAGENT_CONF"
        echo "✓ Updated GitLab token"
    fi

    echo "✓ GitLab configuration updated successfully"
else
    echo "No GitLab configuration provided, skipping..."
fi

# 3. Restart CodeAgent service via supervisor
echo "----------------------------------------"
echo "Step 3: Restarting CodeAgent service..."
echo "----------------------------------------"

if ! command -v supervisorctl &> /dev/null; then
    echo "ERROR: supervisorctl command not found!"
    exit 1
fi

supervisorctl reread 
supervisorctl update
echo "✓ CodeAgent service restarted successfully"

# 4. Verify services
echo "----------------------------------------"
echo "Step 4: Verifying services..."
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
