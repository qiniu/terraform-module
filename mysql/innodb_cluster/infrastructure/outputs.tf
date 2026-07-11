output "mysql_node_ids" {
  value = {
    for node_key, instance in qiniu_compute_instance.mysql_nodes : node_key => instance.id
  }
}

output "mysql_private_key" {
  value     = qiniu_compute_key_pair.mysql.private_key
  sensitive = true
}

output "mysql_data_volumes" {
  value = {
    for node_key in sort(keys(var.mysql_nodes)) : node_key => {
      disk_id       = try(local.mysql_data_disk_ids[node_key], "")
      attachment_id = try(qiniu_compute_disk_attachment.mysql_data[node_key].id, "")
    }
  }
}
