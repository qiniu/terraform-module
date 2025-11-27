# Generate random suffix for resource names
resource "random_string" "random_suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

locals {
  # Cluster suffix for resource naming
  cluster_suffix = random_string.random_suffix.result

  # CNI manifest URLs
  cni_manifests = {
    flannel = "https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
    calico  = "https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml"
    weave   = "https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml"
  }

  cni_manifest_url = local.cni_manifests[var.cni_plugin]
}

# Generate K8s bootstrap token (format: [a-z0-9]{6}.[a-z0-9]{16})
resource "random_string" "k8s_token_part1" {
  length  = 6
  upper   = false
  lower   = true
  numeric = true
  special = false
}

resource "random_string" "k8s_token_part2" {
  length  = 16
  upper   = false
  lower   = true
  numeric = true
  special = false
}

locals {
  k8s_bootstrap_token = "${random_string.k8s_token_part1.result}.${random_string.k8s_token_part2.result}"
}

# Generate random passwords for instance access
resource "random_password" "instance_passwords" {
  count   = var.worker_count + 1 # master + workers
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}
