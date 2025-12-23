# Generate random passwords
resource "random_password" "gitlab_instance_password" {
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}

resource "random_password" "codeagent_instance_password" {
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}

# Step 1: Create GitLab instance first
resource "qiniu_compute_instance" "gitlab_instance" {
  instance_type          = var.gitlab_instance_type
  name                   = format("gitlab-%s", local.instance_suffix)
  description            = format("GitLab instance %s", local.instance_suffix)
  image_id               = var.gitlab_image_id
  system_disk_size       = var.gitlab_system_disk_size
  internet_max_bandwidth = var.gitlab_internet_max_bandwidth
  password               = random_password.gitlab_instance_password.result

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }
}

# Use null_resource to configure GitLab with actual public IP via SSH
resource "null_resource" "configure_gitlab" {
  depends_on = [qiniu_compute_instance.gitlab_instance]

  connection {
    type     = "ssh"
    user     = "root"
    password = random_password.gitlab_instance_password.result
    host     = qiniu_compute_instance.gitlab_instance.public_ip_addresses[0].ipv4
    timeout  = "10m"
    agent    = false
    host_key = null
  }

  # Upload the setup script
  provisioner "file" {
    content = templatefile("${path.module}/gitlab_setup.sh", {
      public_ip = qiniu_compute_instance.gitlab_instance.public_ip_addresses[0].ipv4
    })
    destination = "/tmp/gitlab_setup.sh"
  }

  # Execute the script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/gitlab_setup.sh",
      "/tmp/gitlab_setup.sh"
    ]
  }
}

# Step 2: Create CodeAgent instance after GitLab is configured
resource "qiniu_compute_instance" "codeagent_instance" {
  depends_on = [null_resource.configure_gitlab]

  instance_type          = var.codeagent_instance_type
  name                   = format("codeagent-%s", local.instance_suffix)
  description            = format("CodeAgent instance %s", local.instance_suffix)
  image_id               = var.codeagent_image_id
  system_disk_size       = var.codeagent_system_disk_size
  internet_max_bandwidth = var.codeagent_internet_max_bandwidth
  password               = random_password.codeagent_instance_password.result

  # Configure CodeAgent with GitLab URL
  user_data = base64encode(templatefile("${path.module}/codeagent_setup.sh", {
    model_api_key         = var.model_api_key
    gitlab_base_url       = format("http://%s", qiniu_compute_instance.gitlab_instance.public_ip_addresses[0].ipv4)
    gitlab_webhook_secret = local.gitlab_webhook_secret
    gitlab_token          = local.gitlab_token
  }))

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }
}

# Step 3: Configure GitLab webhook after CodeAgent is ready
resource "null_resource" "configure_gitlab_webhook" {
  depends_on = [qiniu_compute_instance.codeagent_instance]

  provisioner "local-exec" {
    command = templatefile("${path.module}/configure_webhook.sh", {
      gitlab_url      = format("http://%s", qiniu_compute_instance.gitlab_instance.public_ip_addresses[0].ipv4)
      codeagent_ip    = qiniu_compute_instance.codeagent_instance.public_ip_addresses[0].ipv4
      gitlab_token    = local.gitlab_token
      webhook_secret  = local.gitlab_webhook_secret
      project_id      = "1"
    })
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

locals {
  instance_suffix = random_string.resource_suffix.result

   # Hardcoded GitLab configuration for CodeAgent
  gitlab_webhook_secret = "7Xk9pL2qNvR" #gitlab 内置测试项目配置的webhook_secret密钥，仅做测试用，请勿用于真实环境
  gitlab_token          = "glpat-vkEFt2B0j-bFbEJaUmfWcm86MQp1OjIH.01.0w1yp1q9m" #gitlab 内置配置的codeagent的token ，仅做测试用，请勿用于真实环境
}