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

# 2. Install Python YAML library if not present
echo "----------------------------------------"
echo "Step 2: Installing Python YAML library..."
echo "----------------------------------------"

if ! python3 -c "import ruamel.yaml" &> /dev/null; then
    echo "ruamel.yaml not found, installing via pip..."
    pip3 install ruamel.yaml
    echo "✓ ruamel.yaml installed successfully"
else
    echo "✓ ruamel.yaml already installed"
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

    # Use Python to update GitLab configuration
    python3 <<'EOF'
import os
import sys
from ruamel.yaml import YAML

yaml = YAML()
yaml.preserve_quotes = True
yaml.default_flow_style = False

config_file = os.environ['CODEAGENT_CONF']
gitlab_base_url = os.environ.get('GITLAB_BASE_URL')
gitlab_webhook_secret = os.environ.get('GITLAB_WEBHOOK_SECRET')
gitlab_token = os.environ.get('GITLAB_TOKEN')

try:
    with open(config_file, 'r') as f:
        config = yaml.load(f)

    # Update GitLab base_url
    if gitlab_base_url:
        config['platforms']['gitlab']['instances']['com']['base_url'] = gitlab_base_url

    # Update webhook_secret if provided
    if gitlab_webhook_secret:
        config['platforms']['gitlab']['instances']['com']['webhook_secret'] = gitlab_webhook_secret

    # Update token if provided
    if gitlab_token:
        config['platforms']['gitlab']['instances']['com']['token'] = gitlab_token

    with open(config_file, 'w') as f:
        yaml.dump(config, f)

    print("✓ GitLab configuration updated successfully", file=sys.stderr)
except Exception as e:
    print(f"ERROR: Failed to update GitLab configuration: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    if [ $? -eq 0 ]; then
        echo "✓ Updated base_url: [CONFIGURED]"
        [ -n "$GITLAB_WEBHOOK_SECRET" ] && echo "✓ Updated webhook_secret"
        [ -n "$GITLAB_TOKEN" ] && echo "✓ Updated GitLab token"
    else
        echo "ERROR: Failed to update GitLab configuration"
        exit 1
    fi
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

    # Use Python to update CNB configuration
    python3 <<'EOF'
import os
import sys
from ruamel.yaml import YAML

yaml = YAML()
yaml.preserve_quotes = True
yaml.default_flow_style = False

config_file = os.environ['CODEAGENT_CONF']
cnb_base_url = os.environ.get('CNB_BASE_URL')
cnb_api_url = os.environ.get('CNB_API_URL')
cnb_webhook_secret = os.environ.get('CNB_WEBHOOK_SECRET')
cnb_token = os.environ.get('CNB_TOKEN')

try:
    with open(config_file, 'r') as f:
        config = yaml.load(f)

    # Update CNB required fields
    if cnb_base_url and cnb_api_url:
        config['platforms']['cnb']['instances']['cool']['base_url'] = cnb_base_url
        config['platforms']['cnb']['instances']['cool']['api_url'] = cnb_api_url

        # Update optional fields only if provided
        if cnb_webhook_secret:
            config['platforms']['cnb']['instances']['cool']['webhook_secret'] = cnb_webhook_secret

        if cnb_token:
            config['platforms']['cnb']['instances']['cool']['token'] = cnb_token

    with open(config_file, 'w') as f:
        yaml.dump(config, f)

    print("✓ CNB configuration updated successfully", file=sys.stderr)
except Exception as e:
    print(f"ERROR: Failed to update CNB configuration: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    if [ $? -eq 0 ]; then
        echo "✓ CNB platform configuration completed"
        echo "  - Base URL: [CONFIGURED]"
        echo "  - API URL: [CONFIGURED]"
        [ -n "$CNB_WEBHOOK_SECRET" ] && echo "  - Webhook secret: [CONFIGURED]"
        [ -n "$CNB_TOKEN" ] && echo "  - Token: [CONFIGURED]"
    else
        echo "ERROR: Failed to update CNB configuration"
        exit 1
    fi
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
