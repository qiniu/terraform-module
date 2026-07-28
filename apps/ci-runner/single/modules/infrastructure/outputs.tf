output "instance_id" {
  description = "CI Runner ECS 实例 ID。"
  value       = qiniu_compute_instance.ci_runner.id
}

output "deployment_private_key" {
  description = "连接 CI Runner ECS 的部署私钥。"
  value       = qiniu_compute_key_pair.deployment.private_key
  sensitive   = true
}

output "public_url" {
  description = "runnerd 对外提供服务的 HTTPS URL。"
  value       = "https://${qiniu_compute_instance_public_access.runnerd.endpoint}"
}

output "ssh_endpoints" {
  description = "启用 SSH 端口转发时的公网 IP:Port 列表。"
  value       = var.enable_ssh_port_forward ? [for endpoint in qiniu_compute_instance_public_access.ssh[0].endpoints : endpoint.endpoint] : []
}
