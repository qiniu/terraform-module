# 随机后缀（用于资源命名唯一性）
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

locals {
  # 实例名称
  instance_name = "openclaw-${random_string.suffix.result}"
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

locals {
  gateway_port = 18789
}
