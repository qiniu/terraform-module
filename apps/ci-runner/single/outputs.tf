output "dashboard_url" {
  description = "runnerd 控制台 HTTPS 地址。"
  value       = local.public_url
}

output "github_oauth_callback_url" {
  description = "GitHub App OAuth callback URL。"
  value       = "${local.public_url}/auth/github/callback"
}

output "github_app_setup_url" {
  description = "GitHub App setup URL。"
  value       = "${local.public_url}/github-app/setup"
}

output "github_webhook_url" {
  description = "GitHub App webhook URL。"
  value       = "${local.public_url}/webhooks/github"
}

output "github_webhook_secret" {
  description = "GitHub App webhook secret。"
  value       = module.config.webhook_secret
  sensitive   = true
}

output "ssh_endpoints" {
  description = "启用 SSH 端口转发时的公网 IP:Port 列表。"
  value       = var.enable_ssh_port_forward ? [for endpoint in try(qiniu_compute_instance_public_access.ssh[0].endpoints, []) : endpoint.endpoint] : []
}

output "ssh_private_key" {
  description = "启用 SSH 端口转发时使用的部署私钥；仅应写入权限为 0600 的本地临时文件。"
  value       = var.enable_ssh_port_forward ? tls_private_key.deployment.private_key_openssh : null
  sensitive   = true
}
