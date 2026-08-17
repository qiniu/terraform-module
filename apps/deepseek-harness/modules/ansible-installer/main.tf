locals {
  bootstrap_content     = file("${path.module}/scripts/bootstrap.sh")
  bootstrap_target_path = "/opt/las-dsh-installer/bootstrap/bootstrap.sh"

  install_command = format(
    "exec '%s' '%s'",
    local.bootstrap_target_path,
    base64encode(jsonencode({
      nginx_proxy_port             = var.dsh_web_port
      dsh_web_public_authority     = var.dsh_web_public_authority
      dsh_instance_id              = var.dsh_instance_id
      dsh_region_id                = var.dsh_region_id
      dsh_region_name              = var.dsh_region_name
      preview_public_authorities   = var.preview_public_authorities
      preview_ports                = var.preview_ports
      code_server_proxy_port       = var.code_server_web_port
      code_server_public_authority = var.code_server_public_authority
      dsh_web_username             = var.dsh_web_username
      dsh_web_password             = var.dsh_web_password
      code_server_password         = var.code_server_password
    })),
  )
}

module "ansible_runtime" {
  source = "./ansible"

  target_dir = "/opt/las-dsh-installer/project"
}
