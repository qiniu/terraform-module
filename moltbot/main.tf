# ============================================================================
# Moltbot Terraform Module - Main Resources
# ============================================================================
# 本模块在七牛云 LAS 上部署 Moltbot 个人 AI 助手
# 基于七牛云 LAS 社区镜像 Clawdbot，开箱即用
# ============================================================================

# ============================================================================
# 随机后缀（用于资源命名唯一性）
# ============================================================================

# 读取环境变量 QINIU_REGION_ID
data "external" "region_id" {
  program = ["sh", "-c", "echo '{\"region_id\": \"'\"$QINIU_REGION_ID\"'\"}'"]
}

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
# 数据源：查询 Clawdbot 社区镜像
# ============================================================================

data "qiniu_compute_images" "clawdbot" {
  type  = "CustomPublic"
  state = "Available"
}

locals {
  region_id   = trimspace(data.external.region_id.result.region_id)
  name_prefix = "${var.instance_name_prefix}-${random_string.suffix.result}"

  # 筛选当前区域的 Clawdbot 镜像，按创建时间降序排序后取最新的
  clawdbot_images = sort([
    for img in data.qiniu_compute_images.clawdbot.items :
    "${img.created_at}|${img.id}" if can(regex("^Clawdbot-v2026\\.1\\.", img.name)) && img.region_id == local.region_id
  ])

  selected_image_id = length(local.clawdbot_images) > 0 ? split("|", local.clawdbot_images[length(local.clawdbot_images) - 1])[1] : null
}

# ============================================================================
# 计算实例
# ============================================================================

resource "qiniu_compute_instance" "moltbot" {
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
    # clawd 用户使用与 root 相同的密码
    clawd_password = var.root_password

    # LLM 配置（固定使用七牛 MaaS）
    llm_api_key   = var.qiniu_llm_api_key
    default_model = var.default_model

    # Dashboard token
    dashboard_token = random_password.dashboard_token.result

    # 工作空间配置
    gateway_port = var.gateway_port
  }))

  description = "Moltbot AI Assistant - Managed by Terraform"

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
      error_message = "未找到匹配的 Clawdbot 镜像，请检查 QINIU_REGION_ID 环境变量是否正确配置。"
    }
  }
}

