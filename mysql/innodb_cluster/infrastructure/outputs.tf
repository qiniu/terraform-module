output "mysql_node_ids" {
  value = {
    for node_key, instance in qiniu_compute_instance.mysql_nodes : node_key => instance.id
  }
}

output "mysql_private_key" {
  value     = qiniu_compute_key_pair.mysql.private_key
  sensitive = true
}
