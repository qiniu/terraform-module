variable "instance_id" {
  description = "目标实例 ID。"
  type        = string
}

variable "private_key" {
  description = "用于 root 远程连接的 SSH 私钥。"
  type        = string
  sensitive   = true
}

variable "runtime_file_contents" {
  description = "按相对路径索引的 Ansible 运行时文件内容（base64）。"
  type        = map(string)
  sensitive   = true
}

variable "runtime_file_metadata" {
  description = "按相对路径索引的 Ansible 运行时文件发布元数据。"
  type = map(object({
    file_mode   = string
    sha256      = string
    target_path = string
  }))
}

variable "runtime_manifest" {
  description = "Ansible 运行时文件 SHA-256 清单的发布元数据。"
  type = object({
    content     = string
    file_mode   = string
    sha256      = string
    target_path = string
  })
}

variable "bootstrap" {
  description = "Ansible 安装 bootstrap 的发布元数据。"
  type = object({
    content     = string
    file_mode   = string
    sha256      = string
    target_path = string
  })
}

check "runtime_file_keys_match" {
  assert {
    condition     = toset(keys(var.runtime_file_contents)) == toset(keys(var.runtime_file_metadata))
    error_message = "runtime_file_contents 与 runtime_file_metadata 必须使用相同的相对路径。"
  }
}
