resource "qiniu_compute_security_group" "validation_db_access" {
  count = var.enable_validation ? 1 : 0

  vpc_id      = qiniu_compute_vpc.default.id
  name        = format("%s-validation-db-access", var.name_prefix)
  description = "Temporary validation access to MySQL nodes"
}

resource "qiniu_compute_security_group_rule_set" "validation_db_access" {
  count = var.enable_validation ? 1 : 0

  security_group_id = qiniu_compute_security_group.validation_db_access[0].id

  ingress {
    ip_protocol    = "tcp"
    port_range     = "22"
    source_cidr_ip = "0.0.0.0/0"
    description    = "Allow SSH to MySQL nodes during validation"
  }

  egress {
    ip_protocol  = "all"
    port_range   = "all"
    dest_cidr_ip = "0.0.0.0/0"
    description  = "Allow outbound traffic"
  }
}

resource "terraform_data" "mysql_cluster_validation" {
  count = var.enable_validation ? 1 : 0

  depends_on = [
    module.mysql_innodb_cluster,
  ]

  triggers_replace = {
    script_version = 7
    public_ips     = join(",", compact(module.mysql_innodb_cluster.mysql_node_public_ips))
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/validate_mysql_cluster.sh"

    environment = {
      MYSQL_ADMIN_USERNAME     = module.mysql_innodb_cluster.mysql_admin_username
      MYSQL_ADMIN_PASSWORD_B64 = base64encode(module.mysql_innodb_cluster.mysql_admin_password)
      ROUTER_RW_ENDPOINTS      = join(" ", compact([for ip in module.mysql_innodb_cluster.mysql_node_public_ips : ip != null ? format("%s:6446", ip) : ""]))
      ROUTER_RO_ENDPOINTS      = join(" ", compact([for ip in module.mysql_innodb_cluster.mysql_node_public_ips : ip != null ? format("%s:6447", ip) : ""]))
      MYSQL_DIRECT_ENDPOINTS   = join(" ", compact([for ip in module.mysql_innodb_cluster.mysql_node_public_ips : ip != null ? format("%s:3306", ip) : ""]))
      MYSQL_NODE_HOSTNAMES     = join(" ", module.mysql_innodb_cluster.mysql_node_hostnames)
      MYSQL_NODE_SSH_ENDPOINTS = join(" ", compact([for ip in module.mysql_innodb_cluster.mysql_node_public_ips : ip != null ? format("%s:22", ip) : ""]))
      MYSQL_INSTANCE_PASSWORDS = join(" ", [for password in module.mysql_innodb_cluster.mysql_instance_passwords : base64encode(password)])
    }
  }
}
