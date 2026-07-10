resource "qiniu_compute_instance_exec" "node_private_ip" {
  for_each = toset(keys(nonsensitive(var.mysql_nodes)))

  instance_id = var.mysql_nodes[each.key].id
  password    = var.mysql_nodes[each.key].password
  user        = "root"
  shell       = "bash"
  command     = local.node_private_ip_command

  store_stdout = true

  timeouts {
    create = "5m"
    delete = "5m"
  }
}
