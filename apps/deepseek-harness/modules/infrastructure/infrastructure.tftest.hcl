mock_provider "qiniu" {
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
  image_id                  = "ubuntu-2404"
  preview_count             = 0
  enable_code_server        = false
  enable_filebrowser        = false
  instance_type             = "ecs.t1s.c2m4"
  system_disk_type          = "auto"
  system_disk_size          = 40
  internet_max_bandwidth    = 100
  internet_public_ip_type   = null
  enable_ssh_port_forward   = false
  cost_charge_type          = "PostPaid"
  cost_discount_activity_id = null
  instance_password         = null
}

run "omits_instance_password_when_null" {
  command = plan

  assert {
    condition     = qiniu_compute_instance.deepseek_harness.password == null
    error_message = "instance_password 为 null 时，云实例密码必须为 null。"
  }
}

run "resolves_auto_system_disk_type" {
  command = plan

  assert {
    condition     = qiniu_compute_instance.deepseek_harness.system_disk_type == "cloud.ssd"
    error_message = "auto 必须在支持 EBS 的地域选择 cloud.ssd。"
  }
}

run "forwards_discount_activity_configuration" {
  command = plan

  variables {
    instance_type             = "69c5fce89e43138e3e10sq1a"
    system_disk_type          = "local.ssd"
    cost_charge_type          = "PrePaid"
    cost_period               = 1
    cost_discount_activity_id = "2026_user_acquisition"
    internet_public_ip_type   = "Shared"
  }

  assert {
    condition = (
      qiniu_compute_instance.deepseek_harness.cost_discount_activity_id == "2026_user_acquisition" &&
      qiniu_compute_instance.deepseek_harness.internet_public_ip_type == "Shared" &&
      qiniu_compute_instance.deepseek_harness.system_disk_type == "local.ssd"
    )
    error_message = "活动 ID、共享公网 IP 类型和本地系统盘必须传给云实例。"
  }
}
