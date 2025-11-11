output "mysql_primary_endpoint" {
  value       = format("%s:3306", qiniu_compute_instance.mysql_primary_node.private_ip_addresses[0].ipv4)
  description = "MySQL primary address string in the format: <primary_ip>:<port>"
}
