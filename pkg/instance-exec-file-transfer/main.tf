# ============================================================================
# instance-exec-file-transfer 公共传输模块（issue #58）
# ============================================================================
# 通过 qiniu_compute_instance_exec 在目标实例内发布单个文件，按内容大小自动分流：
#   - 小文件：module.direct 单条短命令直传；
#   - 大文件：module.chunked 并发分片（prepare → chunk → finalize）。
# 所有渲染命令均 <= 96000 字节且为纯 ASCII，规避远端 "Argument list too long"。
# ============================================================================

locals {
  # publish.sh.tftpl 固定开销约 1477 字节（含安全守卫与路径）。路径输入
  # 最多各 512 字节时，92.6 KiB payload 仍为命令预算保留约 100 字节余量。
  direct_payload_cap = 92600
  # 长度可由公开输入推导（非敏感），仅内容本身敏感
  small_file = nonsensitive(length(var.content)) <= local.direct_payload_cap
}

# 传输方式切换时，先销毁旧发布资源再创建新路径，避免两个 cleanup/publish
# 操作并发处理同一个目标文件。仅方式变化会替换，不影响同方式内容更新。
resource "terraform_data" "transport" {
  triggers_replace = [local.small_file]
}

module "direct" {
  count  = local.small_file ? 1 : 0
  source = "./modules/direct"

  depends_on = [terraform_data.transport]

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

  depends_on = [terraform_data.transport]

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
