resource "qiniu_compute_instance_exec" "node_network" {
  for_each    = toset(keys(nonsensitive(var.mysql_nodes)))
  instance_id = var.mysql_nodes[each.key].id
  private_key = var.mysql_nodes[each.key].private_key
  user        = "root"
  shell       = "bash"
  command     = local.node_network_commands[each.key]
  timeouts {
    create = "5m"
  }
}

resource "qiniu_compute_instance_exec" "node_packages" {
  for_each    = toset(keys(nonsensitive(var.mysql_nodes)))
  instance_id = var.mysql_nodes[each.key].id
  private_key = var.mysql_nodes[each.key].private_key
  user        = "root"
  shell       = "bash"
  command     = local.node_package_commands[each.key]
  timeouts {
    create = "30m"
  }
}

resource "qiniu_compute_instance_exec" "node_storage" {
  for_each                    = toset(keys(nonsensitive(var.mysql_nodes)))
  depends_on                  = [qiniu_compute_instance_exec.node_packages]
  instance_id                 = var.mysql_nodes[each.key].id
  private_key                 = var.mysql_nodes[each.key].private_key
  user                        = "root"
  shell                       = "bash"
  command                     = local.node_storage_commands[each.key]
  destroy_command             = local.node_storage_destroy_commands[each.key]
  continue_on_destroy_failure = false
  triggers = {
    attachment_id = var.mysql_data_volumes[each.key].attachment_id
  }
  timeouts {
    create = "20m"
    delete = "10m"
  }
}

resource "qiniu_compute_instance_exec" "node_setup" {
  for_each    = toset(keys(nonsensitive(var.mysql_nodes)))
  depends_on  = [qiniu_compute_instance_exec.node_network, qiniu_compute_instance_exec.node_storage]
  instance_id = var.mysql_nodes[each.key].id
  private_key = var.mysql_nodes[each.key].private_key
  user        = "root"
  shell       = "bash"
  command     = local.node_setup_commands[each.key]
  timeouts {
    create = "15m"
  }
}

resource "qiniu_compute_instance_exec" "cluster_reconcile" {
  depends_on  = [qiniu_compute_instance_exec.node_setup]
  instance_id = var.mysql_nodes["01"].id
  private_key = var.mysql_nodes["01"].private_key
  user        = "root"
  shell       = "bash"
  command     = local.cluster_reconcile_command
  timeouts {
    create = "30m"
  }
}

resource "qiniu_compute_instance_exec" "mysql_router" {
  for_each    = toset(keys(nonsensitive(var.mysql_nodes)))
  depends_on  = [qiniu_compute_instance_exec.cluster_reconcile]
  instance_id = var.mysql_nodes[each.key].id
  private_key = var.mysql_nodes[each.key].private_key
  user        = "root"
  shell       = "bash"
  command     = local.router_bootstrap_commands[each.key]
  timeouts {
    create = "20m"
  }
}

resource "qiniu_compute_instance_exec" "member_lifecycle" {
  for_each                    = toset([for node_key in keys(nonsensitive(var.mysql_nodes)) : node_key if node_key != "01"])
  depends_on                  = [qiniu_compute_instance_exec.cluster_reconcile, qiniu_compute_instance_exec.node_storage]
  instance_id                 = var.mysql_nodes[each.key].id
  private_key                 = var.mysql_nodes[each.key].private_key
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
    ignore_changes = [command, destroy_command, private_key]
  }
}
