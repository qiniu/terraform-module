resource "qiniu_compute_nat_gateway" "default" {
  name        = "mysql-innodb-example-nat"
  description = "NAT gateway for MySQL InnoDB Cluster package installation"
  subnet_id   = var.subnet_id
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

  vpc_id               = var.vpc_id
  subnet_id            = var.subnet_id
  mysql_node_count     = var.mysql_node_count
  mysql_admin_password = var.mysql_admin_password
  security_group_ids   = var.security_group_ids
}
