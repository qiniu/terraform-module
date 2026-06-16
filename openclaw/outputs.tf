output "instance_id" {
  value       = qiniu_compute_instance.openclaw.id
  description = "OpenClaw 实例 ID"
}

output "expired_at" {
  value       = qiniu_compute_instance.openclaw.expired_at
  description = "实例过期时间（RFC3339 格式），仅预付费实例返回"
}

output "ssh_command" {
  value = join(" ", [
    "ssh",
    "-p", local.ssh_endpoint[1],        # 端口
    "openclaw@${local.ssh_endpoint[0]}" # 主机
  ])
  description = "SSH 连接命令（openclaw 用户）"
}

output "public_dashboard_url" {
  value = var.expose_dashboard ? (
    "https://${qiniu_compute_instance_public_access.gateway_http_proxy[0].endpoint}?token=${module.openclaw_scripts.dashboard_token}"
  ) : null
  sensitive   = true
  description = "公网 Dashboard 访问 URL（仅 expose_dashboard=true 时输出）"
}

output "internal_ssh_tunnel_command" {
  value = join(" ", [
    "ssh",
    "-p", local.ssh_endpoint[1],                                                  # 端口
    "-N",                                                                         # 只建立隧道，不进入shell执行命令
    "-L ${local.internal_gateway_port}:127.0.0.1:${local.internal_gateway_port}", # 在本地端口上监听，转发流量到远程端口
    "openclaw@${local.ssh_endpoint[0]}",                                          # 主机
    "-o StrictHostKeyChecking=no",                                                # 不询问新主机的密钥
    "-o UserKnownHostsFile=/dev/null",                                            # 不记录到已知主机密钥
  ])
  description = "基于 SSH 隧道转发命令用于访问 Dashboard"
  sensitive   = true
}

output "internal_dashboard_url" {
  value       = "http://127.0.0.1:${local.internal_gateway_port}?token=${module.openclaw_scripts.dashboard_token}"
  description = "本地 Dashboard 访问 URL，需要先执行 internal_ssh_tunnel_command 命令建立隧道后才能访问"
  sensitive   = true
}

output "ssh_openclaw_password" {
  value       = var.root_password
  description = "实例 openclaw 用户密码"
  sensitive   = true
}
