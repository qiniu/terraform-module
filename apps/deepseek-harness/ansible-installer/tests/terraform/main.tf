terraform {
  required_version = ">= 1.6"

  required_providers {
    qiniu = {
      source  = "qiniu/qiniu"
      version = "= 1.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.8.0"
    }
  }
}

provider "qiniu" {}

module "infrastructure" {
  source = "../../../modules/infrastructure"

  nginx_proxy_port        = 3081
  preview_count           = 1
  code_server_proxy_port  = 3087
  instance_type           = "ecs.t1s.c2m4"
  system_disk_size        = 40
  internet_max_bandwidth  = 50
  enable_ssh_port_forward = true
  cost_charge_type        = "PostPaid"
}

output "ssh_endpoint" {
  value = module.infrastructure.ssh_endpoints[0]
}

output "deployment_private_key" {
  value     = module.infrastructure.deployment_private_key
  sensitive = true
}

output "public_authority" {
  value = module.infrastructure.public_authority
}

output "preview_public_authorities" {
  value = module.infrastructure.preview_public_authorities
}

output "code_server_public_authority" {
  value = module.infrastructure.code_server_public_authority
}
