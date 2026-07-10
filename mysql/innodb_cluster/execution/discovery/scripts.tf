locals {
  node_private_ip_command = templatefile("${path.module}/templates/discover_private_ip.sh", {})
}
