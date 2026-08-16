locals {
  project_dir = "/opt/las-dsh-installer/project"

  extra_vars_base64 = base64encode(jsonencode({
    nginx_proxy_port             = var.dsh_web_port
    dsh_web_public_authority     = var.dsh_web_public_authority
    preview_public_authorities   = var.preview_public_authorities
    preview_ports                = var.preview_ports
    code_server_proxy_port       = var.code_server_web_port
    code_server_public_authority = var.code_server_public_authority
    dsh_web_username             = var.dsh_web_username
    dsh_web_password             = var.dsh_web_password
    code_server_password         = var.code_server_password
  }))

  bootstrap_content = templatefile("${path.module}/templates/bootstrap.sh.tftpl", {})

  bootstrap = {
    content     = base64encode(local.bootstrap_content)
    file_mode   = "0700"
    sha256      = sha256(local.bootstrap_content)
    target_path = "/opt/las-dsh-installer/bootstrap/bootstrap.sh"
  }

  install_command = "exec '${local.bootstrap.target_path}' '${local.extra_vars_base64}'"
}

module "ansible_runtime" {
  source = "./ansible"

  target_dir = local.project_dir
}
