locals {
  bootstrap_content     = file("${path.module}/scripts/bootstrap.sh")
  bootstrap_target_path = "/opt/las-dsh-installer/bootstrap/bootstrap.sh"

  install_command = format(
    "exec '%s' '%s'",
    local.bootstrap_target_path,
    base64encode(jsonencode(merge({
      dsh_web_proxy_port              = var.dsh_web_proxy_port
      dsh_web_public_authority        = var.dsh_web_public_authority
      static_preview_proxy_port       = var.static_preview_proxy_port
      static_preview_public_authority = var.static_preview_public_authority
      las_instance_id                 = var.las_instance_id
      las_region_id                   = var.las_region_id
      las_region_name                 = var.las_region_name
      preview_public_authorities      = var.preview_public_authorities
      preview_ports                   = var.preview_ports
      enable_code_server              = var.enable_code_server
      dsh_web_username                = var.dsh_web_username
      dsh_web_password                = var.dsh_web_password
      }, var.enable_code_server ? {
      code_server_proxy_port       = var.code_server_proxy_port
      code_server_public_authority = var.code_server_public_authority
      code_server_password         = var.code_server_password
    } : {}))),
  )
}

module "ansible_runtime" {
  source = "./ansible"

  target_dir = "/opt/las-dsh-installer/project"
}
