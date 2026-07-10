resource "qiniu_compute_instance_exec" "node_private_ip" {
  for_each = var.mysql_nodes

  instance_id = var.mysql_node_ids[each.key]
  password    = var.mysql_node_passwords[each.key]
  user        = "root"
  shell       = "bash"
  command     = "hostname -I | awk '{print $1}'"

  store_stdout = true

  timeouts {
    create = "5m"
    delete = "5m"
  }
}
