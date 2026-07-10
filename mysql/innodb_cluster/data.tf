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
  mysql_nodes = {
    for index, node_key in local.mysql_node_keys : node_key => {
      hostname = format("mysql-innodb-%02d-%s", index + 1, local.cluster_suffix)
    }
  }
  mysql_execution_nodes = {
    for node_key, node in local.mysql_nodes : node_key => merge(node, {
      id       = module.mysql_infrastructure.mysql_node_ids[node_key]
      password = module.mysql_infrastructure.mysql_node_passwords[node_key]
    })
  }
  mysql_private_ips = {
    for node_key in local.mysql_node_keys :
    node_key => module.mysql_execution_discovery.mysql_private_ips[node_key]
  }
}
