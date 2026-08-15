# ============================================================================
# instance-exec-file-transfer 公共传输模块（issue #58）
# ============================================================================
# 通过 qiniu_compute_instance_exec 在目标实例内发布单个文件：
#   - 小文件：单条短命令直传（prepare+publish 合一），渲染命令 <= 8192 字节；
#   - 大文件：先 prepare（hash 命名 staging 与 marker）→ 并发分片上传（for_each，
#     每片独立 part 文件，互不追加）→ finalize（序号/SHA 校验 + 目标同目录原子 mv）。
# 每个命令的完整渲染长度都不超过 8192 字节且为纯 ASCII；payload（base64）属于
# 安全字符集（A-Za-z0-9+/=），单引号内嵌，无换行，规避 shell 注入与
# "Argument list too long"。
# ============================================================================

locals {
  # ---- staging 布局（hash 命名，可验证残留复用）----
  staging_dir = "${var.staging_root}/${var.content_sha256}"
  marker_path = "${local.staging_dir}/marker"

  # marker 内容：<sha256> <mode> <target_path>
  marker_content = "${var.content_sha256} ${var.file_mode} ${var.target_path}"

  # ---- 小文件直传命令 ----
  # 模板固定开销按实际生成字符串计算，payload 为唯一变量
  publish_command = <<-EOT
    set -e
    D=${local.staging_dir}
    mkdir -p "$D"
    printf '%s' '${local.marker_content}' > "$D/marker"
    T='${var.target_path}'
    TD=$(dirname "$T")
    mkdir -p "$TD"
    printf '%s' '${var.content}' | base64 -d > "$TD/.qiniu-pub.tmp-$$"
    printf '%s  %s\n' '${var.content_sha256}' "$TD/.qiniu-pub.tmp-$$" | sha256sum -c - >/dev/null
    chmod ${var.file_mode} "$TD/.qiniu-pub.tmp-$$"
    mv -f "$TD/.qiniu-pub.tmp-$$" "$T"
  EOT

  # ---- 大文件分片 ----
  # 分片命令模板：part 文件按 5 位序数命名，字典序即数字序；固定开销由
  # prefix/suffix 字面量计算，payload 上限 = 8192 - 固定开销 - 安全余量。
  chunk_prefix = "set -e\nD=${local.staging_dir}\nprintf '%s' '"
  chunk_suffix = "' > \"$D/part.__INDEX__.tmp\"\nmv -f \"$D/part.__INDEX__.tmp\" \"$D/part.__INDEX__\"\n"

  chunk_fixed_overhead  = length(local.chunk_prefix) + length(local.chunk_suffix) + 12 # __INDEX__ 占位宽度
  chunk_payload_max     = min(var.chunk_size, 8192 - local.chunk_fixed_overhead - 64)
  chunk_payload_aligned = floor(local.chunk_payload_max / 4) * 4

  # 命令长度非敏感（payload 长度可从公开输入推导），仅内容本身敏感
  content_len = nonsensitive(length(var.content))
  chunk_count = max(1, ceil(local.content_len / local.chunk_payload_aligned))

  chunk_indexes = range(local.chunk_count)

  # 单个分片渲染命令（__INDEX__ 替换为 5 位序数，__PAYLOAD__ 替换为 base64 片段）
  chunk_template = <<-EOT
    set -e
    D=${local.staging_dir}
    printf '%s' '__PAYLOAD__' > "$D/part.__INDEX__.tmp"
    mv -f "$D/part.__INDEX__.tmp" "$D/part.__INDEX__"
  EOT

  # keys（5 位序数）非敏感，作为 for_each 的实例 key；values 为敏感 base64 片段
  chunk_payloads = {
    for i in local.chunk_indexes :
    format("%05d", i) => substr(var.content, i * local.chunk_payload_aligned, local.chunk_payload_aligned)
  }

  # ---- prepare 命令：校验/创建 hash 命名 staging 与 marker，清空旧分片 ----
  prepare_command = <<-EOT
    set -e
    D=${local.staging_dir}
    mkdir -p "$D"
    printf '%s' '${local.marker_content}' > "$D/marker"
    rm -f "$D"/part.*
  EOT

  # ---- finalize 命令：校验分片数/存在性 → 拼接解码 → SHA 校验 → 目标同目录原子 mv ----
  # 分片文件名统一 5 位宽度，glob 字典序即数字序（part.00000 .. part.99999）
  finalize_command = <<-EOT
    set -e
    D=${local.staging_dir}
    [ -f "$D/marker" ] || exit 1
    [ "$(cat "$D/marker")" = '${local.marker_content}' ] || exit 1
    n=$(ls "$D"/part.* 2>/dev/null | wc -l)
    [ "$n" -eq ${local.chunk_count} ] || exit 1
    i=0
    while [ $i -lt ${local.chunk_count} ]; do
      p=$(printf '%05d' $i)
      [ -f "$D/part.$p" ] || exit 1
      i=$((i+1))
    done
    cat "$D"/part.* | base64 -d > "$D/merged.tmp"
    printf '%s  %s\n' '${var.content_sha256}' "$D/merged.tmp" | sha256sum -c - >/dev/null
    chmod ${var.file_mode} "$D/merged.tmp"
    T='${var.target_path}'
    TD=$(dirname "$T")
    mkdir -p "$TD"
    B=$(basename "$T")
    cp "$D/merged.tmp" "$TD/.$B.qiniu-finalize.tmp-$$"
    mv -f "$TD/.$B.qiniu-finalize.tmp-$$" "$T"
  EOT

  # ---- destroy 清理命令：仅当 marker 与目标 hash 均严格匹配时删除受管文件 ----
  destroy_command = <<-EOT
    set -e
    D=${local.staging_dir}
    T='${var.target_path}'
    if [ -f "$D/marker" ] && [ "$(cat "$D/marker")" = '${local.marker_content}' ]; then
      if [ -f "$T" ]; then
        if printf '%s  %s\n' '${var.content_sha256}' "$T" | sha256sum -c - >/dev/null 2>&1; then
          rm -f "$T"
        fi
      fi
      rm -rf "$D"
    fi
  EOT

  # 小文件判定：直传命令渲染完整后仍满足 8192 上限（命令长度非敏感）
  small_file = nonsensitive(length(local.publish_command)) <= 8192
}

# ============================================================================
# 小文件直传
# ============================================================================
resource "qiniu_compute_instance_exec" "publish" {
  count = local.small_file ? 1 : 0

  instance_id = var.instance_id
  user        = var.user
  port        = var.port
  password    = var.password
  private_key = var.private_key
  shell       = var.shell

  command         = local.publish_command
  destroy_command = var.destroy_cleanup ? local.destroy_command : null

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }
}

# ============================================================================
# 大文件分片：prepare → chunks（并发）→ finalize
# ============================================================================
resource "qiniu_compute_instance_exec" "prepare" {
  count = local.small_file ? 0 : 1

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
  for_each = local.small_file ? {} : {
    for k in keys(local.chunk_payloads) : k => null
  }

  instance_id = var.instance_id
  user        = var.user
  port        = var.port
  password    = var.password
  private_key = var.private_key
  shell       = var.shell

  command = replace(
    replace(local.chunk_template, "__INDEX__", each.key),
    "__PAYLOAD__",
    local.chunk_payloads[each.key],
  )

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
  count = local.small_file ? 0 : 1

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