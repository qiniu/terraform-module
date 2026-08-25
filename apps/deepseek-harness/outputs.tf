output "dsh_web_public_url" {
  description = "DeepSeek Harness Web HTTPS 地址。"
  value       = "https://${module.infrastructure.dsh_web_public_authority}"
}

output "code_server_public_url" {
  description = "启用 code-server 时的 HTTPS 地址；禁用时为 null。"
  value       = var.enable_code_server ? "https://${module.infrastructure.code_server_public_authority}" : null
}

output "filebrowser_public_url" {
  description = "启用 FileBrowser Quantum 时的 HTTPS 地址；禁用时为 null。"
  value       = var.enable_filebrowser ? "https://${module.infrastructure.filebrowser_public_authority}" : null
}

output "dsh_web_username" {
  description = "Web Basic Auth 用户名。"
  value       = local.dsh_web_username
}

output "dsh_web_password" {
  description = "自动生成的 DeepSeek Harness 登录密码；启用 code-server 或 FileBrowser 时，三个服务共用此密码。显式输入密码时为 null。"
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

output "usage_guide" {
  description = "DeepSeek Harness 使用说明。"
  value = templatefile("${path.module}/templates/usage-guide.md.tftpl", {
    dsh_web_url        = "https://${module.infrastructure.dsh_web_public_authority}"
    code_server_url    = "https://${module.infrastructure.code_server_public_authority}"
    filebrowser_url    = "https://${module.infrastructure.filebrowser_public_authority}"
    enable_code_server = var.enable_code_server
    enable_filebrowser = var.enable_filebrowser
  })
}
