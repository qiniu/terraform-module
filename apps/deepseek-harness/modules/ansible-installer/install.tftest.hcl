variables {
  dsh_web_port                 = 3081
  preview_ports                = [30080]
  dsh_web_public_authority     = "dsh.example.test"
  preview_public_authorities   = ["preview.example.test"]
  code_server_web_port         = 3087
  code_server_public_authority = "code.example.test"
  dsh_web_username             = "admin"
  dsh_web_password             = "web-password-must-not-appear"
  code_server_password         = "Code-server-safe-1234"
}

run "renders_sensitive_manifest_bootstrap_command" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "/opt/las-dsh-installer/bootstrap/install.sh' '/opt/las-dsh-installer/project/.runtime-sha256'") &&
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
      "umask 022\n\"$${uv_bin_dir}/uv\" sync --locked",
    )
    error_message = "uv 虚拟环境必须在可执行的 umask 下创建，以支持 dsh 用户运行 Ansible 模块。"
  }
}

run "installs_uv_with_official_installer" {
  command = plan

  assert {
    condition = (
      strcontains(base64decode(output.bootstrap.content), "UV_VERSION=\"$${uv_version}\"") &&
      strcontains(base64decode(output.bootstrap.content), "UV_UNMANAGED_INSTALL=\"$${uv_bin_dir}\"") &&
      strcontains(base64decode(output.bootstrap.content), "https://astral.sh/uv/install.sh") &&
      strcontains(base64decode(output.bootstrap.content), "\"$${uv_bin_dir}/uv\" --version")
    )
    error_message = "uv 必须通过官方安装脚本安装到固定目录，并校验安装结果。"
  }
}

run "keeps_uv_globally_available_without_managed_registry" {
  command = plan

  assert {
    condition = (
      strcontains(base64decode(output.bootstrap.content), "ln -sfn \"$${uv_bin_dir}/$${executable}\"") &&
      !strcontains(base64decode(output.bootstrap.content), "managed_toolchains_dir") &&
      !strcontains(base64decode(output.bootstrap.content), "cleanup_superseded_uv") &&
      !strcontains(base64decode(output.bootstrap.content), "uv_release_url")
    )
    error_message = "uv 必须通过 /usr/local/bin 全局可用，且不得保留旧的自管理逻辑。"
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
