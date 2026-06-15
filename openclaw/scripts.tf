module "openclaw_scripts" {
  source             = "./openclaw_scripts"
  openclaw_password  = var.root_password
  qiniu_maas_api_key = var.qiniu_maas_api_key
  default_model      = var.default_model
}

resource "terraform_data" "script_init" {
  triggers_replace = {
    instance_id = qiniu_compute_instance.openclaw.id
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
      module.openclaw_scripts.init_script
    ]
  }
}


resource "terraform_data" "script_model_config" {
  depends_on = [
    script_init
  ]

  triggers_replace = {
    script_content_hash = sha256(module.openclaw_scripts.model_config_script)
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
      module.openclaw_scripts.model_config_script
    ]
  }
}

resource "terraform_data" "script_gateway_config" {
  depends_on = [
    # 这几个配置资源要串行执行，并发执行可能导致openclaw一些命令执行失败
    script_model_config
  ]

  triggers_replace = {
    script_content_hash = sha256(module.openclaw_scripts.gateway_config_script)
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
      module.openclaw_scripts.gateway_config_script
    ]
  }
}
