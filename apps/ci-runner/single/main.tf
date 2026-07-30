locals {
  # runnerd 监听及 HTTPProxy 转发的实例内部端口，固定值，无需外部配置
  runnerd_port = 25500
  # runnerd 版本，升级时修改此处
  runnerd_version = "v0.2.6"
  github_app_private_key = trimspace(
    var.github_app_private_key != null && trimspace(var.github_app_private_key) != ""
    ? var.github_app_private_key
    : try(base64decode(split(",", trimspace(var.github_app_private_key_data_uri))[1]), "")
  )
}

check "github_app_private_key_input" {
  assert {
    condition = (
      (length(trimspace(var.github_app_private_key == null ? "" : var.github_app_private_key)) > 0 ? 1 : 0) +
      (length(trimspace(var.github_app_private_key_data_uri == null ? "" : var.github_app_private_key_data_uri)) > 0 ? 1 : 0) == 1
    )
    error_message = "github_app_private_key 和 github_app_private_key_data_uri 必须且只能设置一个。"
  }
}

module "github_utils" {
  source = "./modules/github-utils"

  github_login = var.bootstrap_admin_github_login
}

module "infrastructure" {
  source = "./modules/infrastructure"

  runnerd_port            = local.runnerd_port
  instance_type           = var.instance_type
  system_disk_size        = var.system_disk_size
  internet_max_bandwidth  = var.internet_max_bandwidth
  enable_ssh_port_forward = var.enable_ssh_port_forward

  cost_charge_type = var.cost_charge_type
  cost_period      = var.cost_period
  cost_period_unit = var.cost_period_unit

  instance_password = var.instance_password
}

module "config" {
  source = "./modules/config-generator"

  public_url                 = module.infrastructure.public_url
  runnerd_port               = local.runnerd_port
  github_app_id              = var.github_app_id
  github_app_slug            = var.github_app_slug
  github_oauth_client_id     = var.github_oauth_client_id
  github_oauth_client_secret = var.github_oauth_client_secret
}

module "runnerd" {
  source = "./modules/runnerd-installer"

  runnerd_version                = local.runnerd_version
  runnerd_port                   = local.runnerd_port
  config_content                 = module.config.config_content
  github_app_private_key         = local.github_app_private_key
  bootstrap_admin_github_user_id = module.github_utils.user_id
}

resource "qiniu_compute_instance_exec" "install_runnerd" {
  instance_id = module.infrastructure.instance_id
  user        = "root"
  port        = "22"
  private_key = module.infrastructure.deployment_private_key

  shell   = "bash"
  command = module.runnerd.install_command

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }
}
