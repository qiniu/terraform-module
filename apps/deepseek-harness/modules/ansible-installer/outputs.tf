output "install_command" {
  description = "在目标主机上引导 uv 并本机运行 DeepSeek Harness Ansible 安装的命令。"
  value       = local.install_command
  sensitive   = true

  precondition {
    condition     = can(regex("^[\\x00-\\x7F]*$", local.install_command)) && length(local.install_command) <= 131072
    error_message = "install_command 必须为不超过 131072 个 ASCII 字符。"
  }

  precondition {
    condition = (
      var.dsh_port != var.nginx_proxy_port &&
      var.dsh_port != var.code_server_port &&
      var.dsh_port != var.code_server_proxy_port &&
      var.nginx_proxy_port != var.code_server_port &&
      var.nginx_proxy_port != var.code_server_proxy_port &&
      var.code_server_port != var.code_server_proxy_port &&
      !contains(var.preview_ports, var.dsh_port) &&
      !contains(var.preview_ports, var.nginx_proxy_port) &&
      !contains(var.preview_ports, var.code_server_port) &&
      !contains(var.preview_ports, var.code_server_proxy_port)
    )
    error_message = "Harness、Preview 和 code-server 的内部/代理端口必须互不重复。"
  }
}
