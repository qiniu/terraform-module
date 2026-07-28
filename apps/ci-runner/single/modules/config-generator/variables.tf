variable "public_url" {
  description = "runnerd 对外提供服务的 HTTPS URL。"
  type        = string
}

variable "runnerd_port" {
  description = "runnerd 监听端口。"
  type        = number
}

variable "github_app_id" {
  description = "GitHub App ID。"
  type        = number
}

variable "github_app_slug" {
  description = "GitHub App slug。"
  type        = string
}

variable "github_oauth_client_id" {
  description = "GitHub OAuth client ID。"
  type        = string
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth client secret。"
  type        = string
  sensitive   = true
}
