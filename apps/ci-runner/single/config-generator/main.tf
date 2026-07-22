resource "random_bytes" "session_secret" {
  length = 32
}

resource "random_bytes" "encryption_key" {
  length = 32
}

resource "random_bytes" "webhook_secret" {
  length = 32
}

locals {
  config = {
    server = {
      http_addr             = ":25500"
      read_timeout_seconds  = 15
      write_timeout_seconds = 60
      idle_timeout_seconds  = 120
    }
    database = {
      backend = "sqlite"
      dsn     = "/var/lib/runnerd/runnerd.db"
    }
    auth = {
      session_secret    = random_bytes.session_secret.base64
      encryption_key    = random_bytes.encryption_key.base64
      session_ttl_hours = 12
    }
    sandbox = {
      timeout_seconds        = 3600
      create_timeout_seconds = 120
      stop_timeout_seconds   = 30
    }
    github = {
      webhook_secret = random_bytes.webhook_secret.base64
      app = {
        id               = var.github_app_id
        slug             = var.github_app_slug
        private_key_file = "/etc/runnerd/secrets/github-app.pem"
      }
      oauth = {
        client_id     = var.github_oauth_client_id
        client_secret = var.github_oauth_client_secret
        redirect_url  = "${trimsuffix(var.public_url, "/")}/auth/github/callback"
      }
    }
    worker = {
      max_concurrent_runners      = 100
      runner_idle_timeout_seconds = 300
      recovery_timeout_seconds    = 120
      lease_ttl_seconds           = 300
      retry_base_delay_seconds    = 15
      retry_max_delay_seconds     = 300
      retry_max_attempts          = 5
    }
  }

  config_content = yamlencode(local.config)
}
