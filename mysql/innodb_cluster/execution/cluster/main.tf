resource "qiniu_compute_instance_exec" "node_network" {
  for_each    = var.mysql_nodes
  instance_id = var.mysql_node_ids[each.key]
  password    = var.mysql_node_passwords[each.key]
  user        = "root"
  shell       = "bash"
  command     = var.node_network_commands[each.key]
  timeouts { create = "5m" }
}

resource "qiniu_compute_instance_exec" "node_setup" {
  for_each    = var.mysql_nodes
  depends_on  = [qiniu_compute_instance_exec.node_network]
  instance_id = var.mysql_node_ids[each.key]
  password    = var.mysql_node_passwords[each.key]
  user        = "root"
  shell       = "bash"
  command     = var.node_setup_commands[each.key]
  timeouts { create = "30m" }
}

resource "qiniu_compute_instance_exec" "cluster_reconcile" {
  depends_on  = [qiniu_compute_instance_exec.node_setup]
  instance_id = var.mysql_node_ids["01"]
  password    = var.mysql_node_passwords["01"]
  user        = "root"
  shell       = "bash"
  command     = var.cluster_reconcile_command
  timeouts { create = "30m" }
}

resource "qiniu_compute_instance_exec" "mysql_router" {
  for_each    = var.install_mysql_router_on_nodes ? var.mysql_nodes : {}
  depends_on  = [qiniu_compute_instance_exec.cluster_reconcile]
  instance_id = var.mysql_node_ids[each.key]
  password    = var.mysql_node_passwords[each.key]
  user        = "root"
  shell       = "bash"
  command     = var.router_bootstrap_commands[each.key]
  timeouts { create = "20m" }
}

resource "qiniu_compute_instance_exec" "member_lifecycle" {
  for_each                    = { for node_key, node in var.mysql_nodes : node_key => node if node.index > 0 }
  depends_on                  = [qiniu_compute_instance_exec.cluster_reconcile]
  instance_id                 = var.mysql_node_ids[each.key]
  password                    = var.mysql_node_passwords[each.key]
  user                        = "root"
  shell                       = "bash"
  command                     = "true"
  destroy_command             = var.member_remove_commands[each.key]
  continue_on_destroy_failure = false
  timeouts {
    create = "5m"
    delete = "30m"
  }
  lifecycle {
    ignore_changes = [command, destroy_command, password]
  }
}
