output "destination_path" {
  description = "已原子发布的远端目标路径。"
  value       = var.destination_path
}

output "completed" {
  description = "finalize instance_exec 的完成标识，供调用方建立依赖。"
  value       = qiniu_compute_instance_exec.finalize.id
}
