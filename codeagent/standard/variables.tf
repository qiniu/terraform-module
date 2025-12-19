# Instance configuration variables
variable "instance_type" {
  type        = string
  description = "CodeAgent instance type (ECS specification)"
  default     = "ecs.c1.c16m32"

  validation {
    condition = var.instance_type != "" && contains([
      "ecs.t1.c1m2",
      "ecs.t1.c2m4",
      "ecs.t1.c4m8",
      "ecs.t1.c12m24",
      "ecs.t1.c32m64",
      "ecs.t1.c24m48",
      "ecs.t1.c8m16",
      "ecs.t1.c16m32",
      "ecs.g1.c16m120",
      "ecs.g1.c32m240",
      "ecs.c1.c1m2",
      "ecs.c1.c2m4",
      "ecs.c1.c4m8",
      "ecs.c1.c8m16",
      "ecs.c1.c16m32",
      "ecs.c1.c24m48",
      "ecs.c1.c12m24",
      "ecs.c1.c32m64",
    ], var.instance_type)
    error_message = "instance_type must be one of the allowed ECS instance types"
  }
}

variable "instance_system_disk_size" {
  type        = number
  description = "System disk size in GiB"
  default     = 100

  validation {
    condition     = var.instance_system_disk_size >= 20 && var.instance_system_disk_size <= 500
    error_message = "instance_system_disk_size must be between 20 and 500 GiB"
  }
}

variable "internet_max_bandwidth" {
  type        = number
  description = "Maximum internet bandwidth in Mbps (0-200)"
  default     = 100

  validation {
    condition     = var.internet_max_bandwidth > 0 && var.internet_max_bandwidth <= 200
    error_message = "internet_max_bandwidth must be between 0 and 200 Mbps"
  }
}

variable "image_id" {
  type        = string
  description = "CodeAgent pre-configured image ID"
  default     = "image-694ba6d04003c59f46bd71c5"

  validation {
    condition     = can(regex("^image-[a-z0-9]+$", var.image_id))
    error_message = "image_id must be in the format 'image-xxxxx'"
  }
}

# CodeAgent configuration variables
variable "model_api_key" {
  type        = string
  description = "AI Model API Key for CodeAgent (will be injected into supervisor config)"
  sensitive   = true

  validation {
    condition     = length(var.model_api_key) >= 10
    error_message = "model_api_key must be at least 10 characters long"
  }
}

# GitLab configuration variables
variable "gitlab_base_url" {
  type        = string
  description = "GitLab instance base URL"
  default     = ""

  validation {
    condition     = var.gitlab_base_url == "" || can(regex("^https?://", var.gitlab_base_url))
    error_message = "gitlab_base_url must start with http:// or https://"
  }
}

variable "gitlab_webhook_secret" {
  type        = string
  description = "GitLab webhook secret"
  default     = ""
  sensitive   = true
}

variable "gitlab_token" {
  type        = string
  description = "GitLab Personal Access Token"
  default     = ""
  sensitive   = true
}

# CNB configuration variables
variable "cnb_base_url" {
  type        = string
  description = "CNB platform base URL"
  default     = ""

  validation {
    condition     = var.cnb_base_url == "" || can(regex("^https?://", var.cnb_base_url))
    error_message = "cnb_base_url must start with http:// or https://"
  }
}

variable "cnb_api_url" {
  type        = string
  description = "CNB platform API URL"
  default     = ""

  validation {
    condition     = var.cnb_api_url == "" || can(regex("^https?://", var.cnb_api_url))
    error_message = "cnb_api_url must start with http:// or https://"
  }
}

variable "cnb_webhook_secret" {
  type        = string
  description = "CNB platform webhook secret"
  default     = ""
  sensitive   = true
}

variable "cnb_token" {
  type        = string
  description = "CNB platform access token"
  default     = ""
  sensitive   = true
}
