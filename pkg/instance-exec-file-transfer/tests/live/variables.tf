variable "instance_type" {
  description = "Live 测试用临时实例规格。"
  type        = string
  default     = "ecs.t1s.c1m2"
}

variable "system_disk_size" {
  description = "Live 测试用临时实例系统盘大小（GiB）。"
  type        = number
  default     = 20
}

variable "internet_max_bandwidth" {
  description = "Live 测试用临时实例公网带宽上限（Mbps）。与 ci-runner 默认一致（100），避免实例创建后带宽修改触发额外计费校验。"
  type        = number
  default     = 100
}

variable "instance_password" {
  description = "Live 测试用临时实例 root 密码（同时使用部署 key pair）。"
  type        = string
  sensitive   = true
}

variable "user" {
  description = "测试模块发布文件所使用的 SSH 用户。"
  type        = string
  default     = "root"
}