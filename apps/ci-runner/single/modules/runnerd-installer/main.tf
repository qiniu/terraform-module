locals {
  install_command = templatefile("${path.module}/templates/install.sh.tftpl", {
    runnerd_version                = var.runnerd_version
    runnerd_port                   = var.runnerd_port
    config_content_base64          = base64encode(var.config_content)
    github_app_private_key_base64  = var.github_app_private_key_base64
    bootstrap_admin_github_user_id = var.bootstrap_admin_github_user_id
  })
  install_checksum = nonsensitive(sha256(local.install_command))
}
