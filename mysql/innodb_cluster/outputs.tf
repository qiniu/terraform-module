output "mysql_node_private_ips" {
  value       = [for node_key in local.mysql_node_keys : nonsensitive(local.mysql_private_ips[node_key])]
  description = "Private IPv4 addresses of MySQL InnoDB Cluster nodes."
}

output "mysql_node_public_ips" {
  value = [
    for node_key in local.mysql_node_keys :
    try(module.mysql_infrastructure.mysql_node_public_ips[node_key], null)
  ]
  description = "Public IPv4 addresses of MySQL nodes when internet_max_bandwidth is greater than 0."
}

output "mysql_node_instance_ids" {
  value       = [for node_key in local.mysql_node_keys : module.mysql_infrastructure.mysql_node_ids[node_key]]
  description = "Instance IDs of MySQL InnoDB Cluster nodes."
}

output "mysql_node_hostnames" {
  value       = local.mysql_member_hostnames
  description = "Hostnames of MySQL InnoDB Cluster nodes."
}

output "mysql_direct_endpoints" {
  value       = [for hostname in local.mysql_member_hostnames : format("%s:3306", hostname)]
  description = "Hostname-based direct MySQL server endpoints. Applications should prefer Router endpoints."
}

output "mysql_router_read_write_endpoints" {
  value       = [for hostname in local.mysql_member_hostnames : format("%s:6446", hostname)]
  description = "Hostname-based MySQL Router read/write endpoints on database nodes."
}

output "mysql_router_read_only_endpoints" {
  value       = [for hostname in local.mysql_member_hostnames : format("%s:6447", hostname)]
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

output "mysql_instance_passwords" {
  value       = [for node_key in local.mysql_node_keys : module.mysql_infrastructure.mysql_node_passwords[node_key]]
  description = "Root passwords for the Qiniu compute instances."
  sensitive   = true
}

output "security_group_id" {
  value       = module.mysql_infrastructure.security_group_id
  description = "Security group ID created for the MySQL InnoDB Cluster."
}
