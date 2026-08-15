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

variable "shell" {
  description = "远程命令解释器。"
  type        = string
  default     = "bash"

  validation {
    condition     = var.shell == "bash" || var.shell == "/bin/bash"
    error_message = "shell 只能是 bash 或 /bin/bash。"
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
  description = "受限的 /opt 下绝对目标文件路径。"
  type        = string

  validation {
    condition = (
      can(regex("^/opt/[A-Za-z0-9][A-Za-z0-9._/-]*$", var.destination_path)) &&
      !strcontains(var.destination_path, "//") &&
      !strcontains(var.destination_path, "/./") &&
      !strcontains(var.destination_path, "/../") &&
      !endswith(var.destination_path, "/.") &&
      !endswith(var.destination_path, "/..")
    )
    error_message = "destination_path 必须是不含控制字符、重复分隔符或 traversal 的受限 /opt 绝对文件路径。"
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
