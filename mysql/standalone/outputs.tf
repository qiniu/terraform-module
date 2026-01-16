output "mysql_primary_endpoint" {
  value       = format("%s:3306", qiniu_compute_instance.mysql_primary_node.private_ip_addresses[0].ipv4)
  description = "MySQL primary address string in the format: <primary_ip>:<port>"
}

output "mysql_instance_password" {
  value       = random_password.mysql_instance_password.result
  description = "Password for the MySQL instance (randomly generated)"
  sensitive   = true
}

output "mysql_db_password" {
  value       = local.mysql_password
  description = "MySQL database password (user-provided or randomly generated)"
  sensitive   = true
}
