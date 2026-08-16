variables {
  dsh_web_port                 = 3081
  preview_count                = 1
  preview_ports                = [30080, 30081, 30082, 30083]
  dsh_web_public_authority     = "dsh.example.test"
  preview_public_authorities   = ["preview.example.test"]
  code_server_web_port         = 3087
  code_server_public_authority = "code.example.test"
  web_username                 = "admin"
  web_password                 = "web-password-must-not-appear"
  code_server_password         = "Code-server-safe-1234"
}

run "renders_sensitive_manifest_bootstrap_command" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "/opt/las-dsh-installer/bootstrap/install.sh' '0.12.5'") &&
      strcontains(nonsensitive(output.install_command), "/opt/las-dsh-installer/project/.runtime-sha256") &&
      !strcontains(nonsensitive(output.install_command), "ansible_archive") &&
      !strcontains(nonsensitive(output.install_command), "web-password-must-not-appear") &&
      !strcontains(nonsensitive(output.install_command), "Code-server-safe-1234") &&
      length(nonsensitive(output.install_command)) <= 8192
    )
    error_message = "安装命令必须只携带运行时清单校验值和编码后的变量，并不得泄露密码明文。"
  }
}

run "renders_bootstrap_shell_escapes_before_transfer" {
  command = plan

  assert {
    condition = (
      strcontains(base64decode(output.bootstrap.content), format("project_dir=\"%s{installer_root}/project\"", "$")) &&
      !strcontains(base64decode(output.bootstrap.content), format("%s%s{installer_root}", "$", "$"))
    )
    error_message = "传输前必须渲染 bootstrap 的 Terraform shell 转义。"
  }
}

run "restores_executable_umask_before_ansible_sync" {
  command = plan

  assert {
    condition = strcontains(
      base64decode(output.bootstrap.content),
      "umask 022\nuv sync --locked",
    )
    error_message = "uv 虚拟环境必须在可执行的 umask 下创建，以支持 dsh 用户运行 Ansible 模块。"
  }
}

run "repairs_existing_ansible_venv_traversal_permissions" {
  command = plan

  assert {
    condition = strcontains(
      base64decode(output.bootstrap.content),
      format(
        "chmod 0755 \"%s{UV_PROJECT_ENVIRONMENT}\" \"%s{UV_PROJECT_ENVIRONMENT}/bin\"",
        "$",
        "$",
      ),
    )
    error_message = "既有 root-only Ansible 虚拟环境必须恢复为可供 dsh 执行模块解释器的权限。"
  }
}

run "repairs_existing_ansible_venv_read_permissions" {
  command = plan

  assert {
    condition = (
      strcontains(base64decode(output.bootstrap.content), format("find \"%s{UV_PROJECT_ENVIRONMENT}\" -type d -exec chmod 0755", "$")) &&
      strcontains(base64decode(output.bootstrap.content), format("find \"%s{UV_PROJECT_ENVIRONMENT}\" -type f -exec chmod 0644", "$")) &&
      strcontains(base64decode(output.bootstrap.content), format("find \"%s{UV_PROJECT_ENVIRONMENT}/bin\" -type f -exec chmod 0755", "$"))
    )
    error_message = "既有 Ansible 虚拟环境的目录、文件和 bin 脚本必须恢复为 dsh 可读/执行权限。"
  }
}

run "rejects_port_collisions" {
  command = plan

  variables {
    code_server_web_port = 3080
  }

  expect_failures = [output.install_command]
}
