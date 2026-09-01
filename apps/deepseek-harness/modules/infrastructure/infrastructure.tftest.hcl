mock_provider "qiniu" {
  mock_data "qiniu_compute_images" {
    defaults = {
      items = [{
        id              = "ubuntu-2404"
        os_distribution = "Ubuntu"
        os_version      = "24.04 LTS"
      }]
    }
  }

  mock_data "qiniu_compute_region" {
    defaults = {
      region = {
        features = {
          public_access_http_proxy = { supported = true }
          ebs                      = { supported = true }
        }
      }
    }
  }
}

mock_provider "random" {}

variables {
  preview_count           = 0
  enable_code_server      = false
  enable_filebrowser      = false
  instance_type           = "ecs.t1s.c2m4"
  system_disk_size        = 40
  internet_max_bandwidth  = 100
  enable_ssh_port_forward = false
  cost_charge_type        = "PostPaid"
  instance_password       = null
}

run "omits_instance_password_when_null" {
  command = plan

  assert {
    condition     = qiniu_compute_instance.deepseek_harness.password == null
    error_message = "instance_password 为 null 时，云实例密码必须为 null。"
  }
}
