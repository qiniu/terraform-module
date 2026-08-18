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

output "mysql_primary_instance_password" {
  value       = random_password.mysql_instance_password[0].result
  description = "Password for the MySQL primary instance (randomly generated)"
  sensitive   = true
}

output "mysql_replica_instance_passwords" {
  value = [
    for i in range(var.mysql_replica_count) :
    random_password.mysql_instance_password[i + 1].result
  ]
  description = "List of passwords for MySQL replica instances (randomly generated)"
  sensitive   = true
}

output "mysql_db_password" {
  value       = local.mysql_password
  description = "MySQL database password (user-provided or randomly generated)"
  sensitive   = true
}
