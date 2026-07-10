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

module "mysql_innodb_cluster" {
  source = "../.."

  vpc_id               = qiniu_compute_vpc.default.id
  subnet_id            = qiniu_compute_subnet.default.id
  mysql_node_count     = var.mysql_node_count
  mysql_admin_password = var.mysql_admin_password
}
