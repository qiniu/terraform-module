output "install_command" {
  description = "在目标主机上幂等安装并启动 runnerd 的命令。"
  value       = local.install_command
  sensitive   = true
}

