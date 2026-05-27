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
  value = var.internet_public_ip_type == "Dedicated" ? (
    length(qiniu_compute_instance.openclaw.public_ip_addresses) > 0 ? (
      qiniu_compute_instance.openclaw.public_ip_addresses[0].ipv4
    ) : null
  ) : null
  description = "独立公网 IP 地址（仅 Dedicated 模式有效，Shared 模式为 null）"
}

output "expired_at" {
  value       = qiniu_compute_instance.openclaw.expired_at
  description = "实例过期时间（RFC3339 格式），仅预付费实例返回"
}

# ============================================================================
# 访问信息
# ============================================================================

output "ssh_command" {
  value = var.internet_public_ip_type == "Shared" ? (
    length(local.ssh_port_forward) > 0 ? (
      "ssh -p ${local.ssh_port_forward[0].external_port} openclaw@${local.ssh_port_forward[0].public_ip}"
    ) : null
    ) : (
    length(qiniu_compute_instance.openclaw.public_ip_addresses) > 0 ? (
      "ssh openclaw@${qiniu_compute_instance.openclaw.public_ip_addresses[0].ipv4}"
    ) : null
  )
  description = "SSH 连接命令（openclaw 用户）"
}

output "ssh_tunnel_command" {
  value = !var.expose_dashboard ? (
    var.internet_public_ip_type == "Shared" ? (
      length(local.ssh_port_forward) > 0 ? (
        "ssh -p ${local.ssh_port_forward[0].external_port} -N -L ${var.gateway_port}:127.0.0.1:${var.gateway_port} openclaw@${local.ssh_port_forward[0].public_ip}"
      ) : null
      ) : (
      length(qiniu_compute_instance.openclaw.public_ip_addresses) > 0 ? (
        "ssh -N -L ${var.gateway_port}:127.0.0.1:${var.gateway_port} openclaw@${qiniu_compute_instance.openclaw.public_ip_addresses[0].ipv4}"
      ) : null
    )
  ) : null
  description = "SSH 隧道转发命令（用于访问 Dashboard，仅 expose_dashboard=false 时输出）"
}

output "dashboard_url" {
  value = var.expose_dashboard ? (
    var.internet_public_ip_type == "Shared" ? (
      length(local.gateway_port_forward) > 0 ? (
        "http://${local.gateway_port_forward[0].public_ip}:${local.gateway_port_forward[0].external_port}/?token=${random_password.dashboard_token.result}"
      ) : null
      ) : (
      length(qiniu_compute_instance.openclaw.public_ip_addresses) > 0 ? (
        "http://${qiniu_compute_instance.openclaw.public_ip_addresses[0].ipv4}:${var.gateway_port}/?token=${random_password.dashboard_token.result}"
      ) : null
    )
  ) : null

  sensitive   = true
  description = "Dashboard 访问 URL（仅 expose_dashboard=true 时输出；Shared 模式从 port_forwards 获取外部端口，Dedicated 模式使用 gateway_port）"
}

output "port_forwards" {
  value = [
    # 先将internal_port转化为字符串然后降序排序
    for padded in sort([for pf in qiniu_compute_instance.openclaw.port_forwards : format("%05d", pf.internal_port)]) :
    {
      # 再构建一个map从字符串查找出对应的internal_port、external_port和public_ip
      for pf in qiniu_compute_instance.openclaw.port_forwards : format("%05d", pf.internal_port) => {
        internal_port = pf.internal_port
        external_port = pf.external_port
        public_ip     = pf.public_ip
      }
    }[padded]
  ]
  description = "端口转发规则列表（Shared 模式，按 internal_port 升序）"
}
