resource "qiniu_compute_placement_group" "mysql" {
  name        = format("mysql-innodb-%s", var.cluster_suffix)
  description = format("Placement group for MySQL InnoDB Cluster %s", var.cluster_suffix)
  strategy    = "Spread"
}

resource "qiniu_compute_security_group" "mysql" {
  vpc_id      = var.vpc_id
  name        = format("mysql-innodb-%s", var.cluster_suffix)
  description = format("Security group for MySQL InnoDB Cluster %s", var.cluster_suffix)
}

resource "qiniu_compute_security_group_rule_set" "mysql" {
  security_group_id = qiniu_compute_security_group.mysql.id

  ingress {
    ip_protocol    = "tcp"
    port_range     = "3306,33060,33061,6446,6447,6448,6449"
    source_cidr_ip = "0.0.0.0/0"
    description    = "Allow MySQL, Group Replication, and Router traffic in routable networks"
  }

  egress {
    ip_protocol  = "all"
    port_range   = "all"
    dest_cidr_ip = "0.0.0.0/0"
    description  = "Allow outbound traffic"
  }
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

  name                    = each.value.hostname
  hostname                = each.value.hostname
  description             = format("MySQL InnoDB Cluster node %02d (%s)", each.value.index + 1, var.cluster_name)
  instance_type           = var.instance_type
  placement_group_id      = qiniu_compute_placement_group.mysql.id
  image_id                = var.image_id
  system_disk_size        = var.instance_system_disk_size
  system_disk_type        = var.instance_system_disk_type
  state                   = "Running"
  subnet_id               = var.subnet_id
  internet_max_bandwidth  = var.internet_max_bandwidth
  internet_charge_type    = var.internet_charge_type
  internet_public_ip_type = var.internet_max_bandwidth > 0 ? var.internet_public_ip_type : null
  disable_public_ip       = var.internet_max_bandwidth == 0 || var.internet_public_ip_type == "Shared"
  password                = random_password.mysql_instance_password[each.key].result

  security_group_ids = concat(
    [qiniu_compute_security_group.mysql.id],
    var.additional_security_group_ids,
  )

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
