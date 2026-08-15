output "published_path" {
  description = "文件发布到的绝对目标路径。"
  value       = var.target_path
}

output "completed" {
  description = "文件整体发布完成信号（publish exec 的 ID）。"
  value       = qiniu_compute_instance_exec.publish.id
}

output "command" {
  description = "渲染后的直传命令（仅供契约测试与审计）。"
  value       = local.publish_command
  sensitive   = true
}