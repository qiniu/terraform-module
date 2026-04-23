output "k8s_master_endpoint" {
  value       = format("https://%s:6443", qiniu_compute_instance.k8s_master.private_ip_addresses[0].ipv4)
  description = "Kubernetes API Server endpoint"
}

output "k8s_master_ip" {
  value       = qiniu_compute_instance.k8s_master.private_ip_addresses[0].ipv4
  description = "K8s master node IP address"
}

output "k8s_master_password" {
  value       = random_password.instance_passwords[0].result
  description = "K8s master node SSH password"
  sensitive   = true
}

output "k8s_worker_ips" {
  value = [
    for instance in qiniu_compute_instance.k8s_workers :
    instance.private_ip_addresses[0].ipv4
  ]
  description = "List of K8s worker node IP addresses"
}

output "k8s_worker_passwords" {
  value = {
    for idx, instance in qiniu_compute_instance.k8s_workers :
    instance.name => random_password.instance_passwords[idx + 1].result
  }
  description = "Map of worker node names to SSH passwords"
  sensitive   = true
}

output "k8s_bootstrap_token" {
  value       = local.k8s_bootstrap_token
  description = "K8s bootstrap token for joining nodes"
  sensitive   = true
}

output "cluster_info" {
  value = {
    cluster_name     = format("k8s-cluster-%s", local.cluster_suffix)
    k8s_version      = var.k8s_version
    master_endpoint  = format("https://%s:6443", qiniu_compute_instance.k8s_master.private_ip_addresses[0].ipv4)
    pod_network_cidr = var.pod_network_cidr
    service_cidr     = var.service_cidr
    cni_plugin       = var.cni_plugin
    worker_count     = var.worker_count
  }
  description = "K8s cluster information"
}

output "kubeconfig_command" {
  value       = format("ssh root@%s 'cat /etc/kubernetes/admin.conf' > kubeconfig.yaml", qiniu_compute_instance.k8s_master.private_ip_addresses[0].ipv4)
  description = "Command to retrieve kubeconfig file from master node"
}
