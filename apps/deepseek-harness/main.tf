locals {
  dsh_web_username     = "admin"
  dsh_web_password     = nonsensitive(var.dsh_web_password) == "" ? random_password.dsh_web[0].result : var.dsh_web_password
  code_server_password = nonsensitive(var.code_server_password) == "" ? random_password.code_server[0].result : var.code_server_password
}

resource "random_password" "dsh_web" {
  count = nonsensitive(var.dsh_web_password) == "" ? 1 : 0

  length           = 24
  upper            = true
  lower            = true
  numeric          = true
  special          = true
  override_special = "-._~"
}

resource "random_password" "code_server" {
  count = nonsensitive(var.code_server_password) == "" ? 1 : 0

  length           = 30
  upper            = true
  lower            = true
  numeric          = true
  special          = true
  override_special = "-._~"
}

module "infrastructure" {
  source = "./modules/infrastructure"

  image_id                = var.image_id
  preview_count           = var.preview_count
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

  dsh_web_proxy_port              = module.infrastructure.dsh_web_proxy_port
  dsh_web_public_authority        = module.infrastructure.dsh_web_public_authority
  static_preview_proxy_port       = module.infrastructure.static_preview_proxy_port
  static_preview_public_authority = module.infrastructure.static_preview_public_authority
  las_instance_id                 = module.infrastructure.instance_id
  las_region_id                   = module.infrastructure.instance_region_id
  las_region_name                 = module.infrastructure.instance_region_name
  preview_ports                   = module.infrastructure.preview_ports
  preview_public_authorities      = module.infrastructure.preview_public_authorities
  code_server_proxy_port          = module.infrastructure.code_server_proxy_port
  code_server_public_authority    = module.infrastructure.code_server_public_authority
  dsh_web_username                = local.dsh_web_username
  dsh_web_password                = local.dsh_web_password
  code_server_password            = local.code_server_password
}

module "ansible_runtime_transfer" {
  source = "./modules/ansible-runtime-transfer"

  instance_id   = module.infrastructure.instance_id
  private_key   = module.infrastructure.deployment_private_key
  file_contents = module.installer.file_contents
  file_metadata = module.installer.file_metadata
}

resource "terraform_data" "install_dsh_runtime" {
  triggers_replace = nonsensitive(module.installer.file_metadata)
}

resource "qiniu_compute_instance_exec" "install_dsh" {
  depends_on = [module.ansible_runtime_transfer]

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
    replace_triggered_by = [terraform_data.install_dsh_runtime]
  }
}
