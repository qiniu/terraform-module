module "infrastructure" {
  source = "./modules/infrastructure"

  runnerd_port            = var.runnerd_port
  instance_type           = var.instance_type
  system_disk_size        = var.system_disk_size
  internet_max_bandwidth  = var.internet_max_bandwidth
  enable_ssh_port_forward = var.enable_ssh_port_forward
}

module "config" {
  source = "./modules/config-generator"

  public_url                 = module.infrastructure.public_url
  runnerd_port               = var.runnerd_port
  github_app_id              = var.github_app_id
  github_app_slug            = var.github_app_slug
  github_oauth_client_id     = var.github_oauth_client_id
  github_oauth_client_secret = var.github_oauth_client_secret
}

module "runnerd" {
  source = "./modules/runnerd-installer"

  runnerd_version                = var.runnerd_version
  runnerd_port                   = var.runnerd_port
  config_content                 = module.config.config_content
  github_app_private_key_base64  = var.github_app_private_key_base64
  bootstrap_admin_github_user_id = var.bootstrap_admin_github_user_id
}

resource "qiniu_compute_instance_exec" "install_runnerd" {
  instance_id = module.infrastructure.instance_id
  user        = "root"
  port        = "22"
  private_key = module.infrastructure.deployment_private_key

  shell   = "bash"
  command = module.runnerd.install_command

  triggers = {
    install_checksum = module.runnerd.install_checksum
  }

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }
}
