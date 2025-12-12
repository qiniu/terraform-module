# GitLab instance configuration
variable "gitlab_instance_type" {
  type        = string
  description = "GitLab instance type (ECS specification)"
  default     = "ecs.c1.c16m32"

  validation {
    condition = var.gitlab_instance_type != "" && contains([
      "ecs.t1.c1m2", "ecs.t1.c2m4", "ecs.t1.c4m8", "ecs.t1.c12m24",
      "ecs.t1.c32m64", "ecs.t1.c24m48", "ecs.t1.c8m16", "ecs.t1.c16m32",
      "ecs.g1.c16m120", "ecs.g1.c32m240", "ecs.c1.c1m2", "ecs.c1.c2m4",
      "ecs.c1.c4m8", "ecs.c1.c8m16", "ecs.c1.c16m32", "ecs.c1.c24m48",
      "ecs.c1.c12m24", "ecs.c1.c32m64"
    ], var.gitlab_instance_type)
    error_message = "gitlab_instance_type must be one of the allowed ECS instance types"
  }
}

variable "gitlab_system_disk_size" {
  type        = number
  description = "GitLab system disk size in GiB"
  default     = 100

  validation {
    condition     = var.gitlab_system_disk_size >= 100 
    error_message = "gitlab_system_disk_size must be greater than or equal to 100 GiB"
  }
}

variable "gitlab_internet_max_bandwidth" {
  type        = number
  description = "GitLab maximum internet bandwidth in Mbps (0-200)"
  default     = 100

  validation {
    condition     = var.gitlab_internet_max_bandwidth >= 0 && var.gitlab_internet_max_bandwidth <= 200
    error_message = "gitlab_internet_max_bandwidth must be between 0 and 200 Mbps"
  }
}

variable "gitlab_image_id" {
  type        = string
  description = "GitLab pre-configured image ID"
  default     = "image-693bdc845d7ae428f33348af"

  validation {
    condition     = can(regex("^image-[a-z0-9]+$", var.gitlab_image_id))
    error_message = "gitlab_image_id must be in the format 'image-xxxxx'"
  }
}

# CodeAgent instance configuration
variable "codeagent_instance_type" {
  type        = string
  description = "CodeAgent instance type (ECS specification)"
  default     = "ecs.c1.c16m32"

  validation {
    condition = var.codeagent_instance_type != "" && contains([
      "ecs.t1.c1m2", "ecs.t1.c2m4", "ecs.t1.c4m8", "ecs.t1.c12m24",
      "ecs.t1.c32m64", "ecs.t1.c24m48", "ecs.t1.c8m16", "ecs.t1.c16m32",
      "ecs.g1.c16m120", "ecs.g1.c32m240", "ecs.c1.c1m2", "ecs.c1.c2m4",
      "ecs.c1.c4m8", "ecs.c1.c8m16", "ecs.c1.c16m32", "ecs.c1.c24m48",
      "ecs.c1.c12m24", "ecs.c1.c32m64"
    ], var.codeagent_instance_type)
    error_message = "codeagent_instance_type must be one of the allowed ECS instance types"
  }
}

variable "codeagent_system_disk_size" {
  type        = number
  description = "CodeAgent system disk size in GiB"
  default     = 100

  validation {
    condition     = var.codeagent_system_disk_size >= 20 && var.codeagent_system_disk_size <= 500
    error_message = "codeagent_system_disk_size must be between 20 and 500 GiB"
  }
}

variable "codeagent_internet_max_bandwidth" {
  type        = number
  description = "CodeAgent maximum internet bandwidth in Mbps (0-200)"
  default     = 100

  validation {
    condition     = var.codeagent_internet_max_bandwidth >= 0 && var.codeagent_internet_max_bandwidth <= 200
    error_message = "codeagent_internet_max_bandwidth must be between 0 and 200 Mbps"
  }
}

variable "codeagent_image_id" {
  type        = string
  description = "CodeAgent pre-configured image ID"
  default     = "image-693b7d014fc9d0719531c21f"

  validation {
    condition     = can(regex("^image-[a-z0-9]+$", var.codeagent_image_id))
    error_message = "codeagent_image_id must be in the format 'image-xxxxx'"
  }
}

# CodeAgent configuration
variable "model_api_key" {
  type        = string
  description = "AI Model API Key for CodeAgent"
  sensitive   = true

  validation {
    condition     = length(var.model_api_key) >= 10
    error_message = "model_api_key must be at least 10 characters long"
  }
}

