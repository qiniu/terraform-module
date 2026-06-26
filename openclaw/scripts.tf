module "openclaw_scripts" {
  source             = "./openclaw_scripts"
  openclaw_password  = var.root_password
  qiniu_maas_api_key = var.qiniu_maas_api_key
  gateway_port       = local.internal_gateway_port
  channel_qq_token   = var.channel_qq_token
}

resource "terraform_data" "wait_init_done" {
  count = var.cloud_init_only ? 0 : 1

  triggers_replace = {
    script_content = "for i in $(seq 1 120); do [ -f /var/log/openclaw-init-complete ] && break; echo 'Waiting for OpenClaw initialization to complete...'; sleep 5; done; [ -f /var/log/openclaw-init-complete ] || { echo 'OpenClaw init not completed within 10 minutes'; exit 1; }"
    ssh_host       = local.ssh_endpoint[0]
    ssh_port       = local.ssh_endpoint[1]
    private_key    = module.openclaw_scripts.openclaw_private_key
  }

  connection {
    type        = "ssh"
    host        = self.triggers_replace.ssh_host
    user        = "openclaw"
    port        = self.triggers_replace.ssh_port
    private_key = self.triggers_replace.private_key
  }

  provisioner "remote-exec" {
    inline = [
      self.triggers_replace.script_content,
    ]
  }
}

resource "terraform_data" "script_model_config" {
  count = var.cloud_init_only ? 0 : 1

  depends_on = [
    terraform_data.wait_init_done
  ]

  triggers_replace = {
    script_content = module.openclaw_scripts.model_config_script
    ssh_host       = local.ssh_endpoint[0]
    ssh_port       = local.ssh_endpoint[1]
    private_key    = module.openclaw_scripts.openclaw_private_key
  }

  connection {
    type        = "ssh"
    host        = self.triggers_replace.ssh_host
    user        = "openclaw"
    port        = self.triggers_replace.ssh_port
    private_key = self.triggers_replace.private_key
  }

  provisioner "remote-exec" {
    inline = [
      nonsensitive(self.triggers_replace.script_content),
    ]
  }
}

resource "terraform_data" "script_gateway_config" {
  count = var.cloud_init_only ? 0 : 1

  depends_on = [
    # 这几个配置资源要串行执行，并发执行可能导致openclaw一些命令执行失败
    terraform_data.script_model_config
  ]

  triggers_replace = {
    script_content = module.openclaw_scripts.gateway_config_script
    version        = 1
    ssh_host       = local.ssh_endpoint[0]
    ssh_port       = local.ssh_endpoint[1]
    private_key    = module.openclaw_scripts.openclaw_private_key
  }

  connection {
    type        = "ssh"
    host        = self.triggers_replace.ssh_host
    user        = "openclaw"
    port        = self.triggers_replace.ssh_port
    private_key = self.triggers_replace.private_key
  }

  provisioner "remote-exec" {
    inline = [
      nonsensitive(self.triggers_replace.script_content),
    ]
  }
}

resource "terraform_data" "script_channel_qq_config" {
  # destroy 清理依赖 SSH，cloud_init_only 模式下不可用（实例销毁时配置随磁盘消失）
  count = (var.cloud_init_only || var.channel_qq_token == "") ? 0 : 1

  depends_on = [
    # 这几个配置资源要串行执行，并发执行可能导致openclaw一些命令执行失败
    terraform_data.script_gateway_config
  ]

  # destroy provisioner 只能引用 self，所以销毁所需信息（脚本 + ssh 连接参数）全部塞进 triggers_replace
  triggers_replace = {
    channel_qq_apply_script   = module.openclaw_scripts.channel_qq_apply_script
    channel_qq_destroy_script = module.openclaw_scripts.channel_qq_destroy_script
    ssh_host                  = local.ssh_endpoint[0]
    ssh_port                  = local.ssh_endpoint[1]
    private_key               = module.openclaw_scripts.openclaw_private_key
  }

  connection {
    type        = "ssh"
    host        = self.triggers_replace.ssh_host
    user        = "openclaw"
    port        = self.triggers_replace.ssh_port
    private_key = self.triggers_replace.private_key
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
