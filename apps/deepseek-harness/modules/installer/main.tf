locals {
  nginx_transaction_helper               = file("${path.module}/templates/nginx-transaction.sh")
  deployment_environment_skill_installer = file("${path.module}/templates/deployment-environment-skill.py")

  deployment_environment_skill = templatefile("${path.module}/templates/deployment-environment.SKILL.md.tftpl", {
    public_authority             = var.public_authority
    preview_count                = var.preview_count
    preview_ports                = var.preview_ports
    preview_public_authorities   = var.preview_public_authorities
    code_server_port             = var.code_server_port
    code_server_proxy_port       = var.code_server_proxy_port
    code_server_public_authority = var.code_server_public_authority
  })

  install_command = templatefile("${path.module}/templates/install.sh.tftpl", {
    dsh_version                            = var.dsh_version
    node_version                           = var.node_version
    dsh_port                               = var.dsh_port
    proxy_port                             = var.proxy_port
    public_authority                       = var.public_authority
    preview_count                          = var.preview_count
    preview_ports                          = var.preview_ports
    preview_public_authorities             = var.preview_public_authorities
    code_server_version                    = var.code_server_version
    code_server_port                       = var.code_server_port
    code_server_proxy_port                 = var.code_server_proxy_port
    code_server_public_authority           = var.code_server_public_authority
    deployment_environment_skill           = local.deployment_environment_skill
    deployment_environment_skill_installer = local.deployment_environment_skill_installer
    nginx_transaction_helper               = local.nginx_transaction_helper
    web_username                           = var.web_username
    web_password_base64                    = base64encode(var.web_password)
    code_server_password_base64            = base64encode(var.code_server_password)
  })
}
