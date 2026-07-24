output "user_id" {
  description = "GitHub 数字用户 ID"
  value       = jsondecode(data.http.github_user.response_body).id
}

output "login" {
  description = "GitHub 用户名（规范大小写）"
  value       = jsondecode(data.http.github_user.response_body).login
}
