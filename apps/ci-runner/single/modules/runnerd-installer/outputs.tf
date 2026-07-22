output "install_command" {
  description = "在目标主机上幂等安装并启动 runnerd 的命令。"
  value       = local.install_command
  sensitive   = true
}

output "install_checksum" {
  description = "完整安装命令的非敏感 SHA-256 摘要。"
  value       = local.install_checksum
}
