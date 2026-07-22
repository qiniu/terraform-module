locals {
  install_checksum = nonsensitive(sha256(jsonencode({
    version          = var.runnerd_version
    revision         = var.runnerd_install_revision
    port             = var.runnerd_port
    config           = var.config_content
    pem_base64       = var.github_app_private_key_base64
    bootstrap_admin  = var.bootstrap_admin_github_user_id
    install_template = file("${path.module}/templates/install.sh.tftpl")
  })))
  install_command = templatefile("${path.module}/templates/install.sh.tftpl", {
    runnerd_version                = var.runnerd_version
    runnerd_port                   = var.runnerd_port
    config_content_base64          = base64encode(var.config_content)
    github_app_private_key_base64  = var.github_app_private_key_base64
    bootstrap_admin_github_user_id = var.bootstrap_admin_github_user_id
  })
  verify_command = templatefile("${path.module}/templates/verify.sh.tftpl", {
    bootstrap_admin_github_user_id = var.bootstrap_admin_github_user_id
    runnerd_port                   = var.runnerd_port
  })
  verify_checksum = nonsensitive(sha256(jsonencode({
    install_checksum = local.install_checksum
    verify_template  = file("${path.module}/templates/verify.sh.tftpl")
  })))
  destroy_command = file("${path.module}/templates/destroy.sh.tftpl")
}
