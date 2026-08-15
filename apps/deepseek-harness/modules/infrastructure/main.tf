resource "random_string" "suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

locals {
  instance_name = "deepseek-harness-${random_string.suffix.result}"
  preview_ports = [30080, 30081, 30082, 30083]
}

resource "qiniu_compute_key_pair" "deployment" {
  name        = "${local.instance_name}-deploy"
  description = "Temporary deployment key for DeepSeek Harness - Managed by Terraform"
  mode        = "generate"
}

data "qiniu_compute_images" "ubuntu" {
  type  = "Official"
  state = "Available"

  lifecycle {
    postcondition {
      condition = !var.image_validation_enabled || length([
        for image in self.items : image.id
        if image.os_distribution == "Ubuntu" && image.os_version == "24.04 LTS"
      ]) == 1
      error_message = "当前区域必须恰好存在一个可用的 Ubuntu 24.04 LTS 官方镜像。"
    }
  }
}

locals {
  ubuntu_image_ids = [
    for image in data.qiniu_compute_images.ubuntu.items : image.id
    if image.os_distribution == "Ubuntu" && image.os_version == "24.04 LTS"
  ]
}

data "qiniu_compute_region" "current" {
  lifecycle {
    postcondition {
      condition     = self.region.features.public_access_http_proxy.supported
      error_message = "当前区域不支持 public_access_http_proxy 功能。"
    }
  }
}

resource "qiniu_compute_instance" "deepseek_harness" {
  name          = local.instance_name
  description   = "DeepSeek Harness Instance - Managed by Terraform"
  instance_type = var.instance_type
  image_id      = var.image_validation_enabled ? try(one(local.ubuntu_image_ids), "") : "ubuntu-2404"

  system_disk_size = var.system_disk_size
  system_disk_type = data.qiniu_compute_region.current.region.features.ebs.supported ? "cloud.ssd" : "local.ssd"

  internet_max_bandwidth = var.internet_max_bandwidth
  internet_charge_type   = "PeakBandwidth"
  cost_charge_type       = var.cost_charge_type
  cost_period            = var.cost_charge_type == "PrePaid" ? var.cost_period : null
  cost_period_unit       = var.cost_charge_type == "PrePaid" ? var.cost_period_unit : null
  disable_public_ip      = true
  key_pair_id            = qiniu_compute_key_pair.deployment.id
  password               = var.instance_password

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }

}

resource "qiniu_compute_instance_public_access" "web" {
  instance_id   = qiniu_compute_instance.deepseek_harness.id
  internal_port = var.nginx_proxy_port
  type          = "HTTPProxy"
}

resource "qiniu_compute_instance_public_access" "preview" {
  count = var.preview_count

  instance_id   = qiniu_compute_instance.deepseek_harness.id
  internal_port = local.preview_ports[count.index]
  type          = "HTTPProxy"
}

resource "qiniu_compute_instance_public_access" "code_server" {
  instance_id   = qiniu_compute_instance.deepseek_harness.id
  internal_port = var.code_server_proxy_port
  type          = "HTTPProxy"

  lifecycle {
    precondition {
      condition = (
        var.code_server_proxy_port != var.nginx_proxy_port &&
        !contains(local.preview_ports, var.code_server_proxy_port)
      )
      error_message = "code_server_proxy_port 不得与 nginx_proxy_port 或 Preview 端口重复。"
    }
  }
}

resource "qiniu_compute_instance_public_access" "ssh" {
  count = var.enable_ssh_port_forward ? 1 : 0

  instance_id   = qiniu_compute_instance.deepseek_harness.id
  internal_port = 22
  type          = "PortForward"
}
