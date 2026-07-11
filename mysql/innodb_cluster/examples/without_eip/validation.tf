resource "qiniu_compute_instance_exec" "mysql_cluster_validation" {
  count = var.enable_validation ? 1 : 0

  depends_on = [module.mysql_innodb_cluster]

  instance_id = module.mysql_innodb_cluster.mysql_node_instance_ids[0]
  password    = module.mysql_innodb_cluster.mysql_instance_passwords[0]
  user        = "root"
  shell       = "bash"
  command = templatefile("${path.module}/validate_mysql_cluster.sh", {
    bootstrap_hostname       = module.mysql_innodb_cluster.mysql_node_hostnames[0]
    mysql_node_count         = var.mysql_node_count
    mysql_admin_username     = module.mysql_innodb_cluster.mysql_admin_username
    mysql_admin_password_b64 = base64encode(module.mysql_innodb_cluster.mysql_admin_password)
  })

  timeouts {
    create = "20m"
    delete = "5m"
  }
}
