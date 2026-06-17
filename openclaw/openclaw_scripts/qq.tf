variable "qq_secret" {
  type        = string
  sensitive   = true
  default     = ""
  description = "可选的 QQ 机器人凭证，格式为 AppID:AppSecret；为空时跳过 QQ channel 初始化"
}

output "qq_apply_script" {
  value = templatefile("${path.module}/templates/qq.sh.tmpl", {
    qq_secret = var.qq_secret
  })
}

output "qq_destroy_script" {
  value = templatefile("${path.module}/templates/qq_destroy.sh.tmpl", {})
}
