# ============================================================================
# 输出：已发布路径与完成依赖
# 调用方可将 completed 输出传给后续 qiniu_compute_instance_exec 的 triggers /
# depends_on，显式等待文件发布完成。
# ============================================================================

output "published_path" {
  description = "文件发布到的绝对目标路径。"
  value       = var.target_path
}

output "completed" {
  description = "文件整体发布完成信号（小文件为直传 exec，大文件为 finalize exec 的 ID）。"
  value       = local.small_file ? qiniu_compute_instance_exec.publish[0].id : qiniu_compute_instance_exec.finalize[0].id
}

output "chunk_count" {
  description = "实际使用的分片数量（小文件直传时为 1）。"
  value       = local.small_file ? 1 : local.chunk_count
}