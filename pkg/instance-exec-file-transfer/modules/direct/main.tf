# ============================================================================
# direct 子模块：单文件单命令直传（issue #58）
# ============================================================================
# 单条短命令内完成 staging/marker 校验、base64 解码、SHA 校验与目标同目录
# 原子发布；渲染命令 <= 96000 字节且为纯 ASCII。
# 远端脚本模板见 templates/publish.sh.tftpl 与 templates/destroy.sh.tftpl。
# ============================================================================

locals {
  staging_dir    = "${var.staging_root}/${var.content_sha256}"
  marker_content = "${var.content_sha256} ${var.file_mode} ${var.target_path}"

  # 目标已存在时，仅当 marker 与目标 SHA 严格匹配（受管文件）才允许覆盖
  target_cover_guard = "if [ -e \"$T\" ]||[ -L \"$T\" ];then [ -f \"$D/marker\" ]||exit 1;[ \"$(cat \"$D/marker\")\" = '${local.marker_content}' ]||exit 1;printf '%s  %s\\n' '${var.content_sha256}' \"$T\"|sha256sum -c - >/dev/null 2>&1||exit 1;fi"

  publish_command = templatefile("${path.module}/templates/publish.sh.tftpl", {
    staging_dir    = local.staging_dir
    target_path    = var.target_path
    marker_content = local.marker_content
    content        = var.content
    content_sha256 = var.content_sha256
    file_mode      = var.file_mode
    cover_guard    = local.target_cover_guard
  })

  destroy_command = templatefile("${path.module}/templates/destroy.sh.tftpl", {
    staging_dir    = local.staging_dir
    target_path    = var.target_path
    marker_content = local.marker_content
    content_sha256 = var.content_sha256
  })
}

resource "qiniu_compute_instance_exec" "publish" {
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
