# CodeAgent instance information outputs
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
  description = "Root password for SSH access to CodeAgent instance (randomly generated)"
  sensitive   = true
}
