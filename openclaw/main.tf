# ============================================================================
# 计算实例
# ============================================================================

resource "qiniu_compute_instance" "openclaw" {
  name          = local.instance_name
  instance_type = var.instance_type
  image_id      = local.selected_image_id

  system_disk_size = var.system_disk_size
  system_disk_type = var.system_disk_type

  internet_max_bandwidth = var.internet_max_bandwidth
  internet_charge_type   = var.internet_charge_type

  internet_public_ip_type = "Shared" # OpenClaw 目前只支持标准网络实例
  disable_public_ip       = true     # OpenClaw 目前只支持标准网络实例

  # 计费配置
  cost_charge_type          = var.cost_charge_type
  cost_period               = var.cost_period
  cost_period_unit          = var.cost_period_unit
  cost_discount_activity_id = var.cost_discount_activity_id

  # root 用户密码
  password = var.root_password

  # 初始化脚本 - 配置用户密码、生成配置文件并启动 Gateway
  user_data = base64encode(templatefile("${path.module}/templates/init.sh.tpl", {
    # openclaw 用户使用与 root 相同的密码
    openclaw_password = var.root_password

    # MaaS 配置（固定使用七牛 MaaS）
    maas_api_key  = var.qiniu_maas_api_key
    default_model = var.default_model
    wx_secret     = var.wx_secret
    qq_secret     = var.qq_secret

    # Dashboard token
    dashboard_token = local.dashboard_token

    # Gateway 配置
    gateway_port = local.gateway_port
  }))

  description = "OpenClaw AI Assistant - Managed by Terraform"

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }

  lifecycle {
    # 防止因配置变更导致实例被销毁重建
    ignore_changes = [
      instance_type,
      system_disk_type,
      system_disk_size,
    ]

    precondition {
      condition     = local.selected_image_id != null
      error_message = "未找到匹配的 OpenClaw 镜像，请确认当前区域已上架 OpenClaw 社区镜像。"
    }
  }
}

# SSH 端口转发访问
resource "qiniu_compute_instance_public_access" "ssh_port_forward" {
  instance_id   = qiniu_compute_instance.openclaw.id
  internal_port = 22
  type          = "PortForward"
}

# Dashboard HTTP 访问
resource "qiniu_compute_instance_public_access" "gateway_http_proxy" {
  count         = var.expose_dashboard ? 1 : 0
  instance_id   = qiniu_compute_instance.openclaw.id
  internal_port = local.gateway_port
  type          = "HTTPProxy"
}

