variable "runnerd_version" {
  description = "要安装的 runnerd GitHub Release tag。"
  type        = string
}

variable "runnerd_install_revision" {
  description = "用于显式触发重新安装的 revision。"
  type        = string
}

variable "runnerd_port" {
  description = "runnerd 监听和健康检查端口。"
  type        = number
}

variable "config_content" {
  description = "完整的 runnerd 配置内容。"
  type        = string
  sensitive   = true
}

variable "github_app_private_key_base64" {
  description = "Base64 编码的 GitHub App PEM 私钥。"
  type        = string
  sensitive   = true
}

variable "bootstrap_admin_github_user_id" {
  description = "首次引导管理员使用的 GitHub user ID。"
  type        = number
}
