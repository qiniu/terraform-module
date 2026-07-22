output "install_command" {
  description = "在目标主机上幂等安装并启动 runnerd 的命令。"
  value       = local.install_command
  sensitive   = true
}

output "destroy_command" {
  description = "人工停止 runnerd 并移除模块受管文件的命令；保留用户和持久数据。"
  value       = local.destroy_command
}

output "verify_command" {
  description = "验证目标主机 runnerd 安装结果和重启恢复能力的命令。"
  value       = local.verify_command
}

output "verify_checksum" {
  description = "覆盖安装摘要和原始验证模板的非敏感 SHA-256 摘要。"
  value       = local.verify_checksum
}

output "install_checksum" {
  description = "覆盖全部安装输入和原始安装模板的非敏感 SHA-256 摘要。"
  value       = local.install_checksum
}
