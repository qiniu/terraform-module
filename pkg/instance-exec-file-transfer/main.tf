# ============================================================================
# instance-exec-file-transfer 公共传输模块（issue #58）
# ============================================================================
# 通过 qiniu_compute_instance_exec 在目标实例内发布单个文件。根据内容大小
# 自动分流：
#   - 小文件（base64 payload 不超过直传上限）：module.direct 单条短命令直传；
#   - 大文件：module.chunked prepare → 并发分片 → finalize 校验合并。
# 完整渲染命令均 <= 8192 字节且为纯 ASCII，规避远端 "Argument list too long"。
# 分流阈值由直传命令预算确定：8192 - 命令模板固定开销上限 - 安全余量。
# ============================================================================

locals {
  # 直传命令阈值：publish.sh.tftpl 渲染后固定开销实测约 1141 字节（含 cover_guard、
  # staging/target 路径），此处取保守上限 8192 - 1600 = 6592，为长 target_path /
  # staging 路径留足余量。超过阈值自动走分片路径，分片命令长度由子模块按 8192 预算。
  direct_payload_cap = 6592
  # 命令长度/内容长度非敏感（可从公开输入推导），仅内容本身敏感
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