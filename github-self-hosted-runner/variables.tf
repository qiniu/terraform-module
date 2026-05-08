# ==========================================
# 虚拟机配置
# ==========================================

variable "instance_type" {
  type        = string
  description = "GitHub Runner instance type (规格选择参考文档中的推荐配置)"
  default     = "ecs.t1.c2m4" # 2核4GB，适合轻量级测试

  validation {
    condition = contains([
      "ecs.t1.c1m2",    # 1核2GB
      "ecs.t1.c2m4",    # 2核4GB
      "ecs.t1.c4m8",    # 4核8GB
      "ecs.t1.c8m16",   # 8核16GB
      "ecs.t1.c12m24",  # 12核24GB
      "ecs.t1.c16m32",  # 16核32GB
      "ecs.t1.c24m48",  # 24核48GB
      "ecs.t1.c32m64",  # 32核64GB
      "ecs.g1.c16m120", # 16核120GB (高内存)
      "ecs.g1.c32m240", # 32核240GB (高内存)
      "ecs.c1.c1m2",
      "ecs.c1.c2m4",
      "ecs.c1.c4m8",
      "ecs.c1.c8m16",
      "ecs.c1.c16m32",
      "ecs.c1.c24m48",
      "ecs.c1.c12m24",
      "ecs.c1.c32m64",
    ], var.instance_type)
    error_message = "instance_type must be one of the allowed types"
  }
}

variable "instance_system_disk_size" {
  type        = number
  description = "System disk size in GiB (建议至少 50GB 用于存储构建缓存)"
  default     = 50

  validation {
    condition     = var.instance_system_disk_size >= 20
    error_message = "instance_system_disk_size must be at least 20 GiB"
  }
}

# ==========================================
# GitHub 配置
# ==========================================

variable "github_repo_url" {
  type        = string
  description = "GitHub repository URL (e.g., https://github.com/owner/repo)"

  validation {
    condition     = can(regex("^https://github\\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$", var.github_repo_url))
    error_message = "github_repo_url must be a valid GitHub repo URL: https://github.com/owner/repo"
  }
}

variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token (需要 admin:org 或 repo 权限)"
  sensitive   = true

  validation {
    condition     = length(var.github_token) > 20
    error_message = "github_token appears to be invalid (too short)"
  }
}

variable "runner_labels" {
  type        = list(string)
  description = "Custom labels for the runner (会自动添加 self-hosted, linux, x64)"
  default     = []

  validation {
    condition = alltrue([
      for label in var.runner_labels : can(regex("^[a-zA-Z0-9_-]+$", label))
    ])
    error_message = "runner_labels must contain only alphanumeric, underscore, and hyphen characters"
  }
}

variable "runner_name" {
  type        = string
  description = "Custom runner name (如果为空则自动生成)"
  default     = ""

  validation {
    condition     = var.runner_name == "" || length(var.runner_name) <= 64
    error_message = "runner_name must be 64 characters or less"
  }
}

# ==========================================
# 可选：Runner 账户配置
# ==========================================

variable "runner_username" {
  type        = string
  description = "Username for the runner process (默认使用 'runner')"
  default     = "runner"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]*$", var.runner_username))
    error_message = "runner_username must be a valid Linux username"
  }
}

variable "enable_docker" {
  type        = bool
  description = "是否安装 Docker (用于 Docker 构建任务)"
  default     = true
}

variable "additional_packages" {
  type        = list(string)
  description = "Additional apt packages to install (例如: ['nodejs', 'python3-pip'])"
  default     = []
}
