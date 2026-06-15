variable "gateway_port" {
  type    = number
  default = 18789
}

# 生成 dashboard token
resource "random_password" "dashboard_token" {
  length  = 48
  special = false
  lower   = true
  upper   = true
  numeric = true
}

output "dashboard_token" {
  value = random_password.dashboard_token.result
}

locals {
  gateway_config_json = jsonencode({
    mode = "local"
    auth = {
      mode  = "token"
      token = nonsensitive(random_password.dashboard_token.result)
    }
    port = var.gateway_port
    bind = "lan"
    controlUi = {
      allowedOrigins               = ["*"]
      dangerouslyDisableDeviceAuth = true
    }
  })
}

output "gateway_config_script" {
  value = <<-EOT
#!/bin/bash
set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Configuring OpenClaw gateway..."

GATEWAY_JSON=$(cat <<ENDJSON
${local.gateway_config_json}
ENDJSON
)

openclaw config set gateway --strict-json "$GATEWAY_JSON"

openclaw gateway install || {
    log "WARNING: Failed to install openclaw gateway service."
    exit 1
}

openclaw gateway restart || {
    log "WARNING: Failed to restart openclaw gateway."
    exit 1
}

# 4. 等待服务就绪
ELAPSED=0
while [ $ELAPSED -lt 60 ]; do
    if ss -lntp | grep -q ":${var.gateway_port}"; then
        log "OpenClaw gateway is ready on port ${var.gateway_port}."
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge 60 ]; then
    log "WARNING: Gateway did not start within 60 seconds."
fi

log "OpenClaw gateway configuration completed."
EOT
}
