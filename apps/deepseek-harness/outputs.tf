output "dsh_web_public_url" {
  description = "DeepSeek Harness Web HTTPS 地址。"
  value       = "https://${module.infrastructure.dsh_web_public_authority}"
}

output "code_server_public_url" {
  description = "启用 code-server 时的 HTTPS 地址；禁用时为 null。"
  value       = var.enable_code_server ? "https://${module.infrastructure.code_server_public_authority}" : null
}

output "dsh_web_username" {
  description = "Web Basic Auth 用户名。"
  value       = local.dsh_web_username
}

output "dsh_web_password" {
  description = "自动生成的 Web Basic Auth 密码；启用 code-server 时也用作其登录密码。显式输入密码时为 null。"
  value       = nonsensitive(var.dsh_web_password) == "" ? local.dsh_web_password : null
  sensitive   = true
}

output "ssh_command" {
  description = "启用 SSH PortForward 时的 root 登录命令。"
  value = length(module.infrastructure.ssh_endpoints) > 0 ? join(" ", [
    "ssh", "-p", split(":", module.infrastructure.ssh_endpoints[0])[1],
    "root@${split(":", module.infrastructure.ssh_endpoints[0])[0]}",
  ]) : null
}
