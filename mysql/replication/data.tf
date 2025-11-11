data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

locals {
  // 选用的系统镜像ID
  ubuntu_image_id = one([
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ]).id
}

# 为 MySQL 复制用户生成随机密码
resource "random_password" "replication_password" {
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}

locals {
  // MySQL 复制用户名称
  replication_username = var.mysql_replication_username

  // 随机生成的 MySQL 复制用户密码
  replication_password = random_password.replication_password.result
}

# 用于生成资源后缀
resource "random_string" "random_suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

locals {
  // 资源组随机后缀
  cluster_suffix = random_string.random_suffix.result
}
