# MySQL InnoDB Cluster over an existing VPC subnet.

resource "qiniu_compute_placement_group" "mysql" {
  name        = format("mysql-innodb-%s", local.cluster_suffix)
  description = format("Placement group for MySQL InnoDB Cluster %s", local.cluster_suffix)
  strategy    = "Spread"
}

resource "qiniu_compute_security_group" "mysql" {
  vpc_id      = var.vpc_id
  name        = format("mysql-innodb-%s", local.cluster_suffix)
  description = format("Security group for MySQL InnoDB Cluster %s", local.cluster_suffix)
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

resource "qiniu_compute_instance" "mysql_nodes" {
  count = var.mysql_node_count

  name                    = local.mysql_member_hostnames[count.index]
  hostname                = local.mysql_member_hostnames[count.index]
  description             = format("MySQL InnoDB Cluster node %02d (%s)", count.index + 1, var.cluster_name)
  instance_type           = var.instance_type
  placement_group_id      = qiniu_compute_placement_group.mysql.id
  image_id                = local.ubuntu_image_id
  system_disk_size        = var.instance_system_disk_size
  system_disk_type        = var.instance_system_disk_type
  state                   = "Running"
  subnet_id               = var.subnet_id
  internet_max_bandwidth  = var.internet_max_bandwidth
  internet_charge_type    = var.internet_charge_type
  internet_public_ip_type = var.internet_max_bandwidth > 0 ? var.internet_public_ip_type : null
  password                = random_password.mysql_instance_password[count.index].result

  security_group_ids = concat(
    [qiniu_compute_security_group.mysql.id],
    var.additional_security_group_ids,
  )

  user_data = base64encode(templatefile("${path.module}/mysql_innodb_node.sh", {
    node_index               = count.index
    server_id                = count.index + 1
    node_hostname            = local.mysql_member_hostnames[count.index]
    bootstrap_hostname       = local.mysql_member_hostnames[0]
    member_hostnames         = join(" ", local.mysql_member_hostnames)
    member_hostnames_json    = jsonencode(local.mysql_member_hostnames)
    group_replication_uuid   = random_uuid.group_replication.result
    group_seeds              = local.mysql_group_seeds
    cluster_name_json        = jsonencode(var.cluster_name)
    mysql_admin_username     = var.mysql_admin_username
    mysql_admin_username_js  = jsonencode(var.mysql_admin_username)
    mysql_admin_password_b64 = base64encode(local.mysql_admin_password)
    mysql_admin_password_js  = jsonencode(local.mysql_admin_password)
    install_mysql_router     = tostring(var.install_mysql_router_on_db_nodes)
  }))

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }

  lifecycle {
    precondition {
      condition     = local.ubuntu_image_id != null
      error_message = "未找到 Ubuntu 24.04 LTS 官方镜像，请确认当前区域已上架该镜像。"
    }
  }
}
