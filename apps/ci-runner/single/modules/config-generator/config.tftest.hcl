variables {
  public_url                 = "https://runner.example.test"
  runnerd_port               = 31234
  github_app_id              = 123456
  github_app_slug            = "runner-example"
  github_oauth_client_id     = "Iv1.example"
  github_oauth_client_secret = "oauth-secret"
}

run "generates_runnerd_config" {
  command = apply

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).server.http_addr == ":31234"
    error_message = "server.http_addr 必须使用传入的 runnerd_port。"
  }

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).database == { backend = "sqlite", dsn = "/var/lib/runnerd/runnerd.db" }
    error_message = "database 配置不符合预期。"
  }

  assert {
    condition = yamldecode(nonsensitive(output.config_content)).github.app == {
      id               = 123456
      slug             = "runner-example"
      private_key_file = "/etc/runnerd/secrets/github-app.pem"
    }
    error_message = "github.app 配置不符合预期。"
  }

  assert {
    condition = yamldecode(nonsensitive(output.config_content)).github.oauth == {
      client_id     = "Iv1.example"
      client_secret = "oauth-secret"
      redirect_url  = "https://runner.example.test/auth/github/callback"
    }
    error_message = "github.oauth 配置不符合预期。"
  }

  assert {
    condition = length(toset([
      yamldecode(nonsensitive(output.config_content)).auth.session_secret,
      yamldecode(nonsensitive(output.config_content)).auth.encryption_key,
      yamldecode(nonsensitive(output.config_content)).github.webhook_secret,
    ])) == 3
    error_message = "三个随机 secret 必须互不相同。"
  }
}
