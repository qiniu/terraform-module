# 生成资源后缀，避免命名冲突
resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
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
  standalone_suffix = random_string.resource_suffix.result
  # 如果用户提供了密码则使用用户密码，否则使用随机生成的密码
  mysql_password = var.mysql_password != null ? var.mysql_password : random_password.mysql_password[0].result
}
