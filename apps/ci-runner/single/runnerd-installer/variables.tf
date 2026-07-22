variable "runnerd_version" {
  description = "要安装的 runnerd GitHub Release tag。"
  type        = string

  validation {
    condition = (
      can(regex("^[0-9A-Za-z._-]+$", var.runnerd_version)) &&
      lower(var.runnerd_version) != "latest"
    )
    error_message = "runnerd_version 必须是非空的安全版本标签，仅可包含字母、数字、点、下划线和连字符，且不能为 latest。"
  }
}

variable "runnerd_install_revision" {
  description = "用于显式触发重新安装的安全 revision；空字符串表示未设置。"
  type        = string
  default     = ""

  validation {
    condition = (
      var.runnerd_install_revision == "" ||
      can(regex("^[0-9A-Za-z._-]+$", var.runnerd_install_revision))
    )
    error_message = "runnerd_install_revision 必须为空或仅包含字母、数字、点、下划线和连字符。"
  }
}

variable "config_content" {
  description = "完整的 runnerd 配置内容。"
  type        = string
  sensitive   = true

  validation {
    condition     = trimspace(var.config_content) != ""
    error_message = "config_content 不能为空。"
  }
}

variable "github_app_private_key_base64" {
  description = "Base64 编码的 GitHub App PEM 私钥；允许包含 CR/LF 换行。"
  type        = string
  sensitive   = true

  validation {
    condition = can(regex(
      "PRIVATE KEY",
      base64decode(replace(replace(var.github_app_private_key_base64, "\r", ""), "\n", "")),
    ))
    error_message = "github_app_private_key_base64 必须可解码且内容必须包含 PRIVATE KEY。"
  }
}

variable "bootstrap_admin_github_user_id" {
  description = "首次引导管理员使用的正整数 GitHub user ID。"
  type        = number

  validation {
    condition = (
      var.bootstrap_admin_github_user_id > 0 &&
      floor(var.bootstrap_admin_github_user_id) == var.bootstrap_admin_github_user_id
    )
    error_message = "bootstrap_admin_github_user_id 必须是正整数。"
  }
}
