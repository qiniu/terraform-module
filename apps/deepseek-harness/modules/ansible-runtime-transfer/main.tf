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
  command = templatefile("${path.module}/templates/prepare.sh.tftpl", {
    target_directories = local.target_directories
  })

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
