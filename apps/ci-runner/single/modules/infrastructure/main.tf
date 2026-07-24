resource "random_string" "suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

resource "qiniu_compute_key_pair" "deployment" {
  name        = "${local.instance_name}-deploy"
  description = "Temporary deployment key for runnerd - Managed by Terraform"
  mode        = "generate"
}

data "qiniu_compute_images" "ubuntu" {
  type  = "Official"
  state = "Available"
}

data "qiniu_compute_region" "current" {
  lifecycle {
    postcondition {
      condition     = self.region.features.public_access_http_proxy.supported
      error_message = "当前区域不支持 public_access_http_proxy 功能。"
    }
  }
}

locals {
  instance_name = "ci-runner-${random_string.suffix.result}"
  ubuntu_image_ids = [
    for image in data.qiniu_compute_images.ubuntu.items : image.id
    if image.os_distribution == "Ubuntu" && image.os_version == "24.04 LTS"
  ]
  ubuntu_image_id = try(one(local.ubuntu_image_ids), "")
}

resource "qiniu_compute_instance" "ci_runner" {
  name          = local.instance_name
  description   = "CI Runner Instance - Managed by Terraform"
  instance_type = var.instance_type
  image_id      = local.ubuntu_image_id

  system_disk_size = var.system_disk_size
  system_disk_type = data.qiniu_compute_region.current.region.features.ebs.supported ? "cloud.ssd" : "local.ssd"

  internet_max_bandwidth = var.internet_max_bandwidth
  internet_charge_type   = "PeakBandwidth"

  cost_charge_type          = var.cost_charge_type
  cost_period               = var.cost_period
  cost_period_unit          = var.cost_period_unit
  cost_discount_activity_id = var.cost_discount_activity_id
  disable_public_ip      = true
  key_pair_id            = qiniu_compute_key_pair.deployment.id
  password              = var.instance_password

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }

  lifecycle {
    precondition {
      condition     = length(local.ubuntu_image_ids) == 1
      error_message = "当前区域必须恰好存在一个可用的 Ubuntu 24.04 LTS 官方镜像。"
    }
  }
}

resource "qiniu_compute_instance_public_access" "runnerd" {
  instance_id   = qiniu_compute_instance.ci_runner.id
  internal_port = var.runnerd_port
  type          = "HTTPProxy"
}

resource "qiniu_compute_instance_public_access" "ssh" {
  count = var.enable_ssh_port_forward ? 1 : 0

  instance_id   = qiniu_compute_instance.ci_runner.id
  internal_port = 22
  type          = "PortForward"
}
