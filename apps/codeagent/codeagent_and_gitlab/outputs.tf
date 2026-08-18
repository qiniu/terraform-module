# GitLab instance outputs
output "gitlab_instance_id" {
  value       = qiniu_compute_instance.gitlab_instance.id
  description = "GitLab instance ID"
}

output "gitlab_public_ip" {
  value       = qiniu_compute_instance.gitlab_instance.public_ip_addresses[0].ipv4
  description = "GitLab instance public IP address"
}

output "gitlab_private_ip" {
  value       = qiniu_compute_instance.gitlab_instance.private_ip_addresses[0].ipv4
  description = "GitLab instance private IP address"
}

output "gitlab_instance_password" {
  value       = random_password.gitlab_instance_password.result
  description = "Root password for SSH access to GitLab instance"
  sensitive   = true
}

output "gitlab_url" {
  value       = format("http://%s", qiniu_compute_instance.gitlab_instance.public_ip_addresses[0].ipv4)
  description = "GitLab access URL"
}

# CodeAgent instance outputs
output "codeagent_instance_id" {
  value       = qiniu_compute_instance.codeagent_instance.id
  description = "CodeAgent instance ID"
}

output "codeagent_public_ip" {
  value       = qiniu_compute_instance.codeagent_instance.public_ip_addresses[0].ipv4
  description = "CodeAgent instance public IP address"
}

output "codeagent_private_ip" {
  value       = qiniu_compute_instance.codeagent_instance.private_ip_addresses[0].ipv4
  description = "CodeAgent instance private IP address"
}

output "codeagent_instance_password" {
  value       = random_password.codeagent_instance_password.result
  description = "Root password for SSH access to CodeAgent instance"
  sensitive   = true
}

# Combined information
output "deployment_summary" {
  value = {
    gitlab = {
      instance_id = qiniu_compute_instance.gitlab_instance.id
      public_ip   = qiniu_compute_instance.gitlab_instance.public_ip_addresses[0].ipv4
      url         = format("http://%s", qiniu_compute_instance.gitlab_instance.public_ip_addresses[0].ipv4)
    }
    codeagent = {
      instance_id = qiniu_compute_instance.codeagent_instance.id
      public_ip   = qiniu_compute_instance.codeagent_instance.public_ip_addresses[0].ipv4
    }
  }
  description = "Complete deployment summary"
}
