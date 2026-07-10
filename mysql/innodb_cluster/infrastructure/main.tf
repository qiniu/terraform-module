resource "qiniu_compute_placement_group" "mysql" {
  name        = format("mysql-innodb-%s", var.cluster_suffix)
  description = format("Placement group for MySQL InnoDB Cluster %s", var.cluster_suffix)
  strategy    = "Spread"
}

resource "random_password" "mysql_instance_password" {
  for_each = var.mysql_nodes
  length   = 16
  lower    = true
  upper    = true
  numeric  = true
  special  = true

  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "qiniu_compute_instance" "mysql_nodes" {
  for_each = var.mysql_nodes

  name               = each.value.hostname
  hostname           = each.value.hostname
  description        = format("MySQL InnoDB Cluster node %s (%s)", each.key, var.cluster_name)
  instance_type      = var.instance_type
  placement_group_id = qiniu_compute_placement_group.mysql.id
  image_id           = var.image_id
  system_disk_size   = var.instance_system_disk_size
  system_disk_type   = var.instance_system_disk_type
  state              = "Running"
  subnet_id          = var.subnet_id
  password           = random_password.mysql_instance_password[each.key].result

  security_group_ids = var.security_group_ids

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }

  lifecycle {
    precondition {
      condition     = var.image_id != null
      error_message = "未找到 Ubuntu 24.04 LTS 官方镜像，请确认当前区域已上架该镜像。"
    }
  }
}
