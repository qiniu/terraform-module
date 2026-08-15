locals {
  dsh_version            = "0.1.0-rc.6"
  node_version           = "24.19.0"
  uv_version             = "0.12.5"
  dsh_port               = 3080
  nginx_proxy_port       = 3081
  preview_ports          = [30080, 30081, 30082, 30083]
  code_server_version    = "4.132.0"
  code_server_port       = 3086
  code_server_proxy_port = 3087
  web_username           = "admin"
}

resource "random_password" "web" {
  length           = 24
  upper            = true
  lower            = true
  numeric          = true
  special          = true
  override_special = "-._~"
}

resource "random_password" "code_server" {
  length           = 32
  upper            = true
  lower            = true
  numeric          = true
  special          = true
  override_special = "-._~"
}

module "infrastructure" {
  source = "./modules/infrastructure"

  nginx_proxy_port        = local.nginx_proxy_port
  preview_count           = var.preview_count
  code_server_proxy_port  = local.code_server_proxy_port
  instance_type           = var.instance_type
  system_disk_size        = var.system_disk_size
  internet_max_bandwidth  = var.internet_max_bandwidth
  enable_ssh_port_forward = var.enable_ssh_port_forward
  cost_charge_type        = var.cost_charge_type
  cost_period             = var.cost_period
  cost_period_unit        = var.cost_period_unit
  instance_password       = var.instance_password
}

module "installer" {
  source = "./modules/ansible-installer"

  dsh_version                  = local.dsh_version
  node_version                 = local.node_version
  uv_version                   = local.uv_version
  dsh_port                     = local.dsh_port
  nginx_proxy_port             = local.nginx_proxy_port
  public_authority             = module.infrastructure.public_authority
  preview_count                = var.preview_count
  preview_ports                = local.preview_ports
  preview_public_authorities   = module.infrastructure.preview_public_authorities
  code_server_version          = local.code_server_version
  code_server_port             = local.code_server_port
  code_server_proxy_port       = local.code_server_proxy_port
  code_server_public_authority = module.infrastructure.code_server_public_authority
  web_username                 = local.web_username
  web_password                 = random_password.web.result
  code_server_password         = random_password.code_server.result
}

resource "qiniu_compute_instance_exec" "install_dsh" {
  instance_id = module.infrastructure.instance_id
  user        = "root"
  port        = "22"
  private_key = module.infrastructure.deployment_private_key
  shell       = "bash"
  command     = module.installer.install_command

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }

  lifecycle {
    precondition {
      condition = nonsensitive(
        !var.enable_ssh_port_forward ||
        (var.instance_password != null && trimspace(var.instance_password) != "")
      )
      error_message = "启用 SSH PortForward 时必须设置 instance_password。"
    }
  }
}
