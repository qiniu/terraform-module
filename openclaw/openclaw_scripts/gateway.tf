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
      token = random_password.dashboard_token.result
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
  value = templatefile("${path.module}/templates/gateway.sh.tmpl", {
    gateway_config_json = local.gateway_config_json
    gateway_port        = var.gateway_port
  })
}
