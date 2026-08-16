output "dsh_web_public_url" {
  description = "DeepSeek Harness Web HTTPS 地址。"
  value       = module.infrastructure.public_url
}

output "preview_public_urls" {
  description = "Preview HTTPS 地址列表。"
  value       = module.infrastructure.preview_public_urls
}

output "code_server_public_url" {
  description = "code-server HTTPS 地址。"
  value       = module.infrastructure.code_server_public_url
}

output "code_server_password" {
  description = "code-server 自带登录密码。"
  value       = random_password.code_server.result
  sensitive   = true
}

output "dsh_web_username" {
  description = "Web Basic Auth 用户名。"
  value       = local.web_username
}

output "dsh_web_password" {
  description = "Web Basic Auth 随机密码。"
  value       = random_password.web.result
  sensitive   = true
}

output "instance_id" {
  description = "DeepSeek Harness ECS 实例 ID。"
  value       = module.infrastructure.instance_id
}

output "ssh_command" {
  description = "启用 SSH PortForward 时的 root 登录命令。"
  value = length(module.infrastructure.ssh_endpoints) > 0 ? join(" ", [
    "ssh", "-p", split(":", module.infrastructure.ssh_endpoints[0])[1],
    "root@${split(":", module.infrastructure.ssh_endpoints[0])[0]}",
  ]) : null
}

output "setup_guide" {
  description = "部署后的模型配置指引。"
  value       = "部署完成后打开 ${module.infrastructure.public_url}，使用 dsh_web_username/dsh_web_password 登录；code-server 地址为 ${module.infrastructure.code_server_public_url}（运行 terraform output -raw code_server_public_url 查看），使用敏感输出 code_server_password 登录。Preview 槽位数量为 ${var.preview_count}，应用可监听 127.0.0.1:30080 到 127.0.0.1:30083，公开地址列表见 terraform output -json preview_public_urls；Preview 是公开地址，不适用 Harness Basic Auth，由 HTTPProxy 直连应用，不经过 Nginx，未启动应用时 5xx（通常为 502，HTTPProxy 也可能返回 503）属于正常状态，页面或日志不得包含密码、令牌、私钥或其他敏感信息。"
}
