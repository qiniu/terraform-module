locals {
  staging_root       = "/var/lib/instance-exec-file-transfer"
  marker_name        = ".instance-exec-file-transfer-managed"
  encoded_chunks     = [for characters in chunklist(split("", var.content_base64), var.chunk_size) : join("", characters)]
  chunks             = { for index, payload in local.encoded_chunks : format("%06d", index) => payload }
  destination_parent = dirname(var.destination_path)
  destination_name   = basename(var.destination_path)

  prepare_command = <<-BASH
    set -euo pipefail
    umask 077
    sha='${var.content_sha256}'
    destination='${var.destination_path}'
    staging_root='${local.staging_root}'
    marker_name='${local.marker_name}'
    fail() { printf '%s\n' "$1" >&2; exit 1; }
    require_root_dir() {
      [ -d "$1" ] && [ ! -L "$1" ] && [ "$(stat -c %u -- "$1")" = 0 ] || fail "unsafe directory: $1"
      [ "$(realpath -e -- "$1")" = "$1" ] || fail "unsafe realpath: $1"
    }
    require_root_file() {
      [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c %u -- "$1")" = 0 ] || fail "unsafe file: $1"
      [ "$(realpath -e -- "$1")" = "$1" ] || fail "unsafe file realpath: $1"
    }
    marker_matches() { require_root_file "$1"; printf '%s\n' "$sha" | cmp -s - "$1"; }
    install -d -o root -g root -m 0700 -- "$staging_root"
    require_root_dir "$staging_root"
    runtime_parent="$(dirname -- "$destination")"
    current=/opt
    require_root_dir "$current"
    relative="$${destination#/opt/}"
    IFS=/ read -r -a parts <<< "$relative"
    for part in "$${parts[@]:0:$${#parts[@]}-1}"; do
      current="$current/$part"
      if [ -e "$current" ] || [ -L "$current" ]; then require_root_dir "$current"; else install -d -o root -g root -m 0755 -- "$current"; require_root_dir "$current"; fi
    done
    require_root_dir "$runtime_parent"
    staging="$staging_root/$sha"
    marker="$staging/$marker_name"
    if [ -e "$staging" ] || [ -L "$staging" ]; then
      require_root_dir "$staging"
      marker_matches "$marker" || fail 'staging marker hash mismatch'
    else
      install -d -o root -g root -m 0700 -- "$staging"
      printf '%s\n' "$sha" > "$marker"
      chown root:root -- "$marker"; chmod 0600 -- "$marker"
    fi
    chunks="$staging/chunks"
    if [ -e "$chunks" ] || [ -L "$chunks" ]; then require_root_dir "$chunks"; rm -rf -- "$chunks"; fi
    install -d -o root -g root -m 0700 -- "$chunks"
    if [ -e "$destination" ] || [ -L "$destination" ]; then
      target_marker="$destination$marker_name"
      require_root_file "$destination"; marker_matches "$target_marker" || fail 'target marker hash mismatch'
      [ "$(sha256sum -- "$destination" | awk '{print $1}')" = "$sha" ] || fail 'target content hash mismatch'
    fi
  BASH

  chunk_commands = {
    for index, payload in local.chunks : index => <<-BASH
      set -euo pipefail
      sha='${var.content_sha256}'; staging='${local.staging_root}/${var.content_sha256}'; marker="$staging/${local.marker_name}"; chunks="$staging/chunks"
      fail() { printf '%s\n' "$1" >&2; exit 1; }
      require_root_file() { [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c %u -- "$1")" = 0 ] && [ "$(realpath -e -- "$1")" = "$1" ] || fail "unsafe file: $1"; }
      marker_matches() { require_root_file "$1"; printf '%s\n' "$sha" | cmp -s - "$1"; }
      [ -d "$staging" ] && [ ! -L "$staging" ] && [ "$(stat -c %u -- "$staging")" = 0 ] && [ "$(realpath -e -- "$staging")" = "$staging" ] || fail 'unsafe staging'
      marker_matches "$marker" || fail 'unsafe staging marker'
      [ -d "$chunks" ] && [ ! -L "$chunks" ] && [ "$(stat -c %u -- "$chunks")" = 0 ] && [ "$(realpath -e -- "$chunks")" = "$chunks" ] || fail 'unsafe chunks directory'
      target="$chunks/chunk-${index}"; temporary="$(mktemp "$chunks/.chunk-${index}.XXXXXX")"
      trap 'rm -f -- "$temporary"' EXIT
      printf %s '${payload}' > "$temporary"
      chown root:root -- "$temporary"; chmod 0600 -- "$temporary"; mv -f -- "$temporary" "$target"
    BASH
  }

  finalize_command = <<-BASH
    set -euo pipefail
    umask 077
    sha='${var.content_sha256}'; destination='${var.destination_path}'; staging='${local.staging_root}/${var.content_sha256}'; marker="$staging/${local.marker_name}"; chunks="$staging/chunks"; expected=${length(local.chunks)}
    fail() { printf '%s\n' "$1" >&2; exit 1; }
    require_root_dir() { [ -d "$1" ] && [ ! -L "$1" ] && [ "$(stat -c %u -- "$1")" = 0 ] && [ "$(realpath -e -- "$1")" = "$1" ] || fail "unsafe directory: $1"; }
    require_root_file() { [ -f "$1" ] && [ ! -L "$1" ] && [ "$(stat -c %u -- "$1")" = 0 ] && [ "$(realpath -e -- "$1")" = "$1" ] || fail "unsafe file: $1"; }
    marker_matches() { require_root_file "$1"; printf '%s\n' "$sha" | cmp -s - "$1"; }
    require_root_dir "$staging"; require_root_dir "$chunks"
    marker_matches "$marker" || fail 'unsafe staging marker'
    [ "$(find "$chunks" -mindepth 1 -maxdepth 1 -printf x | wc -c)" -eq "$expected" ] || fail 'unexpected chunk count'
    for index in $(seq 0 "$((expected - 1))"); do
      name="$(printf 'chunk-%06d' "$index")"; file="$chunks/$name"
      require_root_file "$file" || fail "unsafe chunk: $name"
    done
    parent="$(dirname -- "$destination")"; require_root_dir "$parent"
    target_marker="$destination${local.marker_name}"
    if [ -e "$destination" ] || [ -L "$destination" ]; then
      require_root_file "$destination"; marker_matches "$target_marker" || fail 'refusing unmanaged target'
      [ "$(sha256sum -- "$destination" | awk '{print $1}')" = "$sha" ] || fail 'target content hash mismatch'
    fi
    temporary="$(mktemp "$parent/.${local.destination_name}.XXXXXX")"; marker_temporary="$(mktemp "$parent/.${local.destination_name}.marker.XXXXXX")"
    trap 'rm -f -- "$temporary" "$marker_temporary"' EXIT
    for index in $(seq 0 "$((expected - 1))"); do cat -- "$chunks/$(printf 'chunk-%06d' "$index")"; done | base64 -d > "$temporary"
    [ "$(sha256sum -- "$temporary" | awk '{print $1}')" = "$sha" ] || fail 'decoded content hash mismatch'
    chown root:root -- "$temporary"; chmod 0600 -- "$temporary"; printf '%s\n' "$sha" > "$marker_temporary"; chown root:root -- "$marker_temporary"; chmod 0600 -- "$marker_temporary"
    mv -f -- "$temporary" "$destination"; mv -f -- "$marker_temporary" "$target_marker"
  BASH

  all_commands = concat([local.prepare_command, local.finalize_command], values(local.chunk_commands))
}

resource "terraform_data" "input_validation" {
  input = var.content_sha256

  lifecycle {
    precondition {
      condition     = sha256(base64decode(var.content_base64)) == var.content_sha256
      error_message = "content_sha256 必须等于解码后 content_base64 的 SHA-256。"
    }

    precondition {
      condition     = alltrue([for command in local.all_commands : length(command) <= 8192 && can(regex("^[\\x09\\x0A\\x0D\\x20-\\x7E]*$", command))])
      error_message = "完整渲染的 prepare、chunk 和 finalize 命令必须是 ASCII 且不超过 8192 字符。"
    }
  }
}

resource "qiniu_compute_instance_exec" "prepare" {
  instance_id = var.instance_id
  user        = var.user
  port        = var.port
  private_key = var.private_key
  shell       = var.shell
  command     = local.prepare_command

  store_stdout = false
  store_stderr = false
  triggers = {
    content_sha256   = var.content_sha256
    destination_path = var.destination_path
    chunk_count      = tostring(length(local.chunks))
    command_sha256   = sha256(local.prepare_command)
  }

  depends_on = [terraform_data.input_validation]
}

resource "qiniu_compute_instance_exec" "chunks" {
  for_each = local.chunks

  instance_id = var.instance_id
  user        = var.user
  port        = var.port
  private_key = var.private_key
  shell       = var.shell
  command     = local.chunk_commands[each.key]

  store_stdout = false
  store_stderr = false
  triggers = {
    content_sha256 = var.content_sha256
    chunk_index    = each.key
    chunk_sha256   = sha256(each.value)
    command_sha256 = sha256(local.chunk_commands[each.key])
  }

  depends_on = [qiniu_compute_instance_exec.prepare]
}

resource "qiniu_compute_instance_exec" "finalize" {
  instance_id = var.instance_id
  user        = var.user
  port        = var.port
  private_key = var.private_key
  shell       = var.shell
  command     = local.finalize_command

  store_stdout = false
  store_stderr = false
  triggers = {
    content_sha256 = var.content_sha256
    chunk_count    = tostring(length(local.chunks))
    command_sha256 = sha256(local.finalize_command)
  }

  depends_on = [qiniu_compute_instance_exec.chunks]
}
