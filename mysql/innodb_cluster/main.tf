# Top-level orchestration: infrastructure outputs feed command execution and rendering.

module "mysql_infrastructure" {
  source = "./infrastructure"

  cluster_suffix            = local.cluster_suffix
  cluster_name              = var.cluster_name
  vpc_id                    = var.vpc_id
  subnet_id                 = var.subnet_id
  image_id                  = local.selected_image_id
  mysql_nodes               = local.mysql_nodes
  instance_type             = var.instance_type
  instance_system_disk_size = var.instance_system_disk_size
  instance_system_disk_type = var.instance_system_disk_type
  security_group_ids        = var.security_group_ids
}

module "mysql_execution_discovery" {
  source = "./execution/discovery"

  mysql_nodes = local.mysql_execution_nodes
}

module "mysql_execution_cluster" {
  source = "./execution/cluster"

  depends_on = [module.mysql_execution_discovery]

  mysql_nodes                   = local.mysql_execution_nodes
  mysql_private_ips             = local.mysql_private_ips
  cluster_name                  = var.cluster_name
  group_replication_uuid        = random_uuid.group_replication.result
  mysql_admin_username          = var.mysql_admin_username
  mysql_admin_password          = local.mysql_admin_password
  install_mysql_router_on_nodes = var.install_mysql_router_on_db_nodes
}
