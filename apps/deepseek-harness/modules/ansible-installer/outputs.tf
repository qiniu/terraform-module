output "install_command" {
  description = "在目标主机上引导 uv 并本机运行 DeepSeek Harness Ansible 安装的命令。"
  value       = local.install_command
  sensitive   = true

  precondition {
    condition     = can(regex("^[\\x00-\\x7F]*$", local.install_command)) && length(local.install_command) <= 8192
    error_message = "install_command 必须为不超过 8192 个 ASCII 字符。"
  }

  precondition {
    condition = (
      local.dsh_port != var.dsh_web_port &&
      local.dsh_port != local.code_server_port &&
      local.dsh_port != var.code_server_web_port &&
      var.dsh_web_port != local.code_server_port &&
      var.dsh_web_port != var.code_server_web_port &&
      local.code_server_port != var.code_server_web_port &&
      !contains(var.preview_ports, local.dsh_port) &&
      !contains(var.preview_ports, var.dsh_web_port) &&
      !contains(var.preview_ports, local.code_server_port) &&
      !contains(var.preview_ports, var.code_server_web_port)
    )
    error_message = "Harness、Preview 和 code-server 的内部/代理端口必须互不重复。"
  }
}

output "runtime_file_contents" {
  description = "显式 Ansible 运行时白名单中每个文件的无换行 base64 内容。"
  value       = local.runtime_file_contents
  sensitive   = true
}

output "runtime_file_metadata" {
  description = "显式 Ansible 运行时白名单中每个文件的目标路径、权限和 SHA-256。"
  value       = local.runtime_file_metadata
}

output "runtime_manifest" {
  description = "用于 bootstrap 校验所有已传输 Ansible 文件的 SHA-256 清单。"
  value       = local.runtime_manifest
}

output "bootstrap" {
  description = "无敏感安装 bootstrap 脚本的目标路径、权限、SHA-256 和 base64 内容。"
  value       = local.bootstrap
}
