# 随机后缀（用于资源命名唯一性）
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

locals {
  # 实例名称
  instance_name         = "openclaw-${random_string.suffix.result}"
  internal_gateway_port = 18789
}

# 查询 OpenClaw 应用镜像
data "qiniu_compute_images" "openclaw" {
  type  = "Application"
  state = "Available"
}

locals {
  image_name_prefix = "OpenClaw-v2026.5.18"
  # 筛选 OpenClaw 应用镜像，按创建时间降序排序后取最新的
  openclaw_images = sort([
    for img in data.qiniu_compute_images.openclaw.items :
    "${img.created_at}|${img.id}" if startswith(img.name, local.image_name_prefix)
  ])
  selected_image_id = length(local.openclaw_images) > 0 ? split("|", local.openclaw_images[length(local.openclaw_images) - 1])[1] : null
}

resource "qiniu_compute_instance" "openclaw" {
  name          = local.instance_name
  description   = "OpenClaw AI Assistant - Managed by Terraform"
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

locals {
  ssh_endpoint = split(":", qiniu_compute_instance_public_access.ssh_port_forward.endpoints[0].endpoint)
}

# Dashboard HTTP 访问
resource "qiniu_compute_instance_public_access" "gateway_http_proxy" {
  count         = var.expose_dashboard ? 1 : 0
  instance_id   = qiniu_compute_instance.openclaw.id
  internal_port = local.internal_gateway_port
  type          = "HTTPProxy"
}

