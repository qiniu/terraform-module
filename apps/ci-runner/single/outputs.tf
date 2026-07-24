output "dashboard_url" {
  description = "CI Runner 控制台 HTTPS 地址。"
  value       = module.infrastructure.public_url
}

output "github_oauth_callback_url" {
  description = "GitHub App OAuth callback URL。"
  value       = "${module.infrastructure.public_url}/auth/github/callback"
}

output "github_webhook_url" {
  description = "GitHub App webhook URL。"
  value       = "${module.infrastructure.public_url}/webhooks/github"
}

output "github_webhook_secret" {
  description = "GitHub App webhook secret。"
  value       = module.config.webhook_secret
  sensitive   = true
}

output "ssh_command" {
  description = "SSH 登录命令（root 用户），需先设置 instance_password 且 enable_ssh_port_forward = true。"
  value = length(module.infrastructure.ssh_endpoints) > 0 ? join(" ", [
    "ssh",
    "-p", split(":", module.infrastructure.ssh_endpoints[0])[1],
    "root@${split(":", module.infrastructure.ssh_endpoints[0])[0]}",
  ]) : null
}

output "setup_guide" {
  description = "部署后配置指引：按步骤完成 GitHub App 设置即可开始使用。"
  value       = <<-EOT
    部署完成！请按以下步骤完成 GitHub App 配置：

    1. 打开 GitHub App 设置页: https://github.com/settings/apps/${var.github_app_slug}
    2. 设置 Webhook URL: ${module.infrastructure.public_url}/webhooks/github
    3. 设置 Webhook Secret: 见 github_webhook_secret 输出
    4. 订阅事件: 勾选 Workflow jobs（必需），可选 Workflow runs
    5. 设置 OAuth callback URL: ${module.infrastructure.public_url}/auth/github/callback
    6. 打开控制台完成初始化: ${module.infrastructure.public_url}
  EOT
}
