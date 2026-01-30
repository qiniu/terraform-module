# ============================================================================
# OpenClaw Terraform Module - Main Resources
# ============================================================================
# 本模块在七牛云 LAS 上部署 OpenClaw 个人 AI 助手
# 基于七牛云 LAS 社区镜像 OpenClaw，开箱即用
# ============================================================================

# ============================================================================
# 随机后缀（用于资源命名唯一性）
# ============================================================================

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

# 生成 dashboard token
resource "random_password" "dashboard_token" {
  length  = 48
  special = false
  lower   = true
  upper   = true
  numeric = true
}

# ============================================================================
# 数据源：查询 OpenClaw 社区镜像
# ============================================================================

data "qiniu_compute_images" "openclaw" {
  type  = "CustomPublic"
  state = "Available"
}

locals {
  name_prefix = "${var.instance_name_prefix}-${random_string.suffix.result}"

  # 筛选 OpenClaw 镜像，按创建时间降序排序后取最新的
  openclaw_images = sort([
    for img in data.qiniu_compute_images.openclaw.items :
    "${img.created_at}|${img.id}" if can(regex("^OpenClaw-v2026\\.1\\.29", img.name))
  ])

  selected_image_id = length(local.openclaw_images) > 0 ? split("|", local.openclaw_images[length(local.openclaw_images) - 1])[1] : null
}

# ============================================================================
# 计算实例
# ============================================================================

resource "qiniu_compute_instance" "openclaw" {
  name          = local.name_prefix
  instance_type = var.instance_type
  image_id      = local.selected_image_id

  system_disk_size = var.system_disk_size
  system_disk_type = var.system_disk_type

  internet_max_bandwidth = var.internet_max_bandwidth
  internet_charge_type   = var.internet_charge_type

  # root 用户密码
  password = var.root_password

  # 初始化脚本 - 配置用户密码、生成配置文件并启动 Gateway
  user_data = base64encode(templatefile("${path.module}/templates/init.sh.tpl", {
    # openclaw 用户使用与 root 相同的密码
    openclaw_password = var.root_password

    # MaaS 配置（固定使用七牛 MaaS）
    maas_api_key  = var.qiniu_maas_api_key
    default_model = var.default_model

    # Dashboard token
    dashboard_token = random_password.dashboard_token.result

    # 工作空间配置
    gateway_port = var.gateway_port
  }))

  description = "OpenClaw AI Assistant - Managed by Terraform"

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }

  lifecycle {
    # 防止因配置变更导致实例被销毁重建
    ignore_changes = [user_data, instance_type, system_disk_size]

    precondition {
      condition     = local.selected_image_id != null
      error_message = "未找到匹配的 OpenClaw 镜像，请确认当前区域已上架 OpenClaw 社区镜像。"
    }
  }
}
