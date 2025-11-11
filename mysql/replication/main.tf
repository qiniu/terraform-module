# MySQL Replication Cluster Configuration

# 创建置放组
resource "qiniu_compute_placement_group" "mysql_pg" {
  name        = format("mysql-repl-%s", local.cluster_suffix)
  description = format("Placement group for MySQL replication cluster %s", local.cluster_suffix)
  strategy    = "Spread"
}

# 创建 MySQL 主库
resource "qiniu_compute_instance" "mysql_primary_node" {
  instance_type      = var.instance_type
  placement_group_id = qiniu_compute_placement_group.mysql_pg.id
  name               = format("mysql-primary-%s", local.cluster_suffix)
  description        = format("Primary node for MySQL replication cluster %s", local.cluster_suffix)
  image_id           = local.ubuntu_image_id
  system_disk_size   = var.instance_system_disk_size

  user_data = base64encode(templatefile("${path.module}/mysql_master.sh", {
    mysql_server_id            = "1"
    mysql_admin_username       = var.mysql_username
    mysql_admin_password       = var.mysql_password
    mysql_replication_username = local.replication_username
    mysql_replication_password = local.replication_password
    mysql_db_name              = var.mysql_db_name
  }))
}


# 创建 MySQL 从库节点
resource "qiniu_compute_instance" "mysql_replication_nodes" {
  depends_on = [qiniu_compute_instance.mysql_primary_node]

  count              = var.mysql_replica_count
  instance_type      = var.instance_type
  placement_group_id = qiniu_compute_placement_group.mysql_pg.id
  name               = format("mysql-repl-%02d-%s", count.index + 1, local.cluster_suffix)
  description        = format("Replica node %02d for MySQL replication cluster %s", count.index + 1, local.cluster_suffix)
  image_id           = local.ubuntu_image_id
  system_disk_size   = var.instance_system_disk_size

  user_data = base64encode(templatefile("${path.module}/mysql_slave.sh", {
    mysql_master_ip            = qiniu_compute_instance.mysql_primary_node.private_ip_addresses[0].ipv4
    mysql_server_id            = tostring(count.index + 2) // 从库ID从2开始递增
    mysql_replication_username = local.replication_username
    mysql_replication_password = local.replication_password
  }))
}


