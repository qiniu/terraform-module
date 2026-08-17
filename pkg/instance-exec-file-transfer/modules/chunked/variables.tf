variable "instance_id" {
  description = "目标实例 ID，用于 qiniu_compute_instance_exec 的 InstanceConnect 连接。"
  type        = string
}

variable "user" {
  description = "SSH 用户名，默认 root。"
  type        = string
  default     = "root"
}

variable "port" {
  description = "SSH 端口。"
  type        = string
  default     = "22"
}

variable "private_key" {
  description = "SSH 私钥内容，与 password 二选一。"
  type        = string
  sensitive   = true
  default     = null
}

variable "password" {
  description = "SSH 密码，与 private_key 二选一。"
  type        = string
  sensitive   = true
  default     = null
}

variable "shell" {
  description = "远端 shell，默认 bash。"
  type        = string
  default     = "bash"
}

variable "content" {
  description = "待发布文件的完整内容，无换行 ASCII base64 编码。"
  type        = string
  sensitive   = true

  validation {
    condition     = var.content == "" || can(regex("^[A-Za-z0-9+/=]+$", var.content))
    error_message = "content 必须是无换行的 ASCII base64 字符串。"
  }
}

variable "content_sha256" {
  description = "content base64 解码后原始字节的 SHA-256，64 位小写十六进制。"
  type        = string

  validation {
    condition     = var.content_sha256 != null && can(regex("^[0-9a-f]{64}$", var.content_sha256))
    error_message = "content_sha256 必须是 64 位小写十六进制 SHA-256。"
  }
}

variable "target_path" {
  description = "目标机上的绝对 ASCII 路径（最多 512 字节），文件将被发布到该路径。"
  type        = string

  validation {
    condition     = startswith(var.target_path, "/")
    error_message = "target_path 必须是绝对路径，拒绝相对路径。"
  }

  validation {
    condition     = can(regex("^[\\x20-\\x7E]+$", var.target_path))
    error_message = "target_path 必须仅包含可打印 ASCII 字符，以保证命令字节长度预算。"
  }

  validation {
    condition     = !strcontains(var.target_path, "..")
    error_message = "target_path 不得包含 '..' 路径穿越。"
  }

  validation {
    condition     = !strcontains(var.target_path, "'")
    error_message = "target_path 不得包含单引号，避免破坏渲染脚本。"
  }

  validation {
    condition     = length(var.target_path) <= 512
    error_message = "target_path 不得超过 512 字节，以保证直传命令长度预算。"
  }
}

variable "file_mode" {
  description = "目标文件的权限模式，4 位八进制，如 0644 或 0755。"
  type        = string
  default     = "0644"

  validation {
    condition     = can(regex("^[0-7]{4}$", var.file_mode))
    error_message = "file_mode 必须是 4 位八进制字符串，如 0644。"
  }
}

variable "chunk_size" {
  description = "每个分片的 base64 payload 字节上限（不含命令模板固定开销）。"
  type        = number
  default     = 89000

  validation {
    condition     = var.chunk_size >= 64
    error_message = "chunk_size 不得小于 64 字节。"
  }
}

variable "staging_root" {
  description = "远端 staging 根目录（仅可打印 ASCII，最多 512 字节），staging 与 marker 会放在其下的 <sha256> 子目录中。"
  type        = string
  default     = "/var/tmp/qiniu-instance-exec-file-transfer"

  validation {
    condition     = startswith(var.staging_root, "/")
    error_message = "staging_root 必须是绝对路径。"
  }

  validation {
    condition     = can(regex("^[\\x20-\\x7E]+$", var.staging_root))
    error_message = "staging_root 必须仅包含可打印 ASCII 字符，以保证命令字节长度预算。"
  }

  validation {
    condition     = length(var.staging_root) <= 512
    error_message = "staging_root 不得超过 512 字节，以保证直传命令长度预算。"
  }
}

variable "destroy_cleanup" {
  description = "是否在资源销毁/替换时清理严格匹配的受管文件，默认 true。"
  type        = bool
  default     = true
}
