variable "channel_qq_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "可选的 QQ 机器人凭证，格式为 AppID:AppSecret；为空时跳过 QQ channel 初始化"
}

output "channel_qq_apply_script" {
  value = templatefile("${path.module}/templates/channel_qq.sh.tmpl", {
    channel_qq_token = var.channel_qq_token
  })
}

output "channel_qq_destroy_script" {
  value = templatefile("${path.module}/templates/channel_qq_destroy.sh.tmpl", {})
}
