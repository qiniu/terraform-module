output "mysql_primary_endpoint" {
  value       = qiniu_compute_instance.mysql_primary_node.private_ip_addresses[0].ipv4
  description = "MySQL primary node private IP address"
}

output "mysql_replica_endpoints" {
  value       = [for instance in qiniu_compute_instance.mysql_replication_nodes : instance.private_ip_addresses[0].ipv4]
  description = "MySQL replica nodes private IP addresses"
}
