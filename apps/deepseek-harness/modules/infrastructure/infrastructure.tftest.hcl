mock_provider "qiniu" {
  override_during = plan

  mock_data "qiniu_compute_images" {
    defaults = {
      items = {
        "0" = {
          architecture    = "x86_64"
          created_at      = "2026-01-01T00:00:00Z"
          creator_account = "official"
          description     = "Ubuntu 24.04 LTS"
          id              = "ubuntu-2404"
          image_type      = "Public"
          min_cpu         = 1
          min_disk        = 20
          min_memory      = 1
          name            = "Ubuntu 24.04 LTS"
          os_distribution = "Ubuntu"
          os_platform     = "Linux"
          os_version      = "24.04 LTS"
          public          = true
          public_time     = "2026-01-01T00:00:00Z"
          region_id       = "ap-southeast-1"
          size            = 10
          state           = "Available"
          updated_at      = "2026-01-01T00:00:00Z"
        }
      }
    }
  }
}
mock_provider "random" {
  override_during = plan
}

override_data {
  target          = data.qiniu_compute_region.current
  override_during = plan
  values = {
    region = {
      features = {
        ebs                      = { supported = true }
        public_access_http_proxy = { supported = true }
      }
    }
  }
}

override_resource {
  target          = random_string.suffix
  override_during = plan
  values          = { result = "abc123" }
}

override_resource {
  target          = qiniu_compute_key_pair.deployment
  override_during = plan
  values          = { id = "test-key-pair" }
}

override_resource {
  target          = qiniu_compute_instance.deepseek_harness
  override_during = plan
  values          = { id = "i-test-instance" }
}

override_resource {
  target          = qiniu_compute_instance_public_access.preview[0]
  override_during = plan
  values          = { endpoint = "preview.example.test" }
}

override_resource {
  target          = qiniu_compute_instance_public_access.code_server
  override_during = plan
  values          = { endpoint = "code.example.test" }
}

variables {
  nginx_proxy_port         = 3081
  image_validation_enabled = false
  preview_count            = 1
  code_server_proxy_port   = 3087
  instance_type            = "ecs.t1s.c2m4"
  system_disk_size         = 40
  internet_max_bandwidth   = 100
  enable_ssh_port_forward  = false
  cost_charge_type         = "PostPaid"
  cost_period              = null
  cost_period_unit         = "Month"
  instance_password        = null
}

run "plans_complete_instance_and_public_access" {
  command = plan

  assert {
    condition = (
      qiniu_compute_key_pair.deployment.name == "deepseek-harness-abc123-deploy" &&
      qiniu_compute_key_pair.deployment.mode == "generate" &&
      qiniu_compute_instance.deepseek_harness.name == "deepseek-harness-abc123" &&
      qiniu_compute_instance.deepseek_harness.description == "DeepSeek Harness Instance - Managed by Terraform" &&
      qiniu_compute_instance.deepseek_harness.instance_type == "ecs.t1s.c2m4" &&
      qiniu_compute_instance.deepseek_harness.image_id == "ubuntu-2404" &&
      qiniu_compute_instance.deepseek_harness.system_disk_size == 40 &&
      qiniu_compute_instance.deepseek_harness.system_disk_type == "cloud.ssd" &&
      qiniu_compute_instance.deepseek_harness.internet_max_bandwidth == 100 &&
      qiniu_compute_instance.deepseek_harness.internet_charge_type == "PeakBandwidth" &&
      qiniu_compute_instance.deepseek_harness.cost_charge_type == "PostPaid" &&
      qiniu_compute_instance.deepseek_harness.disable_public_ip &&
      qiniu_compute_instance.deepseek_harness.key_pair_id == "test-key-pair" &&
      qiniu_compute_instance.deepseek_harness.timeouts.create == "30m" &&
      qiniu_compute_instance.deepseek_harness.timeouts.update == "20m" &&
      qiniu_compute_instance.deepseek_harness.timeouts.delete == "10m" &&
      qiniu_compute_instance_public_access.web.instance_id == qiniu_compute_instance.deepseek_harness.id &&
      qiniu_compute_instance_public_access.web.internal_port == 3081 &&
      qiniu_compute_instance_public_access.web.type == "HTTPProxy" &&
      qiniu_compute_instance_public_access.preview[0].instance_id == qiniu_compute_instance.deepseek_harness.id &&
      qiniu_compute_instance_public_access.preview[0].internal_port == 30080 &&
      qiniu_compute_instance_public_access.preview[0].type == "HTTPProxy" &&
      output.preview_public_authority == qiniu_compute_instance_public_access.preview[0].endpoint &&
      output.preview_public_url == "https://${qiniu_compute_instance_public_access.preview[0].endpoint}" &&
      length(output.preview_public_urls) == 1 &&
      qiniu_compute_instance_public_access.code_server.instance_id == qiniu_compute_instance.deepseek_harness.id &&
      qiniu_compute_instance_public_access.code_server.internal_port == 3087 &&
      qiniu_compute_instance_public_access.code_server.type == "HTTPProxy" &&
      output.code_server_public_authority == qiniu_compute_instance_public_access.code_server.endpoint &&
      output.code_server_public_url == "https://${qiniu_compute_instance_public_access.code_server.endpoint}" &&
      length(distinct([
        qiniu_compute_instance_public_access.web.internal_port,
        qiniu_compute_instance_public_access.preview[0].internal_port,
        qiniu_compute_instance_public_access.code_server.internal_port,
      ])) == 3 &&
      length(qiniu_compute_instance_public_access.ssh) == 0
    )
    error_message = "实例、部署密钥、磁盘、网络、计费、密码、超时以及 Web/Preview HTTPProxy 参数必须完整。"
  }
}

run "passes_prepaid_cost_parameters" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 12
    cost_period_unit = "Month"
  }
  assert {
    condition = (
      qiniu_compute_instance.deepseek_harness.cost_charge_type == "PrePaid" &&
      qiniu_compute_instance.deepseek_harness.cost_period == 12 &&
      qiniu_compute_instance.deepseek_harness.cost_period_unit == "Month"
    )
    error_message = "PrePaid 计费参数必须完整传入实例。"
  }
}

run "uses_local_ssd_when_ebs_is_unavailable" {
  command = plan
  override_data {
    target          = data.qiniu_compute_region.current
    override_during = plan
    values = {
      region = {
        features = {
          ebs                      = { supported = false }
          public_access_http_proxy = { supported = true }
        }
      }
    }
  }
  assert {
    condition     = qiniu_compute_instance.deepseek_harness.system_disk_type == "local.ssd"
    error_message = "不支持 EBS 的区域必须使用 local.ssd。"
  }
}

run "rejects_region_without_http_proxy" {
  command         = plan
  expect_failures = [data.qiniu_compute_region.current]
  override_data {
    target          = data.qiniu_compute_region.current
    override_during = plan
    values = {
      region = {
        features = {
          ebs                      = { supported = true }
          public_access_http_proxy = { supported = false }
        }
      }
    }
  }
}

run "rejects_invalid_preview_count" {
  command = plan
  variables { preview_count = 5 }
  expect_failures = [var.preview_count]
}

run "accepts_zero_preview_count" {
  command = plan
  variables {
    preview_count = 0
  }
  assert {
    condition = (
      length(qiniu_compute_instance_public_access.preview) == 0 &&
      output.preview_public_authority == null &&
      output.preview_public_url == null &&
      output.preview_public_authorities == [] &&
      output.preview_public_urls == []
    )
    error_message = "preview_count=0 时不应创建 Preview HTTPProxy，兼容单数输出应为 null，列表输出应为空。"
  }
}

run "creates_four_preview_ports" {
  command = plan
  variables {
    preview_count = 4
  }
  assert {
    condition     = [for item in qiniu_compute_instance_public_access.preview : item.internal_port] == [30080, 30081, 30082, 30083]
    error_message = "preview_count=4 时应创建 30080 到 30083。"
  }
}

run "rejects_invalid_code_server_proxy_port" {
  command = plan
  variables { code_server_proxy_port = 65536 }
  expect_failures = [var.code_server_proxy_port]
}

run "rejects_code_server_proxy_port_collision" {
  command = plan
  variables { code_server_proxy_port = 3081 }
  expect_failures = [qiniu_compute_instance_public_access.code_server]
}

run "creates_ssh_port_forward_and_passes_password" {
  command = plan
  variables {
    enable_ssh_port_forward = true
    instance_password       = "Safe-pass-123"
  }
  assert {
    condition = (
      qiniu_compute_instance.deepseek_harness.password == "Safe-pass-123" &&
      length(qiniu_compute_instance_public_access.ssh) == 1 &&
      qiniu_compute_instance_public_access.ssh[0].instance_id == qiniu_compute_instance.deepseek_harness.id &&
      qiniu_compute_instance_public_access.ssh[0].internal_port == 22 &&
      qiniu_compute_instance_public_access.ssh[0].type == "PortForward"
    )
    error_message = "启用 SSH 时必须传入实例密码并创建 22/PortForward。"
  }
}
