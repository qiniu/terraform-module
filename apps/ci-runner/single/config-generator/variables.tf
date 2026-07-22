variable "public_url" {
  description = "runnerd 对外提供服务的 HTTPS URL。"
  type        = string

  validation {
    condition     = can(regex("^https://[^/?#[:space:]]+/?$", var.public_url))
    error_message = "public_url 必须是仅包含 authority 和可选结尾斜杠的 HTTPS URL。"
  }
}

variable "github_app_id" {
  description = "GitHub App ID。"
  type        = number

  validation {
    condition     = var.github_app_id > 0 && floor(var.github_app_id) == var.github_app_id
    error_message = "github_app_id 必须是正整数。"
  }
}

variable "github_app_slug" {
  description = "GitHub App slug。"
  type        = string

  validation {
    condition     = trimspace(var.github_app_slug) != ""
    error_message = "github_app_slug 不能为空。"
  }
}

variable "github_oauth_client_id" {
  description = "GitHub OAuth client ID。"
  type        = string

  validation {
    condition     = trimspace(var.github_oauth_client_id) != ""
    error_message = "github_oauth_client_id 不能为空。"
  }
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth client secret。"
  type        = string
  sensitive   = true

  validation {
    condition     = trimspace(var.github_oauth_client_secret) != ""
    error_message = "github_oauth_client_secret 不能为空。"
  }
}
