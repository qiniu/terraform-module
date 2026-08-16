locals {
  runtime_directories = sort(distinct(concat(
    [
      "/opt/las-dsh-installer",
      "/opt/las-dsh-installer/bootstrap",
    ],
    [for metadata in values(var.runtime_file_metadata) : dirname(metadata.target_path)],
  )))

  prepare_command = <<-EOT
    set -euo pipefail

    ensure_root_directory() {
      local directory="$1"
      if [ -e "$${directory}" ] || [ -L "$${directory}" ]; then
        [ -d "$${directory}" ] && [ ! -L "$${directory}" ] || exit 1
        [ "$(realpath -e "$${directory}")" = "$${directory}" ] || exit 1
        [ "$(stat -c '%u:%g' "$${directory}")" = '0:0' ] || exit 1
      else
        install -d -o root -g root -m 0755 "$${directory}"
      fi
    }

${join("\n", [for directory in local.runtime_directories : "    ensure_root_directory '${directory}'"])}
  EOT
}

resource "qiniu_compute_instance_exec" "prepare" {
  instance_id = var.instance_id
  user        = "root"
  port        = "22"
  private_key = var.private_key
  shell       = "bash"
  command     = local.prepare_command

  store_stdout = false
  store_stderr = false
}

module "runtime_file" {
  for_each = var.runtime_file_metadata
  source   = "../instance-exec-file-transfer"

  depends_on = [qiniu_compute_instance_exec.prepare]

  instance_id    = var.instance_id
  user           = "root"
  port           = "22"
  private_key    = var.private_key
  content        = var.runtime_file_contents[each.key]
  content_sha256 = each.value.sha256
  target_path    = each.value.target_path
  file_mode      = each.value.file_mode
}

module "runtime_manifest" {
  source = "../instance-exec-file-transfer"

  depends_on = [module.runtime_file]

  instance_id    = var.instance_id
  user           = "root"
  port           = "22"
  private_key    = var.private_key
  content        = var.runtime_manifest.content
  content_sha256 = var.runtime_manifest.sha256
  target_path    = var.runtime_manifest.target_path
  file_mode      = var.runtime_manifest.file_mode
}

module "bootstrap" {
  source = "../instance-exec-file-transfer"

  depends_on = [qiniu_compute_instance_exec.prepare]

  instance_id    = var.instance_id
  user           = "root"
  port           = "22"
  private_key    = var.private_key
  content        = var.bootstrap.content
  content_sha256 = var.bootstrap.sha256
  target_path    = var.bootstrap.target_path
  file_mode      = var.bootstrap.file_mode
}
