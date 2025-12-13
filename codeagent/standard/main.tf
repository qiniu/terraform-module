# Generate random password for CodeAgent instance
resource "random_password" "codeagent_instance_password" {
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}

# Create CodeAgent ECS instance
resource "qiniu_compute_instance" "codeagent_instance" {
  instance_type          = var.instance_type
  name                   = format("codeagent-standard-%s", local.instance_suffix)
  description            = format("CodeAgent Standard instance %s", local.instance_suffix)
  image_id               = var.image_id
  system_disk_size       = var.instance_system_disk_size
  internet_max_bandwidth = var.internet_max_bandwidth
  password               = random_password.codeagent_instance_password.result

  # Use user_data for configuration via cloud-init
  # Script configures API Key and GitLab configuration
  user_data = base64encode(templatefile("${path.module}/codeagent_setup.sh", {
    model_api_key        = var.model_api_key
    gitlab_base_url      = var.gitlab_base_url
    gitlab_webhook_secret = var.gitlab_webhook_secret
    gitlab_token         = var.gitlab_token
  }))

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }
}

# Generate instance suffix for unique naming
resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

locals {
  instance_suffix = random_string.resource_suffix.result
}
