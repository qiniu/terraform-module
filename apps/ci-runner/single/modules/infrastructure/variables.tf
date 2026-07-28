variable "runnerd_port" {
  type        = number
  description = "runnerd 监听及 HTTPProxy 转发的实例内部端口"
}

variable "instance_type" {
  type        = string
  description = "ECS 实例规格"
}

variable "system_disk_size" {
  type        = number
  description = "系统盘大小（GiB）"
}

variable "internet_max_bandwidth" {
  type        = number
  description = "PeakBandwidth 计费模式下的公网最大带宽（Mbps）"
}

variable "enable_ssh_port_forward" {
  type        = bool
  description = "是否通过七牛 PortForward 暴露实例 SSH 22 端口"
}

variable "cost_charge_type" {
  type        = string
  description = "实例计费类型（PostPaid / PrePaid）"
}

variable "cost_period" {
  type        = number
  description = "预付费购买时长"
  default     = null
}

variable "cost_period_unit" {
  type        = string
  description = "预付费购买时长单位"
  default     = "Month"
}



variable "instance_password" {
  type        = string
  description = "ECS 实例 SSH 登录密码"
  default     = null
  sensitive   = true
}
