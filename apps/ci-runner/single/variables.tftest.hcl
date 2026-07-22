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

variables {
  runnerd_version                = "v0.2.3"
  github_app_id                  = 123456
  github_app_slug                = "runner-example"
  github_oauth_client_id         = "Iv1.example"
  github_oauth_client_secret     = "oauth-secret"
  github_app_private_key_base64  = "LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCnRlc3Qta2V5Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K"
  bootstrap_admin_github_user_id = 123456
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
