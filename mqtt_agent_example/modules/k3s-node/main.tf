data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

locals {
  ubuntu_image_id = one([
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ]).id

  mqtt_config = {
    broker_host  = "broker.emqx.io"
    broker_port  = 8883
    topic_prefix = "mqtt-qn-instance"
  }
}

resource "random_password" "instance_password" {
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}

# 构造 agent 与 terraform 之间的通信辅助配置，用于设备唯一识别的关联与端到端加密
module "mqtt_agent_helper" {
  source = "git::https://github.com/zhangzqs/homelab-terraform.git//modules/utils/mqtt_agent/mqtt-agent-helper?ref=master"
}

# 构造 agent 的安装脚本
module "mqtt_agent_runtime" {
  source = "git::https://github.com/zhangzqs/homelab-terraform.git//modules/utils/mqtt_agent/mqtt-agent-runtime?ref=master"

  mqtt_config   = local.mqtt_config
  crypto_bundle = module.mqtt_agent_helper.crypto_bundle
}

# 创建机器实例
resource "qiniu_compute_instance" "node" {
  instance_type          = "ecs.t1.c1m2"
  image_id               = local.ubuntu_image_id
  system_disk_size       = 20
  password               = random_password.instance_password.result
  user_data              = module.mqtt_agent_runtime.rendered
  internet_max_bandwidth = 10
  internet_charge_type   = "Bandwidth"
}

# 等待机器上线接收心跳包
module "mqtt_agent_heartbeat" {
  source = "git::https://github.com/zhangzqs/homelab-terraform.git//modules/utils/mqtt_agent/mqtt-agent-heartbeat?ref=master"

  mqtt_config   = local.mqtt_config
  crypto_bundle = module.mqtt_agent_helper.crypto_bundle
  instance_id   = qiniu_compute_instance.node.id
  timeout       = 600 # 超时控制
}

# 远程执行命令
module "mqtt_agent_exec" {
  source = "git::https://github.com/zhangzqs/homelab-terraform.git//modules/utils/mqtt_agent/mqtt-agent-exec?ref=master"

  mqtt_config   = local.mqtt_config
  crypto_bundle = module.mqtt_agent_helper.crypto_bundle
  timeout       = 600
  command       = <<-EOT
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -
EOT

  # 必须等待心跳模块完成，确认 Agent 已经就绪，才能执行命令
  depends_on = [module.mqtt_agent_heartbeat]
}

# 获取k3s token
module "mqtt_agent_exec_get_token" {
  source = "git::https://github.com/zhangzqs/homelab-terraform.git//modules/utils/mqtt_agent/mqtt-agent-exec?ref=master"

  mqtt_config   = local.mqtt_config
  crypto_bundle = module.mqtt_agent_helper.crypto_bundle
  timeout       = 600

  command = "cat /var/lib/rancher/k3s/server/node-token"

  depends_on = [module.mqtt_agent_exec]
}

# 获取kubectl 配置文件
module "mqtt_agent_exec_get_kubeconfig" {
  source = "git::https://github.com/zhangzqs/homelab-terraform.git//modules/utils/mqtt_agent/mqtt-agent-exec?ref=master"

  mqtt_config   = local.mqtt_config
  crypto_bundle = module.mqtt_agent_helper.crypto_bundle
  timeout       = 600

  command    = "cat /etc/rancher/k3s/k3s.yaml"
  depends_on = [module.mqtt_agent_exec]
}

output "k3s_token" {
  value = trimspace(module.mqtt_agent_exec_get_token.output)
}


output "k8s_api_server" {
  value       = "https://${qiniu_compute_instance.node.public_ip_addresses[0].ipv4}:6443"
  description = "K3s API 服务器地址"
}

locals {
  parsed_kubeconfig = yamldecode(replace(module.mqtt_agent_exec_get_kubeconfig.output, "127.0.0.1", qiniu_compute_instance.node.public_ip_addresses[0].ipv4))
}

output "k8s_cluster_ca_certificate" {
  value       = base64decode(local.parsed_kubeconfig.clusters[0].cluster["certificate-authority-data"])
  description = "Kubernetes 集群 CA 证书内容, clusters.cluster.certificate-authority-data 字段的值"
}

output "k8s_client_key" {
  value       = base64decode(local.parsed_kubeconfig.users[0].user["client-key-data"])
  description = "Kubernetes 客户端密钥内容, users.user.client-certificate-data 字段的值"
}

output "k8s_client_certificate" {
  value       = base64decode(local.parsed_kubeconfig.users[0].user["client-certificate-data"])
  description = "Kubernetes 客户端证书内容, users.user.client-key-data 字段的值"
}
