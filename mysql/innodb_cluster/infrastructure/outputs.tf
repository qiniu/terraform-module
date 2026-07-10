output "mysql_node_ids" {
  value = {
    for node_key, instance in qiniu_compute_instance.mysql_nodes : node_key => instance.id
  }
}

output "mysql_node_passwords" {
  value = {
    for node_key, password in random_password.mysql_instance_password : node_key => password.result
  }
  sensitive = true
}

output "security_group_id" {
  value = qiniu_compute_security_group.mysql.id
}
