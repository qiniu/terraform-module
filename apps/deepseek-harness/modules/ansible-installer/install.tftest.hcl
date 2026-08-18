variables {
  dsh_web_proxy_port              = 3081
  preview_ports                   = [30080]
  dsh_web_public_authority        = "dsh.example.test"
  static_preview_public_authority = "static-preview.example.test"
  static_preview_proxy_port       = 3082
  las_instance_id                 = "i-69832576086fed2869d55cd4"
  las_region_id                   = "ap-southeast-1"
  las_region_name                 = "新加坡"
  preview_public_authorities      = ["preview.example.test"]
  code_server_proxy_port          = 3084
  code_server_public_authority    = "code.example.test"
  dsh_web_username                = "admin"
  dsh_web_password                = "web-password-must-not-appear"
  code_server_password            = "Code-server-safe-1234"
}

run "renders_sensitive_bootstrap_command" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "exec '/opt/las-dsh-installer/bootstrap/bootstrap.sh' '") &&
      base64decode(nonsensitive(output.file_contents[local.bootstrap_target_path])) == local.bootstrap_content &&
      output.file_metadata[local.bootstrap_target_path].file_mode == "0700" &&
      output.file_metadata[local.bootstrap_target_path].sha256 == sha256(local.bootstrap_content) &&
      !strcontains(nonsensitive(output.install_command), "runtime-sha256") &&
      !strcontains(nonsensitive(output.install_command), "ansible_archive") &&
      jsondecode(base64decode(regex("'([^']+)'$", nonsensitive(output.install_command))[0])).static_preview_proxy_port == 3082 &&
      jsondecode(base64decode(regex("'([^']+)'$", nonsensitive(output.install_command))[0])).static_preview_public_authority == "static-preview.example.test" &&
      !strcontains(nonsensitive(output.install_command), "web-password-must-not-appear") &&
      !strcontains(nonsensitive(output.install_command), "Code-server-safe-1234") &&
      length(nonsensitive(output.install_command)) <= 8192
    )
    error_message = "安装命令必须只携带编码后的变量，并不得泄露密码明文。"
  }
}

run "timestamps_persistent_bootstrap_log" {
  command = plan

  assert {
    condition = (
      strcontains(local.bootstrap_content, "required_packages=(ca-certificates curl moreutils)") &&
      strcontains(local.bootstrap_content, "log_file=/var/log/las-dsh-installer.log") &&
      strcontains(local.bootstrap_content, "install -o root -g root -m 0600 /dev/null \"$${log_file}\"") &&
      strcontains(local.bootstrap_content, "run_install 2>&1 | ts '[%Y-%m-%d %H:%M:%S]' | tee \"$${log_file}\"")
    )
    error_message = "Bootstrap 必须安装 moreutils，并将带时间戳的安装日志持久化为 root-only 文件。"
  }
}

run "restores_executable_umask_before_ansible_sync" {
  command = plan

  assert {
    condition = strcontains(
      local.bootstrap_content,
      "  umask 022\n  if [ ! -x \"$${UV_PROJECT_ENVIRONMENT}/bin/ansible-playbook\" ] ||",
    )
    error_message = "uv 虚拟环境必须在可执行的 umask 下创建，以支持 dsh 用户运行 Ansible 模块。"
  }
}

run "installs_uv_with_official_installer" {
  command = plan

  assert {
    condition = (
      strcontains(local.bootstrap_content, "UV_VERSION=\"$${uv_version}\"") &&
      strcontains(local.bootstrap_content, "UV_UNMANAGED_INSTALL=\"$${uv_bin_dir}\"") &&
      strcontains(local.bootstrap_content, "https://astral.sh/uv/install.sh") &&
      strcontains(local.bootstrap_content, "\"$${uv_bin_dir}/uv\" --version")
    )
    error_message = "uv 必须通过官方安装脚本安装到固定目录，并校验安装结果。"
  }
}

run "reuses_matching_uv_and_ansible_venv" {
  command = plan

  assert {
    condition = (
      strcontains(local.bootstrap_content, "[ ! -x \"$${uv_bin_dir}/uvx\" ] ||") &&
      strcontains(local.bootstrap_content, "ansible_venv_marker=\"$${UV_PROJECT_ENVIRONMENT}/.las-dsh-requirements-sha256\"") &&
      strcontains(local.bootstrap_content, "\"$${uv_bin_dir}/uv\" sync --locked")
    )
    error_message = "预制镜像中的匹配 uv 与 Ansible venv 必须复用；不匹配时仍须重新安装或同步。"
  }
}

run "keeps_uv_globally_available_without_managed_registry" {
  command = plan

  assert {
    condition = (
      strcontains(local.bootstrap_content, "ln -sfn \"$${uv_bin_dir}/$${executable}\"") &&
      !strcontains(local.bootstrap_content, "managed_toolchains_dir") &&
      !strcontains(local.bootstrap_content, "cleanup_superseded_uv") &&
      !strcontains(local.bootstrap_content, "uv_release_url")
    )
    error_message = "uv 必须通过 /usr/local/bin 全局可用，且不得保留旧的自管理逻辑。"
  }
}

run "repairs_existing_ansible_venv_traversal_permissions" {
  command = plan

  assert {
    condition = strcontains(
      local.bootstrap_content,
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
      strcontains(local.bootstrap_content, format("find \"%s{UV_PROJECT_ENVIRONMENT}\" -type d -exec chmod 0755", "$")) &&
      strcontains(local.bootstrap_content, format("find \"%s{UV_PROJECT_ENVIRONMENT}\" -type f -exec chmod 0644", "$")) &&
      strcontains(local.bootstrap_content, format("find \"%s{UV_PROJECT_ENVIRONMENT}/bin\" -type f -exec chmod 0755", "$"))
    )
    error_message = "既有 Ansible 虚拟环境的目录、文件和 bin 脚本必须恢复为 dsh 可读/执行权限。"
  }
}

run "installs_pinned_pnpm_with_nodejs" {
  command = plan

  assert {
    condition = (
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/inventory/default/group_vars/all/main.yml"])),
        "pnpm_version: 11.22.0",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/nodejs/tasks/main.yml"])),
        "pnpm@{{ pnpm_version }}",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/nodejs/tasks/main.yml"])),
        "PATH: \"{{ nodejs_prefix }}/bin:{{ ansible_env.PATH }}\"",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/nodejs/tasks/main.yml"])),
        "    - pnpm",
      )
    )
    error_message = "Node.js role 必须安装并通过 /usr/local/bin 发布固定版本的 pnpm。"
  }
}

run "uses_pnpm_for_dsh_prewarm_and_offline_service" {
  command = plan

  assert {
    condition = (
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/inventory/default/group_vars/all/main.yml"])),
        "dsh_pnpm_store_dir: \"{{ dsh_home }}/.pnpm-store\"",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/tasks/main.yml"])),
        "      - /usr/local/bin/pnpm\n      - dlx",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/tasks/main.yml"])),
        "      - \"--allow-build=node-pty\"",
      ) &&
      !strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/tasks/main.yml"])),
        "      - --offline",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/tasks/main.yml"])),
        "dsh_needs_prewarm",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/tasks/main.yml"])),
        "path: \"{{ dsh_pnpm_dlx_cache_dir }}\"",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/tasks/main.yml"])),
        "PNPM_CONFIG_STORE_DIR: \"{{ dsh_pnpm_store_dir }}\"",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/tasks/main.yml"])),
        "PNPM_OFFLINE: \"true\"",
      ) &&
      !strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/tasks/main.yml"])),
        "/usr/local/bin/npm",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/templates/deepseek-harness.service.j2"])),
        "Environment=PNPM_OFFLINE=true",
      ) &&
      !strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/templates/deepseek-harness.service.j2"])),
        "PNPM_CONFIG_OFFLINE",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/templates/deepseek-harness.service.j2"])),
        "ExecStart=/usr/local/bin/pnpm dlx --allow-build=node-pty @deepseek-ai/dsh@{{ dsh_version }}",
      ) &&
      !strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/deepseek_harness/templates/deepseek-harness.service.j2"])),
        "/usr/local/bin/npx",
      )
    )
    error_message = "DeepSeek Harness 必须通过同一 pnpm store 预热，并使用 pnpm 强制离线启动。"
  }
}

run "publishes_complete_managed_toolchains" {
  command = plan

  assert {
    condition = (
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/nodejs/tasks/main.yml"])),
        "Verify the existing Node.js installation is managed",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/nodejs/tasks/main.yml"])),
        "Create a Node.js staging directory",
      ) &&
      can(regex(
        "(?s)Determine whether Node.js installation is current.*Create a Node.js staging directory",
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/nodejs/tasks/main.yml"])),
      )) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/nodejs/tasks/main.yml"])),
        "Make the Node.js staging directory traversable",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/nodejs/tasks/main.yml"])),
        "Make the Node.js prefix traversable",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/code_server/defaults/main.yml"])),
        "code_server_managed_marker: .las-dsh-managed",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/code_server/tasks/main.yml"])),
        "Verify the existing code-server installation is managed",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/code_server/tasks/main.yml"])),
        "Create a code-server staging directory",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/code_server/tasks/main.yml"])),
        "Make the code-server staging directory traversable",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/code_server/tasks/main.yml"])),
        "Make the code-server prefix traversable",
      )
    )
    error_message = "Node.js 和 code-server 必须仅替换受管前缀，并经临时目录完整发布。"
  }
}

run "publishes_managed_skill_templates" {
  command = plan

  assert {
    condition = (
      contains(
        keys(output.file_contents),
        "/opt/las-dsh-installer/project/roles/managed_skills/templates/las_dsh_environment/SKILL.md.j2",
      ) &&
      contains(
        keys(output.file_contents),
        "/opt/las-dsh-installer/project/roles/managed_skills/templates/las_static_preview/SKILL.md.j2",
      ) &&
      contains(
        keys(output.file_contents),
        "/opt/las-dsh-installer/project/roles/managed_skills/templates/las_static_preview/publish.sh.j2",
      ) &&
      contains(
        keys(output.file_contents),
        "/opt/las-dsh-installer/project/roles/managed_skills/templates/las_preview_ports/SKILL.md.j2",
      ) &&
      contains(
        keys(output.file_contents),
        "/opt/las-dsh-installer/project/roles/managed_skills/templates/las_preview_ports/manage-preview-port.sh.j2",
      ) &&
      length(base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/managed_skills/templates/las_dsh_environment/SKILL.md.j2"]))) > 0
    )
    error_message = "内置 las_* Skill 模板和脚本必须作为 Ansible runtime 文件发布。"
  }
}

run "installs_configured_skills" {
  command = plan

  assert {
    condition = (
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/inventory/default/group_vars/all/main.yml"])),
        "dsh_skills:",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/inventory/default/group_vars/all/main.yml"])),
        "https://github.com/vercel-labs/skills",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/inventory/default/group_vars/all/main.yml"])),
        "name: find-skills",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/skill_installer/tasks/main.yml"])),
        "/usr/local/bin/npx",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/skill_installer/tasks/main.yml"])),
        "loop: \"{{ dsh_skills }}\"",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/skill_installer/tasks/main.yml"])),
        "{{ item.source }}",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/skill_installer/tasks/main.yml"])),
        "{{ item.name }}/SKILL.md",
      )
    )
    error_message = "skill_installer 必须根据 dsh_skills 清单以 dsh 用户通过 Skills CLI 幂等安装 skill。"
  }
}

run "keeps_code_server_releases_with_version" {
  command = plan

  assert {
    condition = (
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/inventory/default/group_vars/all/main.yml"])),
        "code_server_releases:",
      ) &&
      strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/code_server/tasks/main.yml"])),
        "code_server_releases",
      ) &&
      !strcontains(
        base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/code_server/defaults/main.yml"])),
        "sha256:",
      )
    )
    error_message = "code-server release 清单必须与版本一同定义在 group_vars，role defaults 只保留私有派生值。"
  }
}

run "recognizes_code_server_version_with_build_metadata" {
  command = plan

  assert {
    condition = strcontains(
      base64decode(nonsensitive(output.file_contents["/opt/las-dsh-installer/project/roles/code_server/tasks/main.yml"])),
      "(code_server_installed_version.stdout | default('')).split() | first | default('') != code_server_version",
    )
    error_message = "code-server 版本检查必须忽略 --version 输出中的构建元数据，避免重复安装。"
  }
}
