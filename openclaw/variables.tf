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
# 七牛 MaaS 配置
# ============================================================================

variable "qiniu_maas_api_key" {
  type        = string
  sensitive   = true
  description = "七牛 MaaS API 密钥（从 https://portal.qiniu.com/ai-inference/api-key 获取）"
}

# ============================================================================
# AI 模型配置
# ============================================================================

variable "default_model" {
  type        = string
  description = "使用的 AI 模型（如 minimax/minimax-m2.1、deepseek/deepseek-chat、qwen/qwen-max 等）"
  default     = "minimax/minimax-m2.1"
}

# ============================================================================
# 工作空间配置
# ============================================================================

variable "gateway_port" {
  type        = number
  description = "Gateway 端口"
  default     = 18789
}

variable "instance_name_prefix" {
  type        = string
  description = "实例名称前缀"
  default     = "openclaw"
}
