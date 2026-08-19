variable "image_id" {
  type    = string
  default = null

  validation {
    condition     = var.image_id == null || trimspace(var.image_id) != ""
    error_message = "image_id 不能是空字符串。"
  }
}

variable "preview_count" {
  type = number

  validation {
    condition     = var.preview_count >= 0 && var.preview_count <= 4 && floor(var.preview_count) == var.preview_count
    error_message = "preview_count 必须是 0 到 4 之间的整数。"
  }
}

variable "enable_code_server" {
  type = bool
}

variable "instance_type" {
  type = string
}

variable "system_disk_size" {
  type = number
}

variable "internet_max_bandwidth" {
  type = number
}

variable "enable_ssh_port_forward" {
  type = bool
}

variable "cost_charge_type" {
  type = string
}

variable "cost_period" {
  type    = number
  default = null
}

variable "cost_period_unit" {
  type    = string
  default = "Month"
}

variable "instance_password" {
  type      = string
  nullable  = false
  sensitive = true
}
