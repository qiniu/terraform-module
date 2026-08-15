output "install_command" {
  description = "在目标主机上幂等安装并启动 DeepSeek Harness 的命令。"
  value       = local.install_command
  sensitive   = true

  precondition {
    condition = (
      var.dsh_port != var.nginx_proxy_port &&
      var.dsh_port != var.code_server_port &&
      var.nginx_proxy_port != var.code_server_proxy_port &&
      !contains(var.preview_ports, var.dsh_port) &&
      !contains(var.preview_ports, var.nginx_proxy_port) &&
      !contains(var.preview_ports, var.code_server_port) &&
      !contains(var.preview_ports, var.code_server_proxy_port)
    )
    error_message = "Harness、Preview 和 code-server 的内部/代理端口必须互不重复。"
  }
}
