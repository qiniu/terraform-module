variable "instance_type" {
  type        = string
  description = "DeepSeek Harness ECS 实例规格。"
  default     = "ecs.t1s.c2m4"

  validation {
    condition     = can(regex("^ecs\\.[0-9A-Za-z]+(\\.[0-9A-Za-z]+)+$", var.instance_type))
    error_message = "instance_type 必须是以 ecs. 开头的有效 ECS 实例规格。"
  }
}

variable "preview_count" {
  type        = number
  description = "启用的 Preview 槽位数量（0 到 4）。"
  default     = 1

  validation {
    condition     = var.preview_count >= 0 && var.preview_count <= 4 && floor(var.preview_count) == var.preview_count
    error_message = "preview_count 必须是 0 到 4 之间的整数。"
  }
}

variable "enable_code_server" {
  type        = bool
  description = "是否安装并公开 code-server。"
  default     = true
}

variable "enable_filebrowser" {
  type        = bool
  description = "是否安装并公开 FileBrowser Quantum。"
  default     = true
}

variable "system_disk_size" {
  type        = number
  description = "ECS 系统盘大小（GiB）。"
  default     = 40

  validation {
    condition     = var.system_disk_size >= 20 && var.system_disk_size <= 500 && floor(var.system_disk_size) == var.system_disk_size && var.system_disk_size % 10 == 0
    error_message = "system_disk_size 必须是 20 到 500 之间且为 10 的倍数的整数。"
  }
}

variable "internet_max_bandwidth" {
  type        = number
  description = "PeakBandwidth 模式下的公网最大带宽（Mbps）。"
  default     = 100

  validation {
    condition     = contains([50, 100, 200], var.internet_max_bandwidth)
    error_message = "internet_max_bandwidth 只能为 50、100 或 200 Mbps。"
  }
}

variable "enable_ssh_port_forward" {
  type        = bool
  description = "是否通过 PortForward 暴露 SSH 22 端口。"
  default     = false
}

variable "cost_charge_type" {
  type        = string
  description = "实例计费类型。"
  default     = "PostPaid"

  validation {
    condition     = contains(["PostPaid", "PrePaid"], var.cost_charge_type)
    error_message = "cost_charge_type 必须为 PostPaid 或 PrePaid。"
  }
}

variable "cost_period" {
  type        = number
  description = "预付费购买时长。"
  default     = null

  validation {
    condition     = var.cost_charge_type != "PostPaid" || var.cost_period == null
    error_message = "PostPaid 模式下 cost_period 必须为 null。"
  }
  validation {
    condition     = var.cost_charge_type != "PrePaid" || var.cost_period != null
    error_message = "PrePaid 模式下必须设置 cost_period。"
  }
  validation {
    condition = var.cost_period == null || (
      var.cost_period >= 1 &&
      floor(var.cost_period) == var.cost_period &&
      (
        var.cost_period_unit == "Month" ? var.cost_period <= 36 :
        var.cost_period_unit == "Year" ? var.cost_period <= 3 : true
      )
    )
    error_message = "cost_period 必须是整数；Month 单位取值 1 到 36，Year 单位取值 1 到 3。"
  }
}

variable "cost_period_unit" {
  type        = string
  description = "预付费购买时长单位。"
  default     = "Month"

  validation {
    condition     = contains(["Month", "Year"], var.cost_period_unit)
    error_message = "cost_period_unit 必须为 Month 或 Year。"
  }
}

variable "instance_password" {
  type        = string
  description = "ECS root 登录密码。"
  nullable    = false
  sensitive   = true

  validation {
    condition = (
      length(var.instance_password) >= 8 &&
      length(var.instance_password) <= 30 &&
      can(regex("[A-Za-z]", var.instance_password)) &&
      can(regex("[0-9]", var.instance_password)) &&
      can(regex("[^A-Za-z0-9]", var.instance_password))
    )
    error_message = "密码必须为 8 到 30 位，且同时包含字母、数字和特殊符号。"
  }
}

variable "dsh_web_password" {
  type        = string
  description = "DeepSeek Harness Web 的登录密码；启用 code-server 时也用作其登录密码。空字符串时自动生成。"
  default     = ""
  nullable    = false
  sensitive   = true

  validation {
    condition = var.dsh_web_password == "" || (
      length(var.dsh_web_password) >= 8 &&
      length(var.dsh_web_password) <= 30 &&
      can(regex("[A-Za-z]", var.dsh_web_password)) &&
      can(regex("[0-9]", var.dsh_web_password)) &&
      can(regex("[^A-Za-z0-9]", var.dsh_web_password))
    )
    error_message = "dsh_web_password 必须为空字符串，或为 8 到 30 位且同时包含字母、数字和特殊符号的密码。"
  }
}
