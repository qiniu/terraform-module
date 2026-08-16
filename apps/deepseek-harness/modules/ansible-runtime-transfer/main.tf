locals {
  target_directories = sort(distinct(concat(
    ["/opt/las-dsh-installer"],
    [for target_path in keys(var.file_metadata) : dirname(target_path)],
  )))
}

resource "qiniu_compute_instance_exec" "prepare" {
  instance_id = var.instance_id
  user        = "root"
  port        = "22"
  private_key = var.private_key
  shell       = "bash"
  command     = <<-EOT
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

${join("\n", [for directory in local.target_directories : "    ensure_root_directory '${directory}'"])}
  EOT

  store_stdout = false
  store_stderr = false
}

module "file" {
  for_each = var.file_metadata
  source   = "../instance-exec-file-transfer"

  depends_on = [qiniu_compute_instance_exec.prepare]

  instance_id    = var.instance_id
  user           = "root"
  port           = "22"
  private_key    = var.private_key
  content        = var.file_contents[each.key]
  content_sha256 = each.value.sha256
  target_path    = each.key
  file_mode      = each.value.file_mode
}
