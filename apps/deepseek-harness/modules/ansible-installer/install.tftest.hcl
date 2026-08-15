variables {
  dsh_version                  = "0.1.2"
  node_version                 = "24.19.0"
  dsh_port                     = 3080
  nginx_proxy_port             = 3081
  preview_count                = 1
  preview_ports                = [30080, 30081, 30082, 30083]
  public_authority             = "dsh.example.test"
  preview_public_authorities   = ["preview.example.test"]
  code_server_version          = "4.132.0"
  code_server_port             = 3086
  code_server_proxy_port       = 3087
  code_server_public_authority = "code.example.test"
  web_username                 = "admin"
  web_password                 = "web-password-must-not-appear"
  code_server_password         = "Code-server-safe-1234"
}

run "renders_sensitive_self_contained_command" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "uv_version='0.12.5'") &&
      strcontains(nonsensitive(output.install_command), "ansible_archive_base64='") &&
      strcontains(nonsensitive(output.install_command), "extra_vars_base64='") &&
      !strcontains(nonsensitive(output.install_command), "web-password-must-not-appear") &&
      !strcontains(nonsensitive(output.install_command), "Code-server-safe-1234") &&
      length(nonsensitive(output.install_command)) <= 131072
    )
    error_message = "安装命令必须携带受限归档和编码后的变量，并不得泄露密码明文。"
  }
}

run "uv_version_changes_rendered_command" {
  command = plan

  variables {
    uv_version = "0.12.6"
  }

  assert {
    condition     = strcontains(nonsensitive(output.install_command), "uv_version='0.12.6'")
    error_message = "修改 uv_version 必须改变引导命令中的固定版本。"
  }
}

run "rejects_port_collisions" {
  command = plan

  variables {
    code_server_proxy_port = 3080
  }

  expect_failures = [output.install_command]
}
