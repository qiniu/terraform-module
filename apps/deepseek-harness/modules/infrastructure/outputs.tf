output "instance_id" {
  value = qiniu_compute_instance.deepseek_harness.id
}

output "instance_region_id" {
  value = data.qiniu_compute_region.current.region.id
}

output "instance_region_name" {
  value = data.qiniu_compute_region.current.region.name
}

output "deployment_private_key" {
  value     = qiniu_compute_key_pair.deployment.private_key
  sensitive = true
}

output "dsh_web_public_authority" {
  description = "HTTPProxy 公网 authority（不含 scheme）。"
  value       = qiniu_compute_instance_public_access.dsh_web.endpoint
}

output "dsh_web_proxy_port" {
  value = local.dsh_web_proxy_port
}

output "static_preview_public_authority" {
  description = "Static Preview HTTPProxy 公网 authority（不含 scheme）。"
  value       = qiniu_compute_instance_public_access.static_preview.endpoint
}

output "static_preview_proxy_port" {
  value = local.static_preview_proxy_port
}

output "preview_ports" {
  value = slice(local.preview_slot_ports, 0, var.preview_count)
}

output "preview_public_authorities" {
  description = "Preview HTTPProxy 公网 authority 列表（不含 scheme）。"
  value       = [for item in qiniu_compute_instance_public_access.preview : item.endpoint]
}

output "code_server_public_authority" {
  description = "code-server HTTPProxy 公网 authority（不含 scheme）。"
  value       = qiniu_compute_instance_public_access.code_server.endpoint
}

output "code_server_proxy_port" {
  value = local.code_server_proxy_port
}

output "ssh_endpoints" {
  value = var.enable_ssh_port_forward ? [for item in qiniu_compute_instance_public_access.ssh[0].endpoints : item.endpoint] : []
}
