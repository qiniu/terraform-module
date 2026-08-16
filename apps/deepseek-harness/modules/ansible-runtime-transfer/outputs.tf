output "runtime_file_count" {
  description = "已发布的 Ansible 运行时文件数。"
  value       = length(module.runtime_file)
}

output "bootstrap_path" {
  description = "已发布的安装 bootstrap 路径。"
  value       = module.bootstrap.published_path
}
