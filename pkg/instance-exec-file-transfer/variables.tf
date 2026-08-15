variable "instance_id" {
  description = "目标 LAS 实例 ID。"
  type        = string

  validation {
    condition     = trimspace(var.instance_id) != ""
    error_message = "instance_id 不能为空。"
  }
}

variable "user" {
  description = "远程执行用户。"
  type        = string
  default     = "root"

  validation {
    condition     = var.user == "root"
    error_message = "公共传输模块只能以 root 用户执行。"
  }
}

variable "port" {
  description = "远程 SSH 端口。"
  type        = string
  default     = "22"

  validation {
    condition     = can(tonumber(var.port)) && tonumber(var.port) >= 1 && tonumber(var.port) <= 65535 && floor(tonumber(var.port)) == tonumber(var.port)
    error_message = "port 必须是 1 到 65535 之间的整数。"
  }
}

variable "private_key" {
  description = "远程 SSH 私钥。"
  type        = string
  sensitive   = true

  validation {
    condition     = trimspace(var.private_key) != ""
    error_message = "private_key 不能为空。"
  }
}

variable "content_base64" {
  description = "待传输内容的无换行 ASCII Base64 编码。"
  type        = string

  validation {
    condition = (
      length(var.content_base64) > 0 &&
      can(regex("^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$", var.content_base64))
    )
    error_message = "content_base64 必须是无换行、长度格式正确的非空 ASCII Base64。"
  }
}

variable "content_sha256" {
  description = "解码后内容的 SHA-256（64 位小写十六进制）。"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.content_sha256))
    error_message = "content_sha256 必须是 64 位小写十六进制 SHA-256。"
  }
}

variable "destination_path" {
  description = "远端绝对目标文件路径。"
  type        = string

  validation {
    condition     = startswith(var.destination_path, "/")
    error_message = "destination_path 必须是绝对路径。"
  }
}

variable "chunk_size" {
  description = "每个 Base64 分片的最大 ASCII 字符数。"
  type        = number
  default     = 4096

  validation {
    condition     = var.chunk_size >= 1 && var.chunk_size <= 4096 && floor(var.chunk_size) == var.chunk_size
    error_message = "chunk_size 必须是 1 到 4096 之间的整数，以保证渲染后命令不超过 8192 字符。"
  }
}
