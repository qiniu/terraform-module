#!/bin/bash
set -e

# GitLab Setup Script
# This script configures GitLab with the public IP

LOG_FILE="/var/log/gitlab_setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Variables passed from Terraform
PUBLIC_IP='${public_ip}'

echo "=========================================="
echo "Starting GitLab configuration..."
echo "Log file: $LOG_FILE"
echo "Public IP: $PUBLIC_IP"
echo "=========================================="

# Wait for cloud-init to complete
echo "Waiting for cloud-init to complete..."
cloud-init status --wait || true
echo "Cloud-init completed."

# Update GitLab external_url
echo "----------------------------------------"
echo "Step 1: Updating GitLab external_url..."
echo "----------------------------------------"

GITLAB_CONF="/etc/gitlab/gitlab.rb"
if [ ! -f "$GITLAB_CONF" ]; then
    echo "ERROR: $GITLAB_CONF not found!"
    exit 1
fi

echo "Found GitLab config at: $GITLAB_CONF"
cp "$GITLAB_CONF" "$GITLAB_CONF.bak"

# Replace external_url
sed -i "s|external_url '.*'|external_url 'http://$PUBLIC_IP'|g" "$GITLAB_CONF"
echo "✓ Updated external_url to http://$PUBLIC_IP"

# Reconfigure GitLab
echo "----------------------------------------"
echo "Step 2: Reconfiguring GitLab..."
echo "----------------------------------------"

if ! command -v gitlab-ctl &> /dev/null; then
    echo "ERROR: gitlab-ctl command not found!"
    exit 1
fi

gitlab-ctl reconfigure
echo "✓ GitLab reconfigured successfully"

# Verify GitLab status
echo "----------------------------------------"
echo "Step 3: Verifying GitLab status..."
echo "----------------------------------------"

gitlab-ctl status | head -n 5

echo ""
echo "=========================================="
echo "GitLab configuration completed!"
echo "=========================================="
echo ""
echo "Access Information:"
echo "  - GitLab URL: http://$PUBLIC_IP"
echo ""
echo "Next Steps:"
echo "  1. Wait 5-10 minutes for GitLab to fully start"
echo "  2. Access GitLab at http://$PUBLIC_IP"
echo "  3. Get root password: cat /etc/gitlab/initial_root_password"
echo "=========================================="
