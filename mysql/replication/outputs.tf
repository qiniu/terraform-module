output "mysql_primary_endpoint" {
  value       = format("%s:3306", qiniu_compute_instance.mysql_primary_node.private_ip_addresses[0].ipv4)
  description = "MySQL primary address string in the format: <primary_ip>:<port>"
}

output "mysql_replica_endpoints" {
  value = [
    for instance in qiniu_compute_instance.mysql_replication_nodes :
    format("%s:3306", instance.private_ip_addresses[0].ipv4)
  ]
  description = "List of MySQL replica endpoints in the format: <replica_ip>:<port>"
}

output "mysql_replication_username" {
  value       = local.replication_username
  description = "MySQL replication username"
}

output "mysql_replication_password" {
  value       = local.replication_password
  description = "MySQL replication password (randomly generated)"
  sensitive   = true
}
