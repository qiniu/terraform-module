locals {
  install_template              = file("${path.module}/templates/install.sh.tftpl")
  normalized_private_key_base64 = replace(replace(var.github_app_private_key_base64, "\r", ""), "\n", "")
  encoded_config_content        = base64encode(var.config_content)
  install_checksum = nonsensitive(sha256(jsonencode({
    version          = var.runnerd_version
    revision         = var.runnerd_install_revision
    config           = var.config_content
    pem_base64       = local.normalized_private_key_base64
    bootstrap_admin  = var.bootstrap_admin_github_user_id
    install_template = local.install_template
  })))
  install_command = templatefile("${path.module}/templates/install.sh.tftpl", {
    runnerd_version                = var.runnerd_version
    config_content_base64          = local.encoded_config_content
    github_app_private_key_base64  = local.normalized_private_key_base64
    bootstrap_admin_github_user_id = var.bootstrap_admin_github_user_id
  })
  destroy_command = templatefile("${path.module}/templates/destroy.sh.tftpl", {})
}
