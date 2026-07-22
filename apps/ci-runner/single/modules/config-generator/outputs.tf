output "config_content" {
  description = "完整的 runnerd YAML 配置内容。"
  value       = local.config_content
  sensitive   = true
}

output "webhook_secret" {
  description = "用于校验 GitHub webhook 签名的随机密钥。"
  value       = random_bytes.webhook_secret.base64
  sensitive   = true
}
