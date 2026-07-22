variables {
  public_url                 = "https://runner.example.test"
  github_app_id              = 123456
  github_app_slug            = "runner-example"
  github_oauth_client_id     = "Iv1.example"
  github_oauth_client_secret = "oauth-secret"
}

run "generates_complete_runnerd_config" {
  command = apply

  assert {
    condition     = toset(keys(yamldecode(nonsensitive(output.config_content)))) == toset(["server", "database", "auth", "sandbox", "github", "worker"])
    error_message = "配置根节点必须且只能包含 server、database、auth、sandbox、github 和 worker。"
  }

  assert {
    condition     = toset(keys(yamldecode(nonsensitive(output.config_content)).server)) == toset(["http_addr", "read_timeout_seconds", "write_timeout_seconds", "idle_timeout_seconds"])
    error_message = "server 字段集合不符合预期。"
  }

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).server == { http_addr = ":25500", read_timeout_seconds = 15, write_timeout_seconds = 60, idle_timeout_seconds = 120 }
    error_message = "server 固定值不符合预期。"
  }

  assert {
    condition     = toset(keys(yamldecode(nonsensitive(output.config_content)).database)) == toset(["backend", "dsn"])
    error_message = "database 字段集合不符合预期。"
  }

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).database == { backend = "sqlite", dsn = "/var/lib/runnerd/runnerd.db" }
    error_message = "database 固定值不符合预期。"
  }

  assert {
    condition     = toset(keys(yamldecode(nonsensitive(output.config_content)).auth)) == toset(["session_secret", "encryption_key", "session_ttl_hours"])
    error_message = "auth 字段集合不符合预期。"
  }

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).auth.session_ttl_hours == 12
    error_message = "auth.session_ttl_hours 必须为 12。"
  }

  assert {
    condition     = toset(keys(yamldecode(nonsensitive(output.config_content)).sandbox)) == toset(["timeout_seconds", "create_timeout_seconds", "stop_timeout_seconds"])
    error_message = "sandbox 字段集合不符合预期。"
  }

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).sandbox == { timeout_seconds = 3600, create_timeout_seconds = 120, stop_timeout_seconds = 30 }
    error_message = "sandbox 固定值不符合预期。"
  }

  assert {
    condition     = toset(keys(yamldecode(nonsensitive(output.config_content)).github)) == toset(["webhook_secret", "app", "oauth"])
    error_message = "github 字段集合不符合预期。"
  }

  assert {
    condition     = toset(keys(yamldecode(nonsensitive(output.config_content)).github.app)) == toset(["id", "slug", "private_key_file"])
    error_message = "github.app 字段集合不符合预期。"
  }

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).github.app == { id = 123456, slug = "runner-example", private_key_file = "/etc/runnerd/secrets/github-app.pem" }
    error_message = "github.app 固定值不符合预期。"
  }

  assert {
    condition     = toset(keys(yamldecode(nonsensitive(output.config_content)).github.oauth)) == toset(["client_id", "client_secret", "redirect_url"])
    error_message = "github.oauth 字段集合不符合预期。"
  }

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).github.oauth == { client_id = "Iv1.example", client_secret = "oauth-secret", redirect_url = "https://runner.example.test/auth/github/callback" }
    error_message = "github.oauth 固定值不符合预期。"
  }

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).github.webhook_secret == nonsensitive(output.webhook_secret)
    error_message = "配置中的 webhook secret 必须与 webhook_secret 输出一致。"
  }

  assert {
    condition     = toset(keys(yamldecode(nonsensitive(output.config_content)).worker)) == toset(["max_concurrent_runners", "runner_idle_timeout_seconds", "recovery_timeout_seconds", "lease_ttl_seconds", "retry_base_delay_seconds", "retry_max_delay_seconds", "retry_max_attempts"])
    error_message = "worker 字段集合不符合预期。"
  }

  assert {
    condition     = yamldecode(nonsensitive(output.config_content)).worker == { max_concurrent_runners = 100, runner_idle_timeout_seconds = 300, recovery_timeout_seconds = 120, lease_ttl_seconds = 300, retry_base_delay_seconds = 15, retry_max_delay_seconds = 300, retry_max_attempts = 5 }
    error_message = "worker 固定值不符合预期。"
  }

  assert {
    condition = alltrue([
      length(nonsensitive(random_bytes.session_secret.hex)) == 64,
      length(nonsensitive(random_bytes.encryption_key.hex)) == 64,
      length(nonsensitive(random_bytes.webhook_secret.hex)) == 64,
    ])
    error_message = "三个随机 secret 都必须恰好包含 32 字节。"
  }

  assert {
    condition = alltrue([
      yamldecode(nonsensitive(output.config_content)).auth.session_secret == nonsensitive(random_bytes.session_secret.base64),
      yamldecode(nonsensitive(output.config_content)).auth.encryption_key == nonsensitive(random_bytes.encryption_key.base64),
      yamldecode(nonsensitive(output.config_content)).github.webhook_secret == nonsensitive(random_bytes.webhook_secret.base64),
    ])
    error_message = "配置中的三个随机 secret 必须分别来自对应的 random_bytes 资源。"
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

run "rejects_public_url_path" {
  command = plan

  variables {
    public_url = "https://runner.example.test/path"
  }

  expect_failures = [var.public_url]
}

run "rejects_public_url_query" {
  command = plan

  variables {
    public_url = "https://runner.example.test?mode=test"
  }

  expect_failures = [var.public_url]
}

run "rejects_public_url_fragment" {
  command = plan

  variables {
    public_url = "https://runner.example.test#fragment"
  }

  expect_failures = [var.public_url]
}
