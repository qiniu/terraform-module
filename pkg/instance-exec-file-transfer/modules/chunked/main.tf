# ============================================================================
# chunked 子模块：大文件并发分片传输（issue #58）
# ============================================================================
# 流程：prepare（hash 命名 staging/marker + 安全边界）→ chunks（并发，每片
# 独立 part 文件）→ finalize（序号/SHA 校验 + 目标同目录原子 mv）。
# 所有渲染命令 <= 8192 字节且为纯 ASCII。
# 远端脚本模板见 templates/{prepare,chunk,finalize,destroy}.sh.tftpl。
# ============================================================================

locals {
  staging_dir    = "${var.staging_root}/${var.content_sha256}"
  marker_content = "${var.content_sha256} ${var.file_mode} ${var.target_path}"

  # 目标已存在时，仅当 marker 与目标 SHA 严格匹配（受管文件）才允许覆盖
  target_cover_guard = "if [ -e \"$T\" ]||[ -L \"$T\" ];then [ -f \"$D/marker\" ]||exit 1;[ \"$(cat \"$D/marker\")\" = '${local.marker_content}' ]||exit 1;printf '%s  %s\\n' '${var.content_sha256}' \"$T\"|sha256sum -c - >/dev/null 2>&1||exit 1;fi"

  # ---- 分片计算 ----
  # 单片命令固定开销 = 空 payload 模板长度；payload 上限 =
  # 8192 - 固定开销 - 余量，再按 4 对齐（base64 字符）。
  chunk_empty = templatefile("${path.module}/templates/chunk.sh.tftpl", {
    staging_dir = local.staging_dir
    index       = "00000"
    payload     = ""
  })

  chunk_fixed_overhead  = length(local.chunk_empty)
  chunk_payload_max     = min(var.chunk_size, 8192 - local.chunk_fixed_overhead - 64)
  chunk_payload_aligned = floor(local.chunk_payload_max / 4) * 4
  content_len           = nonsensitive(length(var.content))
  chunk_count           = max(1, ceil(local.content_len / local.chunk_payload_aligned))
  chunk_payloads = {
    for i in range(local.chunk_count) :
    format("%05d", i) => substr(var.content, i * local.chunk_payload_aligned, local.chunk_payload_aligned)
  }

  # ---- prepare 命令：校验/创建 hash 命名 staging 与 marker，清空旧分片 ----
  prepare_command = templatefile("${path.module}/templates/prepare.sh.tftpl", {
    staging_root   = var.staging_root
    staging_dir    = local.staging_dir
    target_path    = var.target_path
    marker_content = local.marker_content
    content_sha256 = var.content_sha256
    cover_guard    = local.target_cover_guard
  })

  # ---- finalize 命令：校验分片数/存在性 → 拼接解码 → SHA 校验 → 目标同目录原子 mv ----
  finalize_command = templatefile("${path.module}/templates/finalize.sh.tftpl", {
    staging_dir    = local.staging_dir
    marker_content = local.marker_content
    chunk_count    = local.chunk_count
    content_sha256 = var.content_sha256
    file_mode      = var.file_mode
    target_path    = var.target_path
  })

  # ---- destroy 清理命令：仅当 marker 与目标 hash 均严格匹配时删除受管文件 ----
  destroy_command = templatefile("${path.module}/templates/destroy.sh.tftpl", {
    staging_dir    = local.staging_dir
    target_path    = var.target_path
    marker_content = local.marker_content
    content_sha256 = var.content_sha256
  })
}

resource "qiniu_compute_instance_exec" "prepare" {
  instance_id = var.instance_id
  user        = var.user
  port        = var.port
  password    = var.password
  private_key = var.private_key
  shell       = var.shell

  command = local.prepare_command

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }
}

resource "qiniu_compute_instance_exec" "chunk" {
  for_each = {
    for k in keys(local.chunk_payloads) : k => null
  }

  instance_id = var.instance_id
  user        = var.user
  port        = var.port
  password    = var.password
  private_key = var.private_key
  shell       = var.shell

  command = templatefile("${path.module}/templates/chunk.sh.tftpl", {
    staging_dir = local.staging_dir
    index       = each.key
    payload     = local.chunk_payloads[each.key]
  })

  depends_on = [
    qiniu_compute_instance_exec.prepare,
  ]

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }
}

resource "qiniu_compute_instance_exec" "finalize" {
  instance_id = var.instance_id
  user        = var.user
  port        = var.port
  password    = var.password
  private_key = var.private_key
  shell       = var.shell

  command         = local.finalize_command
  destroy_command = var.destroy_cleanup ? local.destroy_command : null

  depends_on = [
    qiniu_compute_instance_exec.chunk,
  ]

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }
}