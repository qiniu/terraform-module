# ============================================================================
# Moltbot Terraform Module - Outputs
# ============================================================================
# 部署完成后输出的信息，用于用户访问和管理
# ============================================================================

# ============================================================================
# 实例信息
# ============================================================================

output "instance_id" {
  value       = qiniu_compute_instance.moltbot.id
  description = "Moltbot 实例 ID"
}

output "public_ip" {
  value = length(qiniu_compute_instance.moltbot.public_ip_addresses) > 0 ? (
    qiniu_compute_instance.moltbot.public_ip_addresses[0].ipv4
  ) : null
  description = "公网 IP 地址"
}

# ============================================================================
# 访问信息
# ============================================================================

output "ssh_command_clawd" {
  value = length(qiniu_compute_instance.moltbot.public_ip_addresses) > 0 ? (
    "ssh clawd@${qiniu_compute_instance.moltbot.public_ip_addresses[0].ipv4}"
  ) : null
  description = "SSH 连接命令（clawd 用户）"
}

output "ssh_tunnel_command" {
  value = length(qiniu_compute_instance.moltbot.public_ip_addresses) > 0 ? (
    "ssh -N -L ${var.gateway_port}:127.0.0.1:${var.gateway_port} clawd@${qiniu_compute_instance.moltbot.public_ip_addresses[0].ipv4}"
  ) : null
  description = "SSH 隧道命令（用于访问 dashboard）"
}

output "dashboard_url" {
  value       = "http://localhost:${var.gateway_port}/?token=${random_password.dashboard_token.result}"
  sensitive   = true
  description = "Dashboard 完整访问 URL（需要先建立 SSH 隧道）"
}
