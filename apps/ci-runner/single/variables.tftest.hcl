mock_provider "qiniu" {}

override_module {
  target = module.infrastructure

  outputs = {
    instance_id            = "test-instance"
    deployment_private_key = "test-private-key"
    public_url             = "https://runner.example.test"
    ssh_endpoints          = []
  }
}

override_module {
  target = module.github_utils

  outputs = {
    user_id = 583231
    login   = "octocat"
  }
}

variables {
  github_app_id                  = 123456
  github_app_slug                = "runner-example"
  github_oauth_client_id         = "Iv1.example"
  github_oauth_client_secret     = "oauth-secret"
  github_app_private_key_base64  = "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCnRlc3Qta2V5Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K"
  bootstrap_admin_github_login = "octocat"
}

run "rejects_invalid_instance_type_format" {
  command = plan

  variables {
    instance_type = "c1m2"
  }

  expect_failures = [var.instance_type]
}

run "rejects_system_disk_smaller_than_20_gib" {
  command = plan

  variables {
    system_disk_size = 10
  }

  expect_failures = [var.system_disk_size]
}

run "rejects_system_disk_larger_than_500_gib" {
  command = plan

  variables {
    system_disk_size = 510
  }

  expect_failures = [var.system_disk_size]
}

run "rejects_system_disk_not_multiple_of_10" {
  command = plan

  variables {
    system_disk_size = 55
  }

  expect_failures = [var.system_disk_size]
}

run "rejects_unsupported_peak_bandwidth" {
  command = plan

  variables {
    internet_max_bandwidth = 150
  }

  expect_failures = [var.internet_max_bandwidth]
}

run "rejects_invalid_cost_charge_type" {
  command = plan

  variables {
    cost_charge_type = "Invalid"
  }

  expect_failures = [var.cost_charge_type]
}

run "accepts_prepaid_with_month_period" {
  command = plan

  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 1
  }
}

run "accepts_postpaid_default" {
  command = plan

  variables {
    cost_charge_type = "PostPaid"
  }
}
