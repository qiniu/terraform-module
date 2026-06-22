module "openclaw_scripts" {
  source             = "./openclaw_scripts"
  openclaw_password  = var.root_password
  qiniu_maas_api_key = var.qiniu_maas_api_key
  gateway_port       = local.internal_gateway_port
  channel_qq_token   = var.channel_qq_token
}

resource "terraform_data" "script_init" {
  triggers_replace = {
    instance_id  = qiniu_compute_instance.openclaw.id
    ssh_host     = local.ssh_endpoint[0]
    ssh_port     = local.ssh_endpoint[1]
    ssh_password = var.root_password
  }

  connection {
    type     = "ssh"
    host     = local.ssh_endpoint[0]
    user     = "root"
    port     = local.ssh_endpoint[1]
    password = var.root_password
  }

  provisioner "remote-exec" {
    inline = [
      nonsensitive(module.openclaw_scripts.init_script),
    ]
  }
}


resource "terraform_data" "script_model_config" {
  depends_on = [
    terraform_data.script_init
  ]

  triggers_replace = {
    script_content = module.openclaw_scripts.model_config_script
    ssh_host       = local.ssh_endpoint[0]
    ssh_port       = local.ssh_endpoint[1]
    ssh_password   = var.root_password
  }

  connection {
    type     = "ssh"
    host     = local.ssh_endpoint[0]
    user     = "openclaw"
    port     = local.ssh_endpoint[1]
    password = var.root_password
  }

  provisioner "remote-exec" {
    inline = [
      nonsensitive(module.openclaw_scripts.model_config_script),
    ]
  }
}

resource "terraform_data" "script_gateway_config" {
  depends_on = [
    # 这几个配置资源要串行执行，并发执行可能导致openclaw一些命令执行失败
    terraform_data.script_model_config
  ]

  triggers_replace = {
    script_content = module.openclaw_scripts.gateway_config_script
    version        = 1
    ssh_host       = local.ssh_endpoint[0]
    ssh_port       = local.ssh_endpoint[1]
    ssh_password   = var.root_password
  }

  connection {
    type     = "ssh"
    host     = local.ssh_endpoint[0]
    user     = "openclaw"
    port     = local.ssh_endpoint[1]
    password = var.root_password
  }

  provisioner "remote-exec" {
    inline = [
      nonsensitive(module.openclaw_scripts.gateway_config_script),
    ]
  }
}

resource "terraform_data" "script_channel_qq_config" {
  count = var.channel_qq_token != "" ? 1 : 0

  depends_on = [
    # 这几个配置资源要串行执行，并发执行可能导致openclaw一些命令执行失败
    terraform_data.script_gateway_config
  ]

  # destroy provisioner 只能引用 self，所以销毁所需信息（脚本 + ssh 连接参数）全部塞进 triggers_replace
  triggers_replace = {
    channel_qq_apply_script   = module.openclaw_scripts.channel_qq_apply_script
    channel_qq_destroy_script = module.openclaw_scripts.channel_qq_destroy_script
    ssh_host       = local.ssh_endpoint[0]
    ssh_port       = local.ssh_endpoint[1]
    ssh_password   = var.root_password
  }

  connection {
    type     = "ssh"
    host     = self.triggers_replace.ssh_host
    user     = "openclaw"
    port     = self.triggers_replace.ssh_port
    password = self.triggers_replace.ssh_password
  }

  provisioner "remote-exec" {
    inline = [
      nonsensitive(self.triggers_replace.channel_qq_apply_script),
    ]
  }

  # 销毁时清掉 QQ channel 配置，保证幂等再创建。
  # 实例被销毁时 SSH 通常不可达，on_failure=continue 避免阻塞 terraform destroy。
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      nonsensitive(self.triggers_replace.channel_qq_destroy_script),
    ]
  }
}
