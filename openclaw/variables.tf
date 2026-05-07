# ============================================================================
# OpenClaw Terraform Module - Variables
# ============================================================================
# 本模块用于在七牛云 LAS 上部署 OpenClaw 个人 AI 助手
# 基于七牛云 LAS 社区镜像 OpenClaw，开箱即用
# ============================================================================

# ============================================================================
# 实例规格配置
# ============================================================================

variable "instance_type" {
  type        = string
  description = "ECS 实例规格"
  default     = "ecs.t1.c4m8"

  validation {
    condition = var.instance_type != "" && contains([
      "ecs.t1.c1m2",
      "ecs.t1.c2m4",
      "ecs.t1.c4m8",
      "ecs.t1.c8m16",
      "ecs.t1.c12m24",
      "ecs.t1.c16m32",
      "ecs.t1.c24m48",
      "ecs.t1.c32m64",
      "ecs.c1.c1m2",
      "ecs.c1.c2m4",
      "ecs.c1.c4m8",
      "ecs.c1.c8m16",
      "ecs.c1.c12m24",
      "ecs.c1.c16m32",
      "ecs.c1.c24m48",
      "ecs.c1.c32m64",
      "ecs.g1.c16m120",
      "ecs.g1.c32m240",
    ], var.instance_type)
    error_message = "instance_type must be one of the allowed ECS instance types."
  }
}

variable "system_disk_size" {
  type        = number
  description = "系统盘大小（GiB）"
  default     = 50

  validation {
    condition     = var.system_disk_size >= 10 && var.system_disk_size <= 500
    error_message = "system_disk_size must be between 10 and 500 GiB."
  }
}

variable "system_disk_type" {
  type        = string
  description = "系统盘类型"
  default     = "local.ssd"

  validation {
    condition     = contains(["local.ssd", "cloud.ssd"], var.system_disk_type)
    error_message = "system_disk_type must be local.ssd or cloud.ssd."
  }
}

variable "internet_max_bandwidth" {
  type        = number
  description = "公网最大带宽（Mbps），取值范围 10-200"
  default     = 100

  validation {
    condition     = var.internet_max_bandwidth >= 10 && var.internet_max_bandwidth <= 200
    error_message = "internet_max_bandwidth must be between 10 and 200 Mbps."
  }
}

variable "internet_charge_type" {
  type        = string
  description = "网络计费类型"
  default     = "PeakBandwidth"

  validation {
    condition     = contains(["Bandwidth", "PeakBandwidth", "Traffic"], var.internet_charge_type)
    error_message = "internet_charge_type must be Bandwidth, PeakBandwidth or Traffic."
  }
}

variable "internet_public_ip_type" {
  type        = string
  description = "公网 IP 类型，Dedicated 为独立公网 IP，Shared 为共享公网 IP"
  default     = "Dedicated"

  validation {
    condition     = contains(["Dedicated", "Shared"], var.internet_public_ip_type)
    error_message = "internet_public_ip_type must be Dedicated or Shared."
  }
}

variable "root_password" {
  type        = string
  sensitive   = true
  description = "实例 root 用户密码（要求：不少于 8 位，必须同时包含字母、数字和特殊符号）"

  validation {
    condition = (
      length(var.root_password) >= 8 &&
      # 必须包含字母（大写或小写）
      can(regex("[A-Za-z]", var.root_password)) &&
      # 必须包含数字
      can(regex("[0-9]", var.root_password)) &&
      # 必须包含特殊符号
      can(regex("[^A-Za-z0-9]", var.root_password))
    )
    error_message = "密码不符合要求：必须不少于 8 位，且同时包含字母、数字和特殊符号。"
  }
}

# ============================================================================
# 计费配置
# ============================================================================

variable "cost_charge_type" {
  type        = string
  description = "实例计费类型，PostPaid 为后付费（按量计费），PrePaid 为预付费（包年包月）"
  default     = "PostPaid"

  validation {
    condition     = contains(["PostPaid", "PrePaid"], var.cost_charge_type)
    error_message = "cost_charge_type must be PostPaid or PrePaid."
  }
}

variable "cost_period" {
  type        = number
  description = "预付费购买时长，仅在 cost_charge_type 为 PrePaid 时生效；默认值为 1"
  default     = 1

  validation {
    condition     = var.cost_period >= 1 && var.cost_period <= 36
    error_message = "cost_period must be between 1 and 36."
  }
}

variable "cost_period_unit" {
  type        = string
  description = "预付费购买时长单位，仅在 cost_charge_type 为 PrePaid 时生效，支持 Month、Year"
  default     = "Month"

  validation {
    condition     = contains(["Month", "Year"], var.cost_period_unit)
    error_message = "cost_period_unit must be Month or Year."
  }
}

variable "cost_discount_activity_id" {
  type        = string
  description = "预付费促销活动 ID，仅在 cost_charge_type 为 PrePaid 时生效"
  default     = ""
}

# ============================================================================
# 端口转发配置
# ============================================================================

variable "port_forwards" {
  type = list(object({
    internal_port = number
  }))
  description = "端口转发规则列表，仅当 internet_public_ip_type 为 Shared 且 internet_max_bandwidth 大于 0 时可配置"
  default     = []

  validation {
    condition = alltrue([
      for p in var.port_forwards : p.internal_port >= 1 && p.internal_port <= 65535
    ]) && length(var.port_forwards) == length(distinct([for p in var.port_forwards : p.internal_port]))
    error_message = "internal_port 必须在 1 到 65535 之间，且每个端口号必须唯一。"
  }
}

# ============================================================================
# 七牛 MaaS 配置
# ============================================================================

variable "qiniu_maas_api_key" {
  type        = string
  sensitive   = true
  description = "七牛 MaaS API 密钥（从 https://portal.qiniu.com/ai-inference/api-key 获取）"
}

variable "wx_secret" {
  type        = string
  sensitive   = true
  description = "可选的微信绑定串，格式为 botid|token|savedAt|baseUrl|userId；为空时跳过微信初始化"
  default     = ""
}

variable "qq_secret" {
  type        = string
  sensitive   = true
  description = "可选的 QQ 机器人凭证，格式为 AppID:AppSecret；为空时跳过 QQ channel 初始化"
  default     = ""

  validation {
    condition     = var.qq_secret == "" || can(regex("^[^:]+:[^:]+$", var.qq_secret))
    error_message = "qq_secret must be empty or in AppID:AppSecret format."
  }
}

# ============================================================================
# AI 模型配置
# ============================================================================

variable "default_model" {
  type        = string
  description = "使用的 AI 模型（如 minimax/minimax-m2.5、deepseek/deepseek-chat、qwen/qwen-max 等）"
  default     = "minimax/minimax-m2.5"
}

# ============================================================================
# Gateway 配置
# ============================================================================

variable "gateway_port" {
  type        = number
  description = "Gateway 端口"
  default     = 18789

  validation {
    condition     = var.gateway_port >= 1 && var.gateway_port <= 65535
    error_message = "gateway_port 必须在 1 到 65535 之间。"
  }
}

variable "expose_dashboard" {
  type        = bool
  description = "是否将 Dashboard 暴露到公网（true: 监听 0.0.0.0 并设置 allowedOrigins:[*]，false: 仅监听 127.0.0.1 需 SSH 隧道访问）"
  default     = false
}

variable "disable_device_auth" {
  type        = bool
  description = "是否禁用设备认证（设置 dangerouslyDisableDeviceAuth:true）"
  default     = false
}

# ============================================================================
# 镜像与命名
# ============================================================================

variable "instance_name_prefix" {
  type        = string
  description = "实例名称前缀"
  default     = "openclaw"
}

variable "image_name_prefix" {
  type        = string
  description = "OpenClaw 社区镜像名称前缀，用于筛选匹配的镜像"
  default     = "OpenClaw-v2026.3.8"
}
