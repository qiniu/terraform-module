output "mysql_primary_endpoint" {
  value       = qiniu_compute_instance.mysql_primary_node.private_ip_addresses[0].ipv4
  description = "MySQL primary node private IP address"
}