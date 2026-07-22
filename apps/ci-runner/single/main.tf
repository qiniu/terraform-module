resource "random_string" "suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

resource "tls_private_key" "deployment" {
  algorithm = "ED25519"
}

resource "qiniu_compute_key_pair" "deployment" {
  name        = "${local.instance_name}-deploy"
  description = "Temporary deployment key for runnerd - Managed by Terraform"
  mode        = "import"
  public_key  = chomp(tls_private_key.deployment.public_key_openssh)
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
  disable_public_ip      = true
  key_pair_id            = qiniu_compute_key_pair.deployment.id

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }

  lifecycle {
    ignore_changes = [
      image_id,
      instance_type,
      system_disk_type,
      system_disk_size,
    ]

    precondition {
      condition     = length(local.ubuntu_image_ids) == 1
      error_message = "当前区域必须恰好存在一个可用的 Ubuntu 24.04 LTS 官方镜像。"
    }
  }
}

resource "qiniu_compute_instance_public_access" "endpoint" {
  instance_id   = qiniu_compute_instance.ci_runner.id
  internal_port = 25500
  type          = "HTTPProxy"
}

resource "qiniu_compute_instance_public_access" "ssh" {
  count = var.enable_ssh_port_forward ? 1 : 0

  instance_id   = qiniu_compute_instance.ci_runner.id
  internal_port = 22
  type          = "PortForward"
}

locals {
  public_url = "https://${qiniu_compute_instance_public_access.endpoint.endpoint}"
}

module "config" {
  source = "./config-generator"

  public_url                 = local.public_url
  github_app_id              = var.github_app_id
  github_app_slug            = var.github_app_slug
  github_oauth_client_id     = var.github_oauth_client_id
  github_oauth_client_secret = var.github_oauth_client_secret
}

module "runnerd" {
  source = "./runnerd-installer"

  runnerd_version                = var.runnerd_version
  runnerd_install_revision       = var.runnerd_install_revision
  config_content                 = module.config.config_content
  github_app_private_key_base64  = var.github_app_private_key_base64
  bootstrap_admin_github_user_id = var.bootstrap_admin_github_user_id
}

resource "qiniu_compute_instance_exec" "install_runnerd" {
  instance_id = qiniu_compute_instance.ci_runner.id
  user        = "root"
  port        = "22"
  private_key = tls_private_key.deployment.private_key_openssh

  shell   = "bash"
  command = module.runnerd.install_command

  triggers = {
    install_checksum = module.runnerd.install_checksum
  }

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }
}

resource "qiniu_compute_instance_exec" "verify_runnerd" {
  depends_on = [qiniu_compute_instance_exec.install_runnerd]

  instance_id = qiniu_compute_instance.ci_runner.id
  user        = "root"
  port        = "22"
  private_key = tls_private_key.deployment.private_key_openssh

  shell = "bash"
  command = templatefile("${path.module}/templates/verify.sh.tftpl", {
    bootstrap_admin_github_user_id = var.bootstrap_admin_github_user_id
  })

  triggers = {
    install_checksum = module.runnerd.install_checksum
  }

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "10m"
    delete = "5m"
  }
}
