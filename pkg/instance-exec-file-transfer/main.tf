# ============================================================================
# instance-exec-file-transfer 公共传输模块（issue #58）
# ============================================================================
# 通过 qiniu_compute_instance_exec 在目标实例内发布单个文件，按内容大小自动分流：
#   - 小文件：module.direct 单条短命令直传；
#   - 大文件：module.chunked 并发分片（prepare → chunk → finalize）。
# 完整渲染命令均 <= 8192 字节且为纯 ASCII，规避远端 "Argument list too long"。
# ============================================================================

locals {
  # 直传阈值：publish.sh.tftpl 固定开销约 1477 字节（含安全守卫与路径），
  # 为长 target_path 预留约 515 字节可变余量：8192 - 1477 - 515 = 6200。
  # 超过阈值自动走分片路径（子模块按 8192 预算）。
  direct_payload_cap = 6200
  # 长度可由公开输入推导（非敏感），仅内容本身敏感
  small_file = nonsensitive(length(var.content)) <= local.direct_payload_cap
}

module "direct" {
  count  = local.small_file ? 1 : 0
  source = "./modules/direct"

  instance_id     = var.instance_id
  user            = var.user
  port            = var.port
  private_key     = var.private_key
  password        = var.password
  shell           = var.shell
  content         = var.content
  content_sha256  = var.content_sha256
  target_path     = var.target_path
  file_mode       = var.file_mode
  staging_root    = var.staging_root
  destroy_cleanup = var.destroy_cleanup
}

module "chunked" {
  count  = local.small_file ? 0 : 1
  source = "./modules/chunked"

  # 直传变分片时，先清理旧的严格受管文件，再发布新内容。
  depends_on = [module.direct]

  instance_id     = var.instance_id
  user            = var.user
  port            = var.port
  private_key     = var.private_key
  password        = var.password
  shell           = var.shell
  content         = var.content
  content_sha256  = var.content_sha256
  target_path     = var.target_path
  file_mode       = var.file_mode
  chunk_size      = var.chunk_size
  staging_root    = var.staging_root
  destroy_cleanup = var.destroy_cleanup
}
