variables {
  runnerd_version                = "v1.2.3"
  runnerd_install_revision       = "test-a"
  runnerd_port                   = 25500
  config_content                 = "github:\n  oauth:\n    client_secret: oauth-secret\n"
  github_app_private_key_base64  = "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCnRlc3Qta2V5Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K"
  bootstrap_admin_github_user_id = 123456
}

run "renders_safe_install_and_destroy_commands" {
  command = plan

  assert {
    condition = (
      startswith(nonsensitive(output.install_command), "#!/usr/bin/env bash\nset -euo pipefail") &&
      !strcontains(nonsensitive(output.install_command), "sudo") &&
      !strcontains(nonsensitive(output.install_command), "RUNNERD_INSTALL") &&
      strcontains(nonsensitive(output.install_command), "qiniu/ci-runner/releases/download/v1.2.3") &&
      strcontains(nonsensitive(output.install_command), "x86_64") &&
      strcontains(nonsensitive(output.install_command), "amd64") &&
      strcontains(nonsensitive(output.install_command), "aarch64") &&
      strcontains(nonsensitive(output.install_command), "arm64") &&
      strcontains(nonsensitive(output.install_command), "retry 5 apt-get update") &&
      !strcontains(nonsensitive(output.install_command), "checksums") &&
      !strcontains(nonsensitive(output.install_command), "sha256sum") &&
      strcontains(nonsensitive(output.install_command), "/opt/runnerd/bin/runnerd") &&
      strcontains(nonsensitive(output.install_command), "/etc/runnerd/runnerd.yaml") &&
      strcontains(nonsensitive(output.install_command), "/etc/runnerd/secrets/github-app.pem") &&
      strcontains(nonsensitive(output.install_command), "install -o root -g runnerd -m 0640") &&
      strcontains(nonsensitive(output.install_command), "install -o runnerd -g runnerd -m 0600") &&
      strcontains(nonsensitive(output.install_command), "User=runnerd") &&
      strcontains(nonsensitive(output.install_command), "Group=runnerd") &&
      strcontains(nonsensitive(output.install_command), "WorkingDirectory=/var/lib/runnerd") &&
      strcontains(nonsensitive(output.install_command), "Restart=on-failure") &&
      strcontains(nonsensitive(output.install_command), "systemctl enable runnerd.service") &&
      strcontains(nonsensitive(output.install_command), "systemctl restart runnerd.service") &&
      strcontains(nonsensitive(output.install_command), "--bootstrap-admin github:123456") &&
      strcontains(nonsensitive(output.install_command), "seq 1 60") &&
      strcontains(nonsensitive(output.install_command), "http://127.0.0.1:25500/healthz") &&
      strcontains(nonsensitive(output.install_command), "journalctl -u runnerd.service -n 100") &&
      !strcontains(nonsensitive(output.install_command), "oauth-secret") &&
      !strcontains(nonsensitive(output.install_command), "runnerd-terraform-verification")
    )
    error_message = "install command must pin the release archive, install with exact ownership, start systemd, and hide raw secrets"
  }

  assert {
    condition = (
      length(trimspace(output.destroy_command)) > 0 &&
      startswith(output.destroy_command, "#!/usr/bin/env bash\nset -euo pipefail") &&
      !strcontains(output.destroy_command, "sudo") &&
      !strcontains(output.destroy_command, "RUNNERD_DESTROY") &&
      strcontains(output.destroy_command, "systemctl disable --now runnerd.service") &&
      strcontains(output.destroy_command, "/opt/runnerd/bin/runnerd") &&
      strcontains(output.destroy_command, "/etc/runnerd/runnerd.yaml") &&
      strcontains(output.destroy_command, "/etc/runnerd/secrets/github-app.pem") &&
      strcontains(output.destroy_command, "/etc/systemd/system/runnerd.service") &&
      strcontains(output.destroy_command, "systemctl daemon-reload") &&
      strcontains(output.destroy_command, "rmdir") &&
      !strcontains(output.destroy_command, "/var/lib/runnerd") &&
      !strcontains(output.destroy_command, "rm -r") &&
      !strcontains(output.destroy_command, "userdel") &&
      !strcontains(output.destroy_command, "runnerd-terraform-verification")
    )
    error_message = "destroy command must be a non-empty, data-preserving uninstall"
  }

  assert {
    condition     = length(output.install_checksum) == 64
    error_message = "install checksum must be a SHA-256 hex digest"
  }

  assert {
    condition = output.install_checksum == nonsensitive(sha256(jsonencode({
      version          = var.runnerd_version
      revision         = var.runnerd_install_revision
      port             = var.runnerd_port
      config           = var.config_content
      pem_base64       = var.github_app_private_key_base64
      bootstrap_admin  = var.bootstrap_admin_github_user_id
      install_template = file("${path.module}/templates/install.sh.tftpl")
    })))
    error_message = "install checksum must include every install input and the raw install template"
  }
}

run "renders_failure_safe_control_flow" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "failure_status=\"$?\"") &&
      strcontains(nonsensitive(output.install_command), "trap - ERR") &&
      can(regex(
        "install_failure\\(\\) \\{[^}]*systemctl status runnerd.service --no-pager[^}]*journalctl -u runnerd.service -n 100 --no-pager[^}]*exit \"\\$failure_status\"[^}]*\\}",
        nonsensitive(output.install_command),
      )) &&
      can(regex(
        "(?s)trap install_failure ERR.*systemctl daemon-reload.*systemctl enable runnerd.service.*systemctl restart runnerd.service",
        nonsensitive(output.install_command),
      ))
    )
    error_message = "install command must register one failure trap before all systemd lifecycle commands"
  }

  assert {
    condition = (
      strcontains(output.destroy_command, "unit_load_state=\"$(systemctl show --property=LoadState --value runnerd.service)\"") &&
      strcontains(output.destroy_command, "if [ \"$unit_load_state\" != \"not-found\" ]; then") &&
      !strcontains(output.destroy_command, "systemctl disable --now runnerd.service || true") &&
      can(regex(
        "(?s)systemctl show --property=LoadState --value runnerd.service.*not-found.*systemctl disable --now runnerd.service.*fi.*rm -f",
        output.destroy_command,
      ))
    )
    error_message = "destroy command must tolerate only a missing unit and stop on real disable failures before deleting files"
  }
}

run "renders_verification_command" {
  command = plan

  assert {
    condition = (
      startswith(output.verify_command, "#!/usr/bin/env bash\nset -euo pipefail") &&
      strcontains(output.verify_command, "systemctl is-active --quiet runnerd.service") &&
      strcontains(output.verify_command, "bootstrap_admin_id=\"123456\"") &&
      strcontains(output.verify_command, "--bootstrap-admin github:$bootstrap_admin_id") &&
      strcontains(output.verify_command, "/var/lib/runnerd-terraform-verification") &&
      strcontains(output.verify_command, "systemctl restart runnerd.service") &&
      strcontains(output.verify_command, "http://127.0.0.1:25500/healthz") &&
      !strcontains(output.verify_command, "sudo -n")
    )
    error_message = "verify command must validate the installed service, bootstrap identity, and restart recovery without redundant sudo"
  }

  assert {
    condition = output.verify_checksum == nonsensitive(sha256(jsonencode({
      install_checksum = output.install_checksum
      verify_template  = file("${path.module}/templates/verify.sh.tftpl")
    })))
    error_message = "verify checksum must include the install checksum and raw verify template"
  }
}

run "revision_changes_checksum" {
  command = plan

  variables {
    runnerd_install_revision = "test-b"
  }

  assert {
    condition     = output.install_checksum != run.renders_safe_install_and_destroy_commands.install_checksum
    error_message = "revision must change install checksum"
  }
}

run "config_changes_checksum" {
  command = plan

  variables {
    config_content = "changed: true\n"
  }

  assert {
    condition     = output.install_checksum != run.renders_safe_install_and_destroy_commands.install_checksum
    error_message = "config must change install checksum"
  }
}

run "pem_changes_checksum" {
  command = plan

  variables {
    github_app_private_key_base64 = "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCmNoYW5nZWQKLS0tLS1FTkQgUFJJVkFURSBLRVktLS0tLQo="
  }

  assert {
    condition     = output.install_checksum != run.renders_safe_install_and_destroy_commands.install_checksum
    error_message = "PEM must change install checksum"
  }
}

run "admin_changes_checksum" {
  command = plan

  variables {
    bootstrap_admin_github_user_id = 654321
  }

  assert {
    condition     = output.install_checksum != run.renders_safe_install_and_destroy_commands.install_checksum
    error_message = "admin ID must change install checksum"
  }
}

run "version_changes_checksum" {
  command = plan

  variables {
    runnerd_version = "v1.2.4"
  }

  assert {
    condition     = output.install_checksum != run.renders_safe_install_and_destroy_commands.install_checksum
    error_message = "version must change install checksum"
  }
}

run "preserves_pem_line_breaks" {
  command = plan

  variables {
    github_app_private_key_base64 = "LS0tLS1CRUdJTiBQUklWQVRF\r\nIEtFWS0tLS0tCnRlc3Qta2V5Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K"
  }

  assert {
    condition     = output.install_checksum != run.renders_safe_install_and_destroy_commands.install_checksum
    error_message = "PEM Base64 必须按传入值参与 checksum，不进行换行归一化。"
  }
}

run "renders_custom_runnerd_port" {
  command = plan

  variables {
    runnerd_port = 31234
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "http://127.0.0.1:31234/healthz") &&
      strcontains(output.verify_command, "http://127.0.0.1:31234/healthz")
    )
    error_message = "install 和 verify command 必须使用传入的 runnerd_port。"
  }
}
