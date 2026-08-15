# ============================================================================
# 输出：发布结果与校验 exec 状态
# ============================================================================

output "instance_id" {
  description = "Live 测试使用的临时实例 ID。"
  value       = qiniu_compute_instance.test.id
}

output "small_published_path" {
  description = "小文件发布路径。"
  value       = module.small.published_path
}

output "big_published_path" {
  description = "大文件发布路径。"
  value       = module.big.published_path
}

output "big_chunk_count" {
  description = "大文件实际分片数量（应 > 1，验证分片路径）。"
  value       = module.big.chunk_count
}

output "verify_exec_id" {
  description = "内容/权限校验 exec 的 ID（apply 成功即校验通过）。"
  value       = qiniu_compute_instance_exec.verify.id
}