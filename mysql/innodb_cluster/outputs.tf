output "mysql_node_private_ips" {
  value       = [for node_key in local.mysql_node_keys : nonsensitive(local.mysql_private_ips[node_key])]
  description = "Private IPv4 addresses of MySQL InnoDB Cluster nodes."
}

output "mysql_node_instance_ids" {
  value       = [for node_key in local.mysql_node_keys : module.mysql_infrastructure.mysql_node_ids[node_key]]
  description = "Instance IDs of MySQL InnoDB Cluster nodes."
}

output "mysql_data_disk_ids" {
  value       = [for node_key in local.mysql_node_keys : module.mysql_infrastructure.mysql_data_volumes[node_key].disk_id]
  description = "Data disk IDs in MySQL node order. Empty values indicate system-disk storage."
}

output "mysql_node_hostnames" {
  value       = [for node_key in local.mysql_node_keys : local.mysql_nodes[node_key].hostname]
  description = "Hostnames of MySQL InnoDB Cluster nodes."
}

output "mysql_direct_endpoints" {
  value       = [for node_key in local.mysql_node_keys : format("%s:3306", local.mysql_nodes[node_key].hostname)]
  description = "Hostname-based direct MySQL server endpoints. Applications should prefer Router endpoints."
}

output "mysql_router_read_write_endpoints" {
  value       = [for node_key in local.mysql_node_keys : format("%s:6446", local.mysql_nodes[node_key].hostname)]
  description = "Hostname-based MySQL Router read/write endpoints on database nodes."
}

output "mysql_router_read_only_endpoints" {
  value       = [for node_key in local.mysql_node_keys : format("%s:6447", local.mysql_nodes[node_key].hostname)]
  description = "Hostname-based MySQL Router read-only endpoints on database nodes."
}

output "mysql_admin_username" {
  value       = var.mysql_admin_username
  description = "MySQL administrator username."
}

output "mysql_admin_password" {
  value       = local.mysql_admin_password
  description = "MySQL administrator password."
  sensitive   = true
}

output "mysql_instance_private_key" {
  value       = module.mysql_infrastructure.mysql_private_key
  description = "Private key generated for the MySQL compute instances."
  sensitive   = true
}
