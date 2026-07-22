variable "runnerd_version" {
  type        = string
  description = "要安装的 runnerd 版本标签，不允许使用 latest"

  validation {
    condition = (
      can(regex("^[0-9A-Za-z._-]+$", var.runnerd_version)) &&
      lower(var.runnerd_version) != "latest"
    )
    error_message = "runnerd_version 必须是非空的安全版本标签，仅可包含字母、数字、点、下划线和连字符，且不能为 latest。"
  }
}

variable "runnerd_port" {
  type        = number
  description = "runnerd 监听及 HTTPProxy 转发的实例内部端口"
  default     = 25500

  validation {
    condition = (
      var.runnerd_port >= 1 &&
      var.runnerd_port <= 65535 &&
      floor(var.runnerd_port) == var.runnerd_port
    )
    error_message = "runnerd_port 必须是 1 到 65535 之间的整数。"
  }
}

variable "github_app_id" {
  type        = number
  description = "GitHub App 的数字 ID"

  validation {
    condition = (
      var.github_app_id > 0 &&
      floor(var.github_app_id) == var.github_app_id
    )
    error_message = "github_app_id 必须是大于 0 的整数。"
  }
}

variable "github_app_slug" {
  type        = string
  description = "GitHub App 的 slug"

  validation {
    condition     = length(trimspace(var.github_app_slug)) > 0
    error_message = "github_app_slug 不能为空。"
  }
}

variable "github_oauth_client_id" {
  type        = string
  description = "GitHub OAuth 客户端 ID"

  validation {
    condition     = length(trimspace(var.github_oauth_client_id)) > 0
    error_message = "github_oauth_client_id 不能为空。"
  }
}

variable "github_oauth_client_secret" {
  type        = string
  description = "GitHub OAuth 客户端密钥"
  sensitive   = true

  validation {
    condition     = length(trimspace(var.github_oauth_client_secret)) > 0
    error_message = "github_oauth_client_secret 不能为空。"
  }
}

variable "github_app_private_key_base64" {
  type        = string
  description = "经过 Base64 编码的 GitHub App PEM 私钥"
  sensitive   = true

  validation {
    condition     = can(regex("PRIVATE KEY", base64decode(var.github_app_private_key_base64)))
    error_message = "github_app_private_key_base64 必须是有效的 Base64，且解码内容必须包含 PRIVATE KEY。"
  }
}

variable "bootstrap_admin_github_user_id" {
  type        = number
  description = "初始管理员的 GitHub 数字用户 ID"

  validation {
    condition = (
      var.bootstrap_admin_github_user_id > 0 &&
      floor(var.bootstrap_admin_github_user_id) == var.bootstrap_admin_github_user_id
    )
    error_message = "bootstrap_admin_github_user_id 必须是大于 0 的整数。"
  }
}

variable "instance_type" {
  type        = string
  description = "ECS 实例规格"
  default     = "ecs.t1s.c1m2"

  validation {
    condition     = can(regex("^ecs\\.[0-9A-Za-z]+(\\.[0-9A-Za-z]+)+$", var.instance_type))
    error_message = "instance_type 必须是以 ecs. 开头的有效 ECS 实例规格。"
  }
}

variable "system_disk_size" {
  type        = number
  description = "系统盘大小（GiB），范围为 20 到 500 且必须是 10 的倍数"
  default     = 20

  validation {
    condition = (
      var.system_disk_size >= 20 &&
      var.system_disk_size <= 500 &&
      floor(var.system_disk_size) == var.system_disk_size &&
      var.system_disk_size % 10 == 0
    )
    error_message = "system_disk_size 必须是 20 到 500 之间且为 10 的倍数的整数。"
  }
}

variable "internet_max_bandwidth" {
  type        = number
  description = "PeakBandwidth 计费模式下的公网最大带宽（Mbps）"
  default     = 100

  validation {
    condition     = contains([50, 100, 200], var.internet_max_bandwidth)
    error_message = "internet_max_bandwidth 在 PeakBandwidth 模式下只能为 50、100 或 200 Mbps。"
  }
}

variable "enable_ssh_port_forward" {
  type        = bool
  description = "是否通过七牛 PortForward 暴露实例 SSH 22 端口"
  default     = false
}
