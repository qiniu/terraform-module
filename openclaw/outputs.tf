# ============================================================================
# OpenClaw Terraform Module - Outputs
# ============================================================================
# 部署完成后输出的信息，用于用户访问和管理
# ============================================================================

# ============================================================================
# 实例信息
# ============================================================================

output "instance_id" {
  value       = qiniu_compute_instance.openclaw.id
  description = "OpenClaw 实例 ID"
}

output "public_ip" {
  value = length(qiniu_compute_instance.openclaw.public_ip_addresses) > 0 ? (
    qiniu_compute_instance.openclaw.public_ip_addresses[0].ipv4
  ) : null
  description = "公网 IP 地址"
}

output "expired_at" {
  value       = qiniu_compute_instance.openclaw.expired_at
  description = "实例过期时间（RFC3339 格式），仅预付费实例返回"
}

output "order_id" {
  value       = qiniu_compute_instance.openclaw.order_id
  description = "实例创建订单 ID，仅预付费实例返回"
}

output "order_state" {
  value       = qiniu_compute_instance.openclaw.order_state
  description = "实例创建订单状态，仅预付费实例返回"
}

# ============================================================================
# 访问信息
# ============================================================================

output "ssh_command" {
  value = length(qiniu_compute_instance.openclaw.public_ip_addresses) > 0 ? (
    "ssh openclaw@${qiniu_compute_instance.openclaw.public_ip_addresses[0].ipv4}"
  ) : null
  description = "SSH 连接命令（openclaw 用户）"
}

output "ssh_tunnel_command" {
  value = !var.expose_dashboard && length(qiniu_compute_instance.openclaw.public_ip_addresses) > 0 ? (
    "ssh -N -L ${var.gateway_port}:127.0.0.1:${var.gateway_port} openclaw@${qiniu_compute_instance.openclaw.public_ip_addresses[0].ipv4}"
  ) : null
  description = "SSH 隧道转发命令（用于访问 Dashboard，仅 expose_dashboard=false 时输出）"
}

output "dashboard_url" {
  value = var.expose_dashboard && length(qiniu_compute_instance.openclaw.public_ip_addresses) > 0 ? (
    "http://${qiniu_compute_instance.openclaw.public_ip_addresses[0].ipv4}:${var.gateway_port}/?token=${random_password.dashboard_token.result}"
  ) : "http://127.0.0.1:${var.gateway_port}/?token=${random_password.dashboard_token.result}"
  sensitive   = true
  description = "Dashboard 访问 URL"
}
