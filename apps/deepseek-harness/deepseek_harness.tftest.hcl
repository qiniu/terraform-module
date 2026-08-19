mock_provider "qiniu" {}

mock_provider "random" {
  mock_resource "random_password" {
    override_during = plan
    defaults = {
      result = "Mock-safe-password-123"
    }
  }
}

override_module {
  target          = module.infrastructure
  override_during = plan
  outputs = {
    instance_id                     = "test-instance"
    instance_region_id              = "ap-southeast-1"
    instance_region_name            = "新加坡"
    deployment_private_key          = "test-private-key"
    dsh_web_public_authority        = "dsh.example.test"
    dsh_web_proxy_port              = 3081
    static_preview_public_authority = "static-preview.example.test"
    static_preview_proxy_port       = 3082
    preview_ports                   = [30080]
    preview_public_authorities      = ["preview.example.test"]
    code_server_public_authority    = "code.example.test"
    code_server_proxy_port          = 3084
    ssh_endpoints                   = []
  }
}

variables {
  instance_type           = "ecs.t1s.c2m4"
  system_disk_size        = 40
  internet_max_bandwidth  = 100
  cost_charge_type        = "PostPaid"
  cost_period             = null
  cost_period_unit        = "Month"
  enable_ssh_port_forward = false
  instance_password       = "Safe-pass-123"
}

run "uses_fixed_versions_and_installer_contract" {
  command = plan

  assert {
    condition = (
      var.preview_count == 1 &&
      module.infrastructure.dsh_web_proxy_port == 3081 &&
      module.infrastructure.static_preview_proxy_port == 3082 &&
      module.infrastructure.preview_ports == [30080] &&
      module.infrastructure.code_server_proxy_port == 3084
    )
    error_message = "infrastructure 必须固定 DSH Web、Static Preview、Preview 和 code-server 代理端口。"
  }

  assert {
    condition = (
      strcontains(nonsensitive(qiniu_compute_instance_exec.install_dsh.command), "exec '/opt/las-dsh-installer/bootstrap/bootstrap.sh' '") &&
      !strcontains(nonsensitive(qiniu_compute_instance_exec.install_dsh.command), "runtime-sha256") &&
      !strcontains(nonsensitive(qiniu_compute_instance_exec.install_dsh.command), "@deepseek-ai/dsh") &&
      length(nonsensitive(qiniu_compute_instance_exec.install_dsh.command)) <= 8192
    )
    error_message = "installer 必须固定版本，并以短命令调用已传输的 Ansible bootstrap。"
  }

  assert {
    condition = (
      qiniu_compute_instance_exec.install_dsh.instance_id == "test-instance" &&
      qiniu_compute_instance_exec.install_dsh.user == "root" &&
      qiniu_compute_instance_exec.install_dsh.port == "22" &&
      qiniu_compute_instance_exec.install_dsh.private_key == "test-private-key" &&
      qiniu_compute_instance_exec.install_dsh.shell == "bash" &&
      qiniu_compute_instance_exec.install_dsh.command == module.installer.install_command &&
      qiniu_compute_instance_exec.install_dsh.store_stdout == false &&
      qiniu_compute_instance_exec.install_dsh.store_stderr == false
    )
    error_message = "安装 exec 必须使用 root/bash/部署私钥且不保存 stdout/stderr。"
  }

  assert {
    condition = (
      nonsensitive(terraform_data.install_dsh_runtime.triggers_replace) ==
      nonsensitive(module.installer.file_metadata)
    )
    error_message = "运行时文件变更必须触发最终安装 exec 重新执行。"
  }

  assert {
    condition = (
      random_password.dsh_web[0].length == 24 &&
      random_password.dsh_web[0].upper &&
      random_password.dsh_web[0].lower &&
      random_password.dsh_web[0].numeric &&
      random_password.dsh_web[0].special &&
      random_password.dsh_web[0].override_special == "-._~"
    )
    error_message = "Web 密码必须为 24 位并包含所有字符类别，特殊字符须对 URL、Basic Auth 与 shell 安全。"
  }
}

run "enables_ssh_port_forward" {
  command = plan
  variables {
    enable_ssh_port_forward = true
  }
}

run "rejects_invalid_instance_type" {
  command = plan
  variables { instance_type = "c2m4" }
  expect_failures = [var.instance_type]
}

run "rejects_invalid_disk_size" {
  command = plan
  variables { system_disk_size = 45 }
  expect_failures = [var.system_disk_size]
}

run "rejects_invalid_bandwidth" {
  command = plan
  variables { internet_max_bandwidth = 150 }
  expect_failures = [var.internet_max_bandwidth]
}

run "rejects_postpaid_period" {
  command = plan
  variables { cost_period = 1 }
  expect_failures = [var.cost_period]
}

run "rejects_invalid_cost_charge_type" {
  command = plan
  variables { cost_charge_type = "Invalid" }
  expect_failures = [var.cost_charge_type]
}

run "rejects_prepaid_without_period" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = null
  }
  expect_failures = [var.cost_period]
}

run "rejects_invalid_period_unit" {
  command = plan
  variables { cost_period_unit = "Day" }
  expect_failures = [var.cost_period_unit]
}

run "rejects_out_of_range_period" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 37
  }
  expect_failures = [var.cost_period]
}

run "rejects_fractional_period" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 1.5
  }
  expect_failures = [var.cost_period]
}

run "rejects_year_period_above_three" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 4
    cost_period_unit = "Year"
  }
  expect_failures = [var.cost_period]
}

run "accepts_one_year_period" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 1
    cost_period_unit = "Year"
  }
}

run "accepts_three_year_period" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 3
    cost_period_unit = "Year"
  }
}

run "rejects_blank_instance_password" {
  command = plan
  variables {
    instance_password = "   "
  }
  expect_failures = [var.instance_password]
}

run "outputs_ssh_command_when_enabled" {
  command = plan
  variables {
    enable_ssh_port_forward = true
    instance_password       = "Safe-pass-123"
  }
  override_module {
    target          = module.infrastructure
    override_during = plan
    outputs = {
      instance_id                     = "test-instance"
      instance_region_id              = "ap-southeast-1"
      instance_region_name            = "新加坡"
      deployment_private_key          = "test-private-key"
      dsh_web_public_authority        = "dsh.example.test"
      dsh_web_proxy_port              = 3081
      static_preview_public_authority = "static-preview.example.test"
      static_preview_proxy_port       = 3082
      preview_ports                   = [30080]
      preview_public_authorities      = ["preview.example.test"]
      code_server_public_authority    = "code.example.test"
      code_server_proxy_port          = 3084
      ssh_endpoints                   = ["203.0.113.10:2222"]
    }
  }
  assert {
    condition     = output.ssh_command == "ssh -p 2222 root@203.0.113.10"
    error_message = "启用 SSH 时必须输出可执行的 root SSH 命令。"
  }
}

run "rejects_weak_instance_password" {
  command = plan
  variables { instance_password = "password" }
  expect_failures = [var.instance_password]
}

run "rejects_instance_password_longer_than_thirty" {
  command = plan
  variables {
    instance_password = "Aa1!aaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
  expect_failures = [var.instance_password]
}

run "accepts_thirty_character_instance_password" {
  command = plan
  variables {
    instance_password = "Aa1!aaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
}

run "outputs_public_contract" {
  command = plan

  assert {
    condition = (
      output.dsh_web_public_url == "https://dsh.example.test" &&
      output.code_server_public_url == "https://code.example.test" &&
      !issensitive(output.code_server_public_url) &&
      output.dsh_web_username == "admin" &&
      output.dsh_web_password == sensitive(random_password.dsh_web[0].result) &&
      output.ssh_command == null
    )
    error_message = "根模块输出必须包含 Web 凭据和可空 SSH 命令。"
  }
}

run "uses_user_supplied_web_passwords" {
  command = plan

  variables {
    dsh_web_password = "Custom-dsh-pass-123"
  }

  assert {
    condition = (
      try(length(random_password.dsh_web), -1) == 0 &&
      output.dsh_web_password == null
    )
    error_message = "用户输入 Web 密码时不得重复通过 output 返回，且不得创建未使用的随机密码。"
  }
}

run "rejects_invalid_user_supplied_dsh_web_password" {
  command = plan

  variables {
    dsh_web_password = "too-short"
  }

  expect_failures = [var.dsh_web_password]
}

run "supports_zero_preview_slots" {
  command = plan
  variables { preview_count = 0 }

  override_module {
    target          = module.infrastructure
    override_during = plan
    outputs = {
      instance_id                     = "test-instance"
      instance_region_id              = "ap-southeast-1"
      instance_region_name            = "新加坡"
      deployment_private_key          = "test-private-key"
      dsh_web_public_authority        = "dsh.example.test"
      dsh_web_proxy_port              = 3081
      static_preview_public_authority = "static-preview.example.test"
      static_preview_proxy_port       = 3082
      preview_ports                   = []
      preview_public_authorities      = []
      code_server_public_authority    = "code.example.test"
      code_server_proxy_port          = 3084
      ssh_endpoints                   = []
    }
  }

}
