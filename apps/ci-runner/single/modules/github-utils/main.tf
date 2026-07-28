data "http" "github_user" {
  url = "https://api.github.com/users/${var.github_login}"

  request_headers = {
    Accept = "application/vnd.github+json"
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "GitHub 用户 ${var.github_login} 不存在或 GitHub API 不可达（HTTP ${self.status_code}）。"
    }
  }
}
