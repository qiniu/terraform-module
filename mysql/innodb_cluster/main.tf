# Top-level orchestration: infrastructure outputs feed command execution and rendering.

module "mysql_infrastructure" {
  source = "./infrastructure"

  cluster_suffix                = local.cluster_suffix
  cluster_name                  = var.cluster_name
  vpc_id                        = var.vpc_id
  subnet_id                     = var.subnet_id
  image_id                      = local.ubuntu_image_id
  mysql_nodes                   = local.mysql_nodes
  instance_type                 = var.instance_type
  instance_system_disk_size     = var.instance_system_disk_size
  instance_system_disk_type     = var.instance_system_disk_type
  additional_security_group_ids = var.additional_security_group_ids
}

module "mysql_scripts" {
  source = "./scripts"

  mysql_nodes                   = local.mysql_nodes
  mysql_member_hostnames        = local.mysql_member_hostnames
  mysql_private_ips             = local.mysql_private_ips
  cluster_name                  = var.cluster_name
  group_replication_uuid        = random_uuid.group_replication.result
  mysql_admin_username          = var.mysql_admin_username
  mysql_admin_password          = local.mysql_admin_password
  install_mysql_router_on_nodes = var.install_mysql_router_on_db_nodes
}

module "mysql_execution_discovery" {
  source = "./execution/discovery"

  mysql_nodes          = local.mysql_nodes
  mysql_node_ids       = module.mysql_infrastructure.mysql_node_ids
  mysql_node_passwords = module.mysql_infrastructure.mysql_node_passwords
}

module "mysql_execution_cluster" {
  source = "./execution/cluster"

  depends_on = [module.mysql_execution_discovery]

  mysql_nodes                   = local.mysql_nodes
  mysql_node_ids                = module.mysql_infrastructure.mysql_node_ids
  mysql_node_passwords          = module.mysql_infrastructure.mysql_node_passwords
  node_network_commands         = module.mysql_scripts.node_network_commands
  node_setup_commands           = module.mysql_scripts.node_setup_commands
  cluster_reconcile_command     = module.mysql_scripts.cluster_reconcile_command
  router_bootstrap_commands     = module.mysql_scripts.router_bootstrap_commands
  member_remove_commands        = module.mysql_scripts.member_remove_commands
  install_mysql_router_on_nodes = var.install_mysql_router_on_db_nodes
}
