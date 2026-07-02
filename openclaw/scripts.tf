module "openclaw_scripts" {
  source              = "./openclaw_scripts"
  openclaw_password   = var.openclaw_user_password
  openclaw_public_key = qiniu_compute_key_pair.openclaw.public_key
  qiniu_maas_api_key  = var.qiniu_maas_api_key
  gateway_port        = local.internal_gateway_port
  channel_qq_token    = var.channel_qq_token
}


resource "qiniu_compute_instance_exec" "init" {
  instance_id = qiniu_compute_instance.openclaw.id
  user        = "openclaw"
  port        = "22"
  private_key = qiniu_compute_key_pair.openclaw.private_key

  shell   = "bash"
  command = "for i in $(seq 1 120); do [ -f /var/log/openclaw-init-complete ] && break; echo 'Waiting for OpenClaw initialization to complete...'; sleep 5; done; [ -f /var/log/openclaw-init-complete ] || { echo 'OpenClaw init not completed within 10 minutes'; exit 1; }"
}

resource "qiniu_compute_instance_exec" "script_model_config" {
  instance_id = qiniu_compute_instance.openclaw.id
  user        = "openclaw"
  port        = "22"
  private_key = qiniu_compute_key_pair.openclaw.private_key

  shell   = "bash"
  command = module.openclaw_scripts.model_config_script
}

resource "qiniu_compute_instance_exec" "script_gateway_config" {
  depends_on = [
    # 这几个配置资源要串行执行，并发执行可能导致openclaw一些命令执行失败
    qiniu_compute_instance_exec.script_model_config
  ]

  instance_id = qiniu_compute_instance.openclaw.id
  user        = "openclaw"
  port        = "22"
  private_key = qiniu_compute_key_pair.openclaw.private_key

  shell   = "bash"
  command = module.openclaw_scripts.gateway_config_script
}

resource "qiniu_compute_instance_exec" "script_channel_qq_config" {
  count = var.channel_qq_token != "" ? 1 : 0

  depends_on = [
    # 这几个配置资源要串行执行，并发执行可能导致openclaw一些命令执行失败
    qiniu_compute_instance_exec.script_gateway_config
  ]

  instance_id = qiniu_compute_instance.openclaw.id
  user        = "openclaw"
  port        = "22"
  private_key = qiniu_compute_key_pair.openclaw.private_key

  shell           = "bash"
  command         = module.openclaw_scripts.channel_qq_apply_script
  destroy_command = module.openclaw_scripts.channel_qq_destroy_script

  continue_on_destroy_failure = false // 销毁失败时，直接报错停下来
}
