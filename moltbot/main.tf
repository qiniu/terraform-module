# ============================================================================
# Moltbot Terraform Module - Main Resources
# ============================================================================
# 本模块在七牛云 LAS 上部署 Moltbot 个人 AI 助手
# 基于 Ubuntu 24.04 LTS 官方镜像，自动安装 Node.js 和 Clawdbot
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
# 数据源：查询 Ubuntu 官方镜像
# ============================================================================

data "qiniu_compute_images" "ubuntu" {
  type  = "Official"
  state = "Available"
}

locals {
  # 从环境变量 QINIU_REGION_ID 获取区域 ID
  # 如果环境变量未设置或为空字符串，则为 null
  _env_region_id = try(trimspace(data.external.region_id.result.region_id), "")
  env_region_id  = local._env_region_id != "" ? local._env_region_id : null

  # 优先使用显式传入的 region_id，其次使用环境变量
  effective_region_id = var.region_id != null ? var.region_id : local.env_region_id

  name_prefix = "${var.instance_name_prefix}-${random_string.suffix.result}"

  # 筛选 Ubuntu 24.04 LTS 镜像，并匹配指定区域
  ubuntu_images = [
    for img in data.qiniu_compute_images.ubuntu.items :
    img if img.os_version == "24.04 LTS" && (
      local.effective_region_id == null || img.region_id == local.effective_region_id
    )
  ]

  selected_image_id = length(local.ubuntu_images) > 0 ? local.ubuntu_images[0].id : null
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

  # 初始化脚本 - 安装 Node.js、Clawdbot 并配置 Gateway
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
    # 防止因 user_data 变更导致实例重建
    ignore_changes = [user_data]
  }
}

