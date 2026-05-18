module "k3s-server" {
  source = "./modules/k3s-node"
  providers = {
    qiniu = qiniu
  }
}

output "k3s_token" {
  value = nonsensitive(module.k3s-server.k3s_token)
}

# provider "kubernetes" {
#   host                   = module.k3s-server.k8s_api_server
#   cluster_ca_certificate = module.k3s-server.k8s_cluster_ca_certificate
#   client_key             = module.k3s-server.k8s_client_key
#   client_certificate     = module.k3s-server.k8s_client_certificate
# }

# resource "kubernetes_namespace" "example" {
#   metadata {
#     name = "my-first-namespace"
#   }
# }
