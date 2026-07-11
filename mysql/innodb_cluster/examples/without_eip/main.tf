resource "qiniu_compute_vpc" "default" {
  name        = var.name_prefix
  description = "VPC for MySQL InnoDB Cluster example"
  cidr_block  = var.vpc_cidr_block
}

resource "qiniu_compute_subnet" "default" {
  vpc_id      = qiniu_compute_vpc.default.id
  name        = format("%s-subnet", var.name_prefix)
  description = "Subnet for MySQL InnoDB Cluster example"
  cidr_block  = var.subnet_cidr_block
}

resource "qiniu_compute_security_group" "default" {
  vpc_id      = qiniu_compute_vpc.default.id
  name        = format("%s-sg", var.name_prefix)
  description = "Temporary test security group for MySQL InnoDB Cluster"
}

resource "qiniu_compute_security_group_rule_set" "default" {
  security_group_id = qiniu_compute_security_group.default.id

  ingress {
    ip_protocol    = "tcp"
    port_range     = "3306,33060,33061,6446,6447,6448,6449"
    source_cidr_ip = "0.0.0.0/0"
    description    = "Test-only MySQL cluster traffic"
  }

  egress {
    ip_protocol  = "all"
    port_range   = "all"
    dest_cidr_ip = "0.0.0.0/0"
    description  = "Test-only outbound traffic"
  }
}

module "mysql_innodb_cluster" {
  source = "../.."

  vpc_id               = qiniu_compute_vpc.default.id
  subnet_id            = qiniu_compute_subnet.default.id
  mysql_node_count     = var.mysql_node_count
  mysql_admin_password = var.mysql_admin_password
  security_group_ids   = [qiniu_compute_security_group.default.id]
  image_id             = var.image_id
}
