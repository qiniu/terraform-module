resource "qiniu_compute_nat_gateway" "default" {
  name        = "mysql-innodb-example-nat"
  description = "NAT gateway for MySQL InnoDB Cluster package installation"
  subnet_id   = qiniu_compute_subnet.default.id
}

resource "qiniu_compute_eip" "nat" {
  name                 = "mysql-innodb-example-nat-eip"
  description          = "EIP for MySQL InnoDB Cluster NAT gateway"
  bandwidth            = var.nat_eip_bandwidth
  internet_charge_type = var.nat_eip_internet_charge_type
  bind_resource_type   = "NatGateway"
  bind_resource_id     = qiniu_compute_nat_gateway.default.id
}

resource "qiniu_compute_snat_rule" "default" {
  name           = "mysql-innodb-example-snat"
  description    = "SNAT for MySQL InnoDB Cluster package installation"
  nat_gateway_id = qiniu_compute_nat_gateway.default.id
  eip_id         = qiniu_compute_eip.nat.id
  source_cidr    = var.subnet_cidr_block
}

module "mysql_innodb_cluster" {
  source = "../.."

  depends_on = [qiniu_compute_snat_rule.default]

  vpc_id               = qiniu_compute_vpc.default.id
  subnet_id            = qiniu_compute_subnet.default.id
  mysql_node_count     = var.mysql_node_count
  mysql_admin_password = var.mysql_admin_password
  security_group_ids   = [qiniu_compute_security_group.default.id]
}
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
