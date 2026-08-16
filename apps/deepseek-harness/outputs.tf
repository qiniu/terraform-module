output "dsh_web_public_url" {
  description = "DeepSeek Harness Web HTTPS 地址。"
  value       = "https://${module.infrastructure.dsh_web_public_authority}"
}

output "preview_public_urls" {
  description = "Preview HTTPS 地址列表。"
  value       = [for authority in module.infrastructure.preview_public_authorities : "https://${authority}"]
}

output "code_server_public_url" {
  description = "code-server HTTPS 地址。"
  value       = "https://${module.infrastructure.code_server_public_authority}"
}

output "code_server_password" {
  description = "code-server 自带登录密码。"
  value       = random_password.code_server.result
  sensitive   = true
}

output "dsh_web_username" {
  description = "Web Basic Auth 用户名。"
  value       = local.dsh_web_username
}

output "dsh_web_password" {
  description = "Web Basic Auth 随机密码。"
  value       = random_password.dsh_web.result
  sensitive   = true
}

output "ssh_command" {
  description = "启用 SSH PortForward 时的 root 登录命令。"
  value = length(module.infrastructure.ssh_endpoints) > 0 ? join(" ", [
    "ssh", "-p", split(":", module.infrastructure.ssh_endpoints[0])[1],
    "root@${split(":", module.infrastructure.ssh_endpoints[0])[0]}",
  ]) : null
}
