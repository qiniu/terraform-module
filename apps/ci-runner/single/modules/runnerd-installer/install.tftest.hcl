variables {
  runnerd_version                = "v1.2.3"
  runnerd_port                   = 31234
  config_content                 = "github:\n  oauth:\n    client_secret: oauth-secret\n"
  github_app_private_key         = <<-EOT
    -----BEGIN PRIVATE KEY-----
    test-key
    -----END PRIVATE KEY-----
  EOT
  bootstrap_admin_github_user_id = 123456
}

run "trims_private_key_boundary_whitespace" {
  command = plan

  assert {
    condition = strcontains(
      nonsensitive(output.install_command),
      base64encode(trimspace(var.github_app_private_key)),
    )
    error_message = "安装命令中的私钥必须先移除首尾空白再进行 Base64 编码。"
  }
}

run "renders_install_command" {
  command = plan

  assert {
    condition = (
      startswith(nonsensitive(output.install_command), "#!/usr/bin/env bash\nset -euo pipefail") &&
      strcontains(nonsensitive(output.install_command), "qiniu/ci-runner/releases/download/v1.2.3") &&
      strcontains(nonsensitive(output.install_command), "/etc/runnerd/runnerd.yaml") &&
      strcontains(nonsensitive(output.install_command), "/etc/runnerd/secrets/github-app.pem") &&
      strcontains(nonsensitive(output.install_command), "User=runnerd") &&
      strcontains(nonsensitive(output.install_command), "--bootstrap-admin github:123456") &&
      strcontains(nonsensitive(output.install_command), "http://127.0.0.1:31234/healthz") &&
      !strcontains(nonsensitive(output.install_command), "-----BEGIN PRIVATE KEY-----") &&
      !strcontains(nonsensitive(output.install_command), "oauth-secret")
    )
    error_message = "install command 必须包含固定版本、配置、systemd、管理员和健康检查设置，且不泄露原始配置。"
  }

  assert {
    condition     = output.install_checksum == nonsensitive(sha256(output.install_command))
    error_message = "install checksum 必须是完整安装命令的 SHA-256 摘要。"
  }
}

run "version_changes_checksum" {
  command = plan

  variables {
    runnerd_version = "v1.2.4"
  }

  assert {
    condition     = output.install_checksum != run.renders_install_command.install_checksum
    error_message = "runnerd_version 变化必须触发新的安装摘要。"
  }
}
