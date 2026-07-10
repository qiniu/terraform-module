# 生成资源后缀，避免命名冲突
resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

resource "random_uuid" "group_replication" {}

resource "random_password" "mysql_admin_password" {
  count   = var.mysql_admin_password == null ? 1 : 0
  length  = 16
  lower   = true
  upper   = true
  numeric = true
  special = true

  # 避免生成会干扰 shell、SQL 或 MySQL Shell URI 的字符。
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

locals {
  cluster_suffix       = random_string.resource_suffix.result
  mysql_admin_password = var.mysql_admin_password != null ? var.mysql_admin_password : random_password.mysql_admin_password[0].result
  mysql_node_keys = [
    for i in range(var.mysql_node_count) :
    format("%02d", i + 1)
  ]
  mysql_member_hostnames = [
    for i in range(var.mysql_node_count) :
    format("mysql-innodb-%02d-%s", i + 1, local.cluster_suffix)
  ]
  mysql_nodes = {
    for index, node_key in local.mysql_node_keys : node_key => {
      index    = index
      hostname = local.mysql_member_hostnames[index]
    }
  }
  mysql_private_ips = {
    for node_key in local.mysql_node_keys :
    node_key => module.mysql_execution_discovery.mysql_private_ips[node_key]
  }
}
