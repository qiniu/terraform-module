# 为 MySQL 复制用户生成随机密码
resource "random_password" "replication_password" {
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}

# 只在用户未提供 mysql_password 时才创建随机密码资源
resource "random_password" "mysql_password" {
  count   = var.mysql_password == null ? 1 : 0
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

  // MySQL 管理员密码（用户提供或随机生成）
  mysql_password = var.mysql_password != null ? var.mysql_password : random_password.mysql_password[0].result
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
