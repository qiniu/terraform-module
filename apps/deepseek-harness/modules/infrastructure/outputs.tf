output "instance_id" {
  value = qiniu_compute_instance.deepseek_harness.id
}

output "deployment_private_key" {
  value     = qiniu_compute_key_pair.deployment.private_key
  sensitive = true
}

output "dsh_public_authority" {
  description = "HTTPProxy 公网 authority（不含 scheme）。"
  value       = qiniu_compute_instance_public_access.web.endpoint
}

output "dsh_public_url" {
  value = "https://${qiniu_compute_instance_public_access.web.endpoint}"
}

output "preview_public_url" {
  value = try("https://${qiniu_compute_instance_public_access.preview[0].endpoint}", null)
}

output "preview_public_authorities" {
  description = "Preview HTTPProxy 公网 authority 列表（不含 scheme）。"
  value       = [for item in qiniu_compute_instance_public_access.preview : item.endpoint]
}

output "preview_public_urls" {
  description = "Preview HTTPProxy 公网 URL 列表。"
  value       = [for item in qiniu_compute_instance_public_access.preview : "https://${item.endpoint}"]
}

output "code_server_public_authority" {
  description = "code-server HTTPProxy 公网 authority（不含 scheme）。"
  value       = qiniu_compute_instance_public_access.code_server.endpoint
}

output "code_server_public_url" {
  value = "https://${qiniu_compute_instance_public_access.code_server.endpoint}"
}

output "ssh_endpoints" {
  value = var.enable_ssh_port_forward ? [for item in qiniu_compute_instance_public_access.ssh[0].endpoints : item.endpoint] : []
}
