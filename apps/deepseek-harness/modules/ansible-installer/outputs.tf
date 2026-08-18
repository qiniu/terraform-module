output "install_command" {
  description = "在目标主机上引导 uv 并本机运行 DeepSeek Harness Ansible 安装的命令。"
  value       = local.install_command
  sensitive   = true

  precondition {
    condition     = can(regex("^[\\x00-\\x7F]*$", local.install_command)) && length(local.install_command) <= 8192
    error_message = "install_command 必须为不超过 8192 个 ASCII 字符。"
  }

}

output "file_contents" {
  description = "按目标绝对路径索引的安装文件 base64 内容。"
  value = merge(module.ansible_runtime.runtime_file_contents, {
    (local.bootstrap_target_path) = base64encode(local.bootstrap_content)
  })
  sensitive = true
}

output "file_metadata" {
  description = "按目标绝对路径索引的安装文件权限和 SHA-256。"
  value = merge(module.ansible_runtime.runtime_file_metadata, {
    (local.bootstrap_target_path) = {
      file_mode = "0700"
      sha256    = sha256(local.bootstrap_content)
    }
  })
}
