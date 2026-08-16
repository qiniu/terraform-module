variable "instance_id" {
  description = "目标实例 ID。"
  type        = string
}

variable "private_key" {
  description = "用于 root 远程连接的 SSH 私钥。"
  type        = string
  sensitive   = true
}

variable "file_contents" {
  description = "按目标绝对路径索引的安装文件内容（base64）。"
  type        = map(string)
  sensitive   = true
}

variable "file_metadata" {
  description = "按目标绝对路径索引的安装文件发布元数据。"
  type = map(object({
    file_mode = string
    sha256    = string
  }))
}

check "file_keys_match" {
  assert {
    condition     = toset(keys(var.file_contents)) == toset(keys(var.file_metadata))
    error_message = "file_contents 与 file_metadata 必须使用相同的目标路径。"
  }
}
