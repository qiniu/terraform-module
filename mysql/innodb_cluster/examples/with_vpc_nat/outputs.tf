output "mysql_router_read_write_endpoints" {
  value       = module.mysql_innodb_cluster.mysql_router_read_write_endpoints
  description = "MySQL Router read/write endpoints."
}

output "mysql_router_read_only_endpoints" {
  value       = module.mysql_innodb_cluster.mysql_router_read_only_endpoints
  description = "MySQL Router read-only endpoints."
}

output "mysql_admin_username" {
  value       = module.mysql_innodb_cluster.mysql_admin_username
  description = "MySQL administrator username."
}

output "mysql_admin_password" {
  value       = module.mysql_innodb_cluster.mysql_admin_password
  description = "MySQL administrator password."
  sensitive   = true
}

output "vpc_id" {
  value       = qiniu_compute_vpc.default.id
  description = "Created VPC ID."
}

output "subnet_id" {
  value       = qiniu_compute_subnet.default.id
  description = "Created subnet ID."
}
