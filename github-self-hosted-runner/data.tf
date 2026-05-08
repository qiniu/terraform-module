# ==========================================
# 生成资源后缀，避免命名冲突
# ==========================================

resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# ==========================================
# 查询可用的 Ubuntu 镜像
# ==========================================

data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

# ==========================================
# 本地变量定义
# ==========================================

locals {
  # 资源后缀
  runner_suffix = random_string.resource_suffix.result

  # 选用 Ubuntu 24.04 LTS 镜像
  ubuntu_image_id = one([
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ]).id

  # Runner 名称（用户指定或自动生成）
  runner_name = var.runner_name != "" ? var.runner_name : "runner-${local.runner_suffix}"

  # 合并默认标签和用户自定义标签
  runner_labels = concat(
    ["self-hosted", "linux", "x64"],
    var.runner_labels
  )

  # 从 GitHub URL 提取 owner 和 repo
  github_owner = split("/", trimprefix(var.github_repo_url, "https://github.com/"))[0]
  github_repo  = split("/", trimprefix(var.github_repo_url, "https://github.com/"))[1]
}
