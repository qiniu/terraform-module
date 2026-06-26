# ============================================================================
# cloud_init_only 模式专用的全量初始化脚本
# ============================================================================
# 当父模块 cloud_init_only=true 时，把 init + model + gateway + channel_qq
# 四段脚本拼接为单个 user_data，由 cloud-init 在实例首次启动时一次性执行，
# 跳过 SSH remote-exec。各子脚本复用 init.tf / models.tf / gateway.tf /
# channel_qq.tf 已渲染好的 local（templatefile 只调一次），保证与 SSH 模式语义一致。
# 执行机制与平台 stdin 约束详见 cloud_init_full.sh.tmpl 头部注释。

locals {
  cloud_init_full_script = templatefile("${path.module}/templates/cloud_init_full.sh.tmpl", {
    init_script_b64       = base64encode(local.init_script)
    model_script_b64      = base64encode(local.model_config_script)
    gateway_script_b64    = base64encode(local.gateway_config_script)
    channel_qq_script_b64 = base64encode(local.channel_qq_apply_script)
    channel_qq_enabled    = var.channel_qq_token != ""
  })
}

output "cloud_init_full_script" {
  description = "cloud_init_only 模式下注入 user_data 的全量脚本（init + model + gateway + channel_qq）"
  value       = local.cloud_init_full_script
}
