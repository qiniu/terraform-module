locals {
  staging_root       = "/var/lib/instance-exec-file-transfer"
  marker_name        = ".instance-exec-file-transfer-managed"
  encoded_chunks     = [for characters in chunklist(split("", var.content_base64), var.chunk_size) : join("", characters)]
  chunks             = { for index, payload in local.encoded_chunks : format("%06d", index) => payload }
  destination_parent = dirname(var.destination_path)
  destination_name   = basename(var.destination_path)

  prepare_command = templatefile("${path.module}/templates/prepare.sh.tftpl", {
    content_sha256   = var.content_sha256
    destination_path = var.destination_path
    destination_name = local.destination_name
    marker_name      = local.marker_name
    staging_root     = local.staging_root
  })

  chunk_commands = {
    for index, payload in local.chunks : index => templatefile("${path.module}/templates/chunk.sh.tftpl", {
      content_sha256 = var.content_sha256
      index          = index
      marker_name    = local.marker_name
      payload        = payload
      staging_root   = local.staging_root
    })
  }

  finalize_command = templatefile("${path.module}/templates/finalize.sh.tftpl", {
    chunk_count      = length(local.chunks)
    content_sha256   = var.content_sha256
    destination_path = var.destination_path
    destination_name = local.destination_name
    marker_name      = local.marker_name
    staging_root     = local.staging_root
  })

  all_commands = concat([local.prepare_command, local.finalize_command], values(local.chunk_commands))
}

resource "terraform_data" "input_validation" {
  input = var.content_sha256

  lifecycle {
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
    content_sha256     = var.content_sha256
    chunk_index        = each.key
    chunk_sha256       = sha256(each.value)
    prepare_generation = sha256(local.prepare_command)
    command_sha256     = sha256(local.chunk_commands[each.key])
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
