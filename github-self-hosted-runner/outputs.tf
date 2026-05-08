# ==========================================
# 输出部署结果信息
# ==========================================

output "runner_instance_id" {
  value       = qiniu_compute_instance.github_runner.id
  description = "GitHub Runner 虚拟机实例 ID"
}

output "runner_instance_name" {
  value       = qiniu_compute_instance.github_runner.name
  description = "GitHub Runner 虚拟机实例名称"
}

output "runner_private_ip" {
  value       = qiniu_compute_instance.github_runner.private_ip_addresses[0].ipv4
  description = "Runner 虚拟机的内网 IP 地址"
}

output "runner_name" {
  value       = local.runner_name
  description = "GitHub Runner 的注册名称"
}

output "runner_labels" {
  value       = local.runner_labels
  description = "GitHub Runner 的标签列表"
}

output "runner_repository" {
  value       = var.github_repo_url
  description = "Runner 所属的 GitHub 仓库"
}

output "instance_password" {
  value       = random_password.runner_instance_password.result
  description = "虚拟机 root 密码（敏感信息）"
  sensitive   = true
}

output "ssh_connection_command" {
  value       = "ssh root@${qiniu_compute_instance.github_runner.private_ip_addresses[0].ipv4}"
  description = "SSH 连接命令（需要密码）"
}

output "runner_status_check" {
  value       = "ssh root@${qiniu_compute_instance.github_runner.private_ip_addresses[0].ipv4} 'cd /home/${var.runner_username}/actions-runner && sudo ./svc.sh status'"
  description = "检查 Runner 状态的命令"
}

output "runner_logs_command" {
  value       = "ssh root@${qiniu_compute_instance.github_runner.private_ip_addresses[0].ipv4} 'journalctl -u actions.runner.* -f'"
  description = "查看 Runner 日志的命令"
}
