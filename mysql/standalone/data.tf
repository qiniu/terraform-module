# 生成资源后缀，避免命名冲突
resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

locals {
  standalone_suffix = random_string.resource_suffix.result
}
