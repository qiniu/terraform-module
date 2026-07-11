module "mysql_innodb_cluster" {
  source = "../.."

  vpc_id               = var.vpc_id
  subnet_id            = var.subnet_id
  mysql_node_count     = var.mysql_node_count
  mysql_admin_password = var.mysql_admin_password
  security_group_ids   = var.security_group_ids
  image_id             = var.image_id
}
