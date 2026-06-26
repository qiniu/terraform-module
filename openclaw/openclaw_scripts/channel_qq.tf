variable "channel_qq_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "可选的 QQ 机器人凭证，格式为 AppID:AppSecret；为空时跳过 QQ channel 初始化"
}

locals {
  channel_qq_apply_script = templatefile("${path.module}/templates/channel_qq.sh.tmpl", {
    channel_qq_token = var.channel_qq_token
  })

  channel_qq_destroy_script = templatefile("${path.module}/templates/channel_qq_destroy.sh.tmpl", {})
}

output "channel_qq_apply_script" {
  value = local.channel_qq_apply_script
}

output "channel_qq_destroy_script" {
  value = local.channel_qq_destroy_script
}
