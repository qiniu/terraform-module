# K8s Cluster Configuration

# Create placement group for K8s nodes
resource "qiniu_compute_placement_group" "k8s_pg" {
  name        = format("k8s-cluster-%s", local.cluster_suffix)
  description = format("Placement group for K8s cluster %s", local.cluster_suffix)
  strategy    = "Spread"
}

# Create K8s master node
resource "qiniu_compute_instance" "k8s_master" {
  instance_type      = var.instance_type
  placement_group_id = qiniu_compute_placement_group.k8s_pg.id
  name               = format("k8s-master-%s", local.cluster_suffix)
  description        = format("Master node for K8s cluster %s", local.cluster_suffix)
  image_id           = local.ubuntu_image_id
  system_disk_size   = var.instance_system_disk_size
  password           = random_password.instance_passwords[0].result

  user_data = base64encode(templatefile("${path.module}/init_master.sh", {
    k8s_version      = var.k8s_version
    pod_network_cidr = var.pod_network_cidr
    service_cidr     = var.service_cidr
    k8s_token        = local.k8s_bootstrap_token
    cni_manifest_url = local.cni_manifest_url
    cni_plugin       = var.cni_plugin
  }))
}

# Create K8s worker nodes
resource "qiniu_compute_instance" "k8s_workers" {
  depends_on = [qiniu_compute_instance.k8s_master]

  count              = var.worker_count
  instance_type      = var.instance_type
  placement_group_id = qiniu_compute_placement_group.k8s_pg.id
  name               = format("k8s-worker-%02d-%s", count.index + 1, local.cluster_suffix)
  description        = format("Worker node %02d for K8s cluster %s", count.index + 1, local.cluster_suffix)
  image_id           = local.ubuntu_image_id
  system_disk_size   = var.instance_system_disk_size
  password           = random_password.instance_passwords[count.index + 1].result

  user_data = base64encode(templatefile("${path.module}/init_worker.sh", {
    k8s_version = var.k8s_version
    master_ip   = qiniu_compute_instance.k8s_master.private_ip_addresses[0].ipv4
    k8s_token   = local.k8s_bootstrap_token
  }))
}
