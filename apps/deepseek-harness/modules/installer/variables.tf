variable "dsh_version" {
  description = "要安装的 @deepseek-ai/dsh 版本。"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?(\\+[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$", var.dsh_version))
    error_message = "dsh_version 必须是完整的 semver（可包含 prerelease 或 build metadata）。"
  }
}

variable "node_version" {
  description = "要安装的 Node.js 版本。"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?(\\+[0-9A-Za-z]+([.-][0-9A-Za-z]+)*)?$", var.node_version))
    error_message = "node_version 必须是完整的 semver（可包含 prerelease 或 build metadata）。"
  }
}

variable "dsh_port" {
  description = "DeepSeek Harness 回环监听端口。"
  type        = number

  validation {
    condition     = var.dsh_port >= 1 && var.dsh_port <= 65535 && floor(var.dsh_port) == var.dsh_port
    error_message = "dsh_port 必须是 1 到 65535 之间的整数。"
  }
}

variable "nginx_proxy_port" {
  description = "Nginx 对外监听端口。"
  type        = number

  validation {
    condition     = var.nginx_proxy_port >= 1 && var.nginx_proxy_port <= 65535 && floor(var.nginx_proxy_port) == var.nginx_proxy_port
    error_message = "nginx_proxy_port 必须是 1 到 65535 之间的整数。"
  }
}

variable "preview_count" {
  description = "启用的 Preview 槽位数量（0 到 4）。"
  type        = number

  validation {
    condition     = var.preview_count >= 0 && var.preview_count <= 4 && floor(var.preview_count) == var.preview_count
    error_message = "preview_count 必须是 0 到 4 之间的整数。"
  }
}

variable "preview_ports" {
  description = "Preview 应用回环端口列表。"
  type        = list(number)

  validation {
    condition     = length(var.preview_ports) == 4 && alltrue([for port in var.preview_ports : port >= 1 && port <= 65535 && floor(port) == port])
    error_message = "preview_ports 必须包含 4 个有效整数端口。"
  }
}

variable "code_server_version" {
  description = "固定的 code-server 版本。"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.code_server_version))
    error_message = "code_server_version 必须是三段数字版本。"
  }
}

variable "code_server_port" {
  description = "code-server 回环监听端口。"
  type        = number

  validation {
    condition     = var.code_server_port >= 1 && var.code_server_port <= 65535 && floor(var.code_server_port) == var.code_server_port
    error_message = "code_server_port 必须是 1 到 65535 之间的整数。"
  }
}

variable "code_server_proxy_port" {
  description = "Nginx code-server 对外监听端口。"
  type        = number

  validation {
    condition     = var.code_server_proxy_port >= 1 && var.code_server_proxy_port <= 65535 && floor(var.code_server_proxy_port) == var.code_server_proxy_port
    error_message = "code_server_proxy_port 必须是 1 到 65535 之间的整数。"
  }
}

variable "public_authority" {
  description = "DeepSeek Harness 信任的外部 Host。"
  type        = string

  validation {
    condition = (
      can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*(:[0-9]{1,5})?$", var.public_authority)) &&
      length(element(split(":", var.public_authority), 0)) <= 253 &&
      (length(split(":", var.public_authority)) == 1 ? true : try(
        tonumber(element(split(":", var.public_authority), 1)) >= 1 &&
        tonumber(element(split(":", var.public_authority), 1)) <= 65535,
        false,
      ))
    )
    error_message = "public_authority 必须是主机部分不超过 253 字节的有效主机名或 host:port authority。"
  }
}

variable "preview_public_authorities" {
  description = "Preview 的外部 Host 列表。"
  type        = list(string)

  validation {
    condition     = length(coalesce(var.preview_public_authorities, [])) == var.preview_count
    error_message = "preview_public_authorities 的长度必须等于 preview_count。"
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

variable "web_username" {
  description = "Nginx Basic Auth 用户名。"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,64}$", var.web_username))
    error_message = "web_username 只能包含字母、数字、点、下划线和连字符，长度为 1 到 64。"
  }
}

variable "web_password" {
  description = "Nginx Basic Auth 密码。"
  type        = string
  sensitive   = true
}

variable "code_server_password" {
  description = "code-server 自带密码。"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9._~-]{16,128}$", var.code_server_password))
    error_message = "code_server_password 必须为 16 到 128 位字母、数字或 -._~。"
  }
}
