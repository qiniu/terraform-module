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
  default     = "ecs.t1s.c4m8"

  validation {
    # 当 cost_discount_activity_id 没有填写时，instance_type 必须是给定的枚举规格
    condition = (
      (var.cost_discount_activity_id != null && var.cost_discount_activity_id != "") ||
      contains([
        "ecs.t1s.c1m2",
        "ecs.t1s.c2m2",
        "ecs.t1s.c2m4",
        "ecs.t1s.c4m8",
        "ecs.t1s.c8m16",
        "ecs.t1s.c12m24",
        "ecs.t1s.c16m32",
      ], var.instance_type)
    )
    error_message = "instance_type must be one of the allowed ECS instance types."
  }
}

variable "system_disk_size" {
  type        = number
  description = "系统盘大小（GiB）"
  default     = 50

  validation {
    # 系统盘大小必须在 20 到 500 GiB 之间
    condition     = var.system_disk_size >= 20 && var.system_disk_size <= 500
    error_message = "system_disk_size must be between 20 and 500 GiB."
  }

  validation {
    # 系统盘大小必须是 10 的倍数
    condition     = var.system_disk_size % 10 == 0
    error_message = "system_disk_size must be a multiple of 10."
  }
}

variable "system_disk_type" {
  type        = string
  description = "系统盘类型"
  default     = "cloud.ssd"

  validation {
    # 系统盘类型必须是 local.ssd 或 cloud.ssd
    condition     = contains(["local.ssd", "cloud.ssd"], var.system_disk_type)
    error_message = "system_disk_type must be local.ssd or cloud.ssd."
  }
}

variable "internet_max_bandwidth" {
  type        = number
  description = "公网最大带宽（Mbps），取值范围 1-300"
  default     = 100

  validation {
    # 公网最大带宽必须在 1 到 300 Mbps 之间
    condition     = var.internet_max_bandwidth >= 1 && var.internet_max_bandwidth <= 300
    error_message = "internet_max_bandwidth must be between 1 and 300 Mbps."
  }

  validation {
    # 若 internet_charge_type 为 PeakBandwidth，则 internet_max_bandwidth 只能为 50、100 或 200
    condition = (
      var.internet_charge_type != "PeakBandwidth" ||
      contains([50, 100, 200], var.internet_max_bandwidth)
    )
    error_message = "当 internet_charge_type 为 PeakBandwidth 时，internet_max_bandwidth 只能为 50、100 或 200。"
  }
}

variable "internet_charge_type" {
  type        = string
  description = "网络计费类型"
  default     = "PeakBandwidth"

  validation {
    # 网络计费类型必须是 Bandwidth、PeakBandwidth 或 Traffic
    condition     = contains(["Bandwidth", "PeakBandwidth", "Traffic"], var.internet_charge_type)
    error_message = "internet_charge_type must be Bandwidth, PeakBandwidth or Traffic."
  }
}

variable "root_password" {
  type        = string
  sensitive   = true
  description = "实例 root 用户密码（要求：不少于 8 位，必须同时包含字母、数字和特殊符号）。openclaw 用户密码也使用该密码。"

  validation {
    condition = (
      # 必须不少于 8 位
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
    # 计费类型必须是 PostPaid 或 PrePaid
    condition     = contains(["PostPaid", "PrePaid"], var.cost_charge_type)
    error_message = "cost_charge_type must be PostPaid or PrePaid."
  }
}

variable "cost_period" {
  type        = number
  description = "预付费购买时长，仅在 cost_charge_type 为 PrePaid 时生效"
  default     = null

  validation {
    # PostPaid 模式下 cost_period 必须为 null（不设置）
    condition     = var.cost_charge_type != "PostPaid" || var.cost_period == null
    error_message = "PostPaid 模式下 cost_period 必须为 null（不设置）。"
  }

  validation {
    # PrePaid 模式下必须设置 cost_period
    condition     = var.cost_charge_type != "PrePaid" || var.cost_period != null
    error_message = "PrePaid 模式下必须设置 cost_period。"
  }

  validation {
    # PrePaid 模式下 cost_period 的取值范围根据 cost_period_unit 不同而不同
    condition = (
      var.cost_period == null ||
      (
        var.cost_period_unit == "Year" ?
        (var.cost_period >= 1 && var.cost_period <= 3) : # Year 单位时，取值范围 1-3
        (var.cost_period >= 1 && var.cost_period <= 36)  # Month 单位时，取值范围 1-36
      )
    )
    error_message = "cost_period must be between 1 and 36 for Month, or between 1 and 3 for Year."
  }
}

variable "cost_period_unit" {
  type        = string
  description = "预付费购买时长单位，仅在 cost_charge_type 为 PrePaid 时生效，支持 Month、Year"
  default     = null

  validation {
    condition     = var.cost_charge_type != "PostPaid" || var.cost_period_unit == null
    error_message = "PostPaid 模式下 cost_period_unit 必须为 null（不设置）。"
  }

  validation {
    condition     = var.cost_charge_type != "PrePaid" || var.cost_period_unit != null
    error_message = "PrePaid 模式下必须设置 cost_period_unit。"
  }

  validation {
    condition     = var.cost_period_unit == null || contains(["Month", "Year"], var.cost_period_unit)
    error_message = "cost_period_unit must be Month or Year."
  }
}

variable "cost_discount_activity_id" {
  type        = string
  description = "预付费促销活动 ID，仅在 cost_charge_type 为 PrePaid 时生效"
  default     = null

  validation {
    # 只有预付费支持设置 cost_discount_activity_id
    condition     = var.cost_charge_type != "PostPaid" || var.cost_discount_activity_id == null
    error_message = "PostPaid 模式下 cost_discount_activity_id 必须为 null（不设置）。"
  }
}

# ============================================================================
# 七牛 MaaS 配置
# ============================================================================

variable "qiniu_maas_api_key" {
  type        = string
  sensitive   = true
  description = "七牛 MaaS API 密钥（从 https://portal.qiniu.com/ai-inference/api-key 获取）"

  validation {
    condition     = length(var.qiniu_maas_api_key) >= 1
    error_message = "qiniu_maas_api_key is required and cannot be empty."
  }
}

# ============================================================================
# QQ 机器人配置
# ============================================================================

variable "qq_secret" {
  type        = string
  sensitive   = true
  default     = ""
  description = "可选的 QQ 机器人凭证，格式为 AppID:AppSecret；为空时跳过 QQ channel 初始化"

  validation {
    condition     = var.qq_secret == "" || can(regex("^[^:]+:[^:]+$", var.qq_secret))
    error_message = "qq_secret must be empty or in AppID:AppSecret format."
  }
}

# ============================================================================
# Gateway 配置
# ============================================================================
variable "expose_dashboard" {
  type        = bool
  description = "是否将 Dashboard 暴露到公网（true: 监听 0.0.0.0 并设置 allowedOrigins:[*]，false: 仅监听 127.0.0.1 需 SSH 隧道访问）"
  default     = false
}

