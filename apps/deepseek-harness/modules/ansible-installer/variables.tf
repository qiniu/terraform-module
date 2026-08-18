variable "dsh_web_proxy_port" {
  description = "DeepSeek Harness Web 的 HTTPProxy/Nginx 代理端口。"
  type        = number

  validation {
    condition     = var.dsh_web_proxy_port >= 1 && var.dsh_web_proxy_port <= 65535 && floor(var.dsh_web_proxy_port) == var.dsh_web_proxy_port
    error_message = "dsh_web_proxy_port 必须是 1 到 65535 之间的整数。"
  }
}

variable "preview_ports" {
  description = "Preview 应用回环端口列表。"
  type        = list(number)

  validation {
    condition     = length(var.preview_ports) <= 4 && alltrue([for port in var.preview_ports : port >= 1 && port <= 65535 && floor(port) == port])
    error_message = "preview_ports 必须包含最多 4 个有效整数端口。"
  }
}

variable "code_server_proxy_port" {
  description = "code-server 的 HTTPProxy/Nginx 代理端口。"
  type        = number

  validation {
    condition     = var.code_server_proxy_port >= 1 && var.code_server_proxy_port <= 65535 && floor(var.code_server_proxy_port) == var.code_server_proxy_port
    error_message = "code_server_proxy_port 必须是 1 到 65535 之间的整数。"
  }
}

variable "las_instance_id" {
  description = "部署 DeepSeek Harness 的 LAS 实例 ID。"
  type        = string

  validation {
    condition     = trimspace(var.las_instance_id) != ""
    error_message = "las_instance_id 不能为空。"
  }
}

variable "las_region_id" {
  description = "LAS 实例所在区域 ID。"
  type        = string

  validation {
    condition     = trimspace(var.las_region_id) != ""
    error_message = "las_region_id 不能为空。"
  }
}

variable "las_region_name" {
  description = "LAS 实例所在区域名称。"
  type        = string

  validation {
    condition     = trimspace(var.las_region_name) != ""
    error_message = "las_region_name 不能为空。"
  }
}

variable "dsh_web_public_authority" {
  description = "DeepSeek Harness 信任的外部 Host。"
  type        = string

  validation {
    condition = (
      can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*(:[0-9]{1,5})?$", var.dsh_web_public_authority)) &&
      length(element(split(":", var.dsh_web_public_authority), 0)) <= 253
    )
    error_message = "dsh_web_public_authority 必须是主机部分不超过 253 字节的有效 authority。"
  }
}

variable "preview_public_authorities" {
  description = "Preview 的外部 Host 列表。"
  type        = list(string)

  validation {
    condition     = length(var.preview_public_authorities) == length(var.preview_ports)
    error_message = "preview_public_authorities 的长度必须等于 preview_ports。"
  }
}

variable "code_server_public_authority" {
  description = "code-server 的外部 Host。"
  type        = string

  validation {
    condition = (
      can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*(:[0-9]{1,5})?$", var.code_server_public_authority)) &&
      length(element(split(":", var.code_server_public_authority), 0)) <= 253
    )
    error_message = "code_server_public_authority 必须是主机部分不超过 253 字节的有效 authority。"
  }
}

variable "dsh_web_username" {
  description = "Nginx Basic Auth 用户名。"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,64}$", var.dsh_web_username))
    error_message = "dsh_web_username 只能包含字母、数字、点、下划线和连字符，长度为 1 到 64。"
  }
}

variable "dsh_web_password" {
  description = "Nginx Basic Auth 密码。"
  type        = string
  sensitive   = true
}

variable "code_server_password" {
  description = "code-server 自带密码。"
  type        = string
  sensitive   = true

  validation {
    condition = (
      length(var.code_server_password) >= 8 &&
      length(var.code_server_password) <= 30 &&
      can(regex("[A-Za-z]", var.code_server_password)) &&
      can(regex("[0-9]", var.code_server_password)) &&
      can(regex("[^A-Za-z0-9]", var.code_server_password))
    )
    error_message = "code_server_password 必须为 8 到 30 位且同时包含字母、数字和特殊符号的密码。"
  }
}
