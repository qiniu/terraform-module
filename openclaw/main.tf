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
    "${img.created_at}|${img.id}" if startswith(img.name, var.image_name_prefix)
  ])

  selected_image_id = length(local.openclaw_images) > 0 ? split("|", local.openclaw_images[length(local.openclaw_images) - 1])[1] : null

  # 默认情况下 Shared 模式至少需要转发 SSH 端口
  shared_ports_1 = [22]
  # expose_dashboard 时需要额外转发 Gateway 端口
  shared_ports_2 = var.expose_dashboard ? distinct(concat(local.shared_ports_1, [var.gateway_port])) : local.shared_ports_1
  # 再补充上用户自定义端口
  shared_ports_3 = distinct(concat(local.shared_ports_2, tolist(var.extra_port_forwards)))
  # 最终的 Shared 模式端口转发规则列表
  shared_ports_final = local.shared_ports_3
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

  internet_max_bandwidth  = var.internet_max_bandwidth
  internet_charge_type    = var.internet_charge_type
  internet_public_ip_type = var.internet_public_ip_type

  # 计费配置
  cost_charge_type          = var.cost_charge_type
  cost_period               = var.cost_period
  cost_period_unit          = var.cost_period_unit
  cost_discount_activity_id = var.cost_discount_activity_id

  # 端口转发配置：
  dynamic "port_forwards" {
    # 仅 Shared 模式且有端口转发规则时配置 port_forwards，Dedicated 模式不使用 port_forwards 进行端口转发
    for_each = var.internet_public_ip_type == "Shared" ? local.shared_ports_final : []
    content {
      internal_port = port_forwards.value
    }
  }

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
    dashboard_token = random_password.dashboard_token.result

    # Gateway 配置
    gateway_port        = var.gateway_port
    gateway_bind        = var.expose_dashboard ? "lan" : "loopback"
    disable_device_auth = var.disable_device_auth
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

    precondition {
      condition     = var.internet_public_ip_type == "Shared" || length(var.extra_port_forwards) == 0
      error_message = "extra_port_forwards 仅在 internet_public_ip_type 为 Shared 时可配置。请将 internet_public_ip_type 设置为 Shared，或清空 extra_port_forwards。"
    }

    precondition {
      condition     = var.cost_charge_type != "PostPaid" || (var.cost_period == null && var.cost_period_unit == null && var.cost_discount_activity_id == null)
      error_message = "PostPaid 模式下 cost_period、cost_period_unit、cost_discount_activity_id 必须为 null（不设置）。"
    }

    precondition {
      condition     = var.cost_charge_type != "PrePaid" || (var.cost_period != null && var.cost_period_unit != null && var.cost_period >= 1 && var.cost_period <= 36 && contains(["Month", "Year"], var.cost_period_unit))
      error_message = "PrePaid 模式下必须设置 cost_period（1-36）和 cost_period_unit（Month 或 Year）。"
    }
  }
}

# Shared 模式下最后会从资源返回的 port_forwards 中查找外部端口映射
locals {
  ssh_port_forward = [
    for pf in qiniu_compute_instance.openclaw.port_forwards : pf if pf.internal_port == 22
  ]
  gateway_port_forward = [
    for pf in qiniu_compute_instance.openclaw.port_forwards : pf if pf.internal_port == var.gateway_port
  ]
}
