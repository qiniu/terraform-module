resource "qiniu_compute_vpc" "default" {
  name        = var.name_prefix
  description = "VPC for MySQL InnoDB Cluster demo"
  cidr_block  = var.vpc_cidr_block
}

resource "qiniu_compute_subnet" "default" {
  vpc_id      = qiniu_compute_vpc.default.id
  name        = format("%s-subnet", var.name_prefix)
  description = "Subnet for MySQL InnoDB Cluster demo"
  cidr_block  = var.subnet_cidr_block
}

resource "qiniu_compute_nat_gateway" "default" {
  count = var.enable_nat ? 1 : 0

  subnet_id = qiniu_compute_subnet.default.id

  name        = format("%s-nat", var.name_prefix)
  description = "NAT Gateway for MySQL package installation"
}

resource "qiniu_compute_eip" "nat" {
  count = var.enable_nat ? 1 : 0

  name                 = format("%s-nat-eip", var.name_prefix)
  description          = "EIP bound to NAT Gateway"
  bandwidth            = var.nat_eip_bandwidth
  internet_charge_type = "PeakBandwidth"
  bind_resource_type   = "NatGateway"
  bind_resource_id     = qiniu_compute_nat_gateway.default[0].id
}

resource "qiniu_compute_snat_rule" "default" {
  count = var.enable_nat ? 1 : 0

  nat_gateway_id = qiniu_compute_nat_gateway.default[0].id
  name           = format("%s-snat", var.name_prefix)
  description    = "Allow subnet instances to access the internet through NAT"
  eip_id         = qiniu_compute_eip.nat[0].id
  source_cidr    = qiniu_compute_subnet.default.cidr_block
}

module "mysql_innodb_cluster" {
  source = "../.."

  vpc_id                  = qiniu_compute_vpc.default.id
  subnet_id               = qiniu_compute_subnet.default.id
  mysql_node_count        = var.mysql_node_count
  mysql_admin_password    = var.mysql_admin_password
  internet_max_bandwidth  = var.enable_validation ? 100 : 0
  internet_charge_type    = "PeakBandwidth"
  internet_public_ip_type = "Dedicated"

  additional_security_group_ids = var.enable_validation ? [
    qiniu_compute_security_group.validation_db_access[0].id,
  ] : []
}
