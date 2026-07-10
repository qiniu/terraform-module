resource "qiniu_compute_instance_exec" "node_network" {
  for_each    = toset(keys(nonsensitive(var.mysql_nodes)))
  instance_id = var.mysql_nodes[each.key].id
  password    = var.mysql_nodes[each.key].password
  user        = "root"
  shell       = "bash"
  command     = local.node_network_commands[each.key]
  timeouts {
    create = "5m"
  }
}

resource "qiniu_compute_instance_exec" "node_setup" {
  for_each    = toset(keys(nonsensitive(var.mysql_nodes)))
  depends_on  = [qiniu_compute_instance_exec.node_network]
  instance_id = var.mysql_nodes[each.key].id
  password    = var.mysql_nodes[each.key].password
  user        = "root"
  shell       = "bash"
  command     = local.node_setup_commands[each.key]
  timeouts {
    create = "30m"
  }
}

resource "qiniu_compute_instance_exec" "cluster_reconcile" {
  depends_on  = [qiniu_compute_instance_exec.node_setup]
  instance_id = var.mysql_nodes["01"].id
  password    = var.mysql_nodes["01"].password
  user        = "root"
  shell       = "bash"
  command     = local.cluster_reconcile_command
  timeouts {
    create = "30m"
  }
}

resource "qiniu_compute_instance_exec" "mysql_router" {
  for_each    = var.install_mysql_router_on_nodes ? toset(keys(nonsensitive(var.mysql_nodes))) : toset([])
  depends_on  = [qiniu_compute_instance_exec.cluster_reconcile]
  instance_id = var.mysql_nodes[each.key].id
  password    = var.mysql_nodes[each.key].password
  user        = "root"
  shell       = "bash"
  command     = local.router_bootstrap_commands[each.key]
  timeouts {
    create = "20m"
  }
}

resource "qiniu_compute_instance_exec" "member_lifecycle" {
  for_each                    = toset([for node_key, node in nonsensitive(var.mysql_nodes) : node_key if node.index > 0])
  depends_on                  = [qiniu_compute_instance_exec.cluster_reconcile]
  instance_id                 = var.mysql_nodes[each.key].id
  password                    = var.mysql_nodes[each.key].password
  user                        = "root"
  shell                       = "bash"
  command                     = "true"
  destroy_command             = local.member_remove_commands[each.key]
  continue_on_destroy_failure = false
  timeouts {
    create = "5m"
    delete = "30m"
  }
  lifecycle {
    ignore_changes = [command, destroy_command, password]
  }
}
