output "published_path" {
  description = "文件发布到的绝对目标路径。"
  value       = var.target_path
}

output "completed" {
  description = "文件整体发布完成信号（finalize exec 的 ID）。"
  value       = qiniu_compute_instance_exec.finalize.id
}

output "chunk_count" {
  description = "实际使用的分片数量。"
  value       = local.chunk_count
}