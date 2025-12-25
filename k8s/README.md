# Kubernetes 集群模块

本模块用于在七牛云上一键部署 Kubernetes 集群。

## 模块说明

### simple - 简单集群

单 Master 节点 + 多 Worker 节点的 K8s 集群配置，适用于开发、测试和小型生产环境。

## 功能特性

- ✅ 自动安装和配置 Kubernetes（支持指定版本）
- ✅ 自动配置容器运行时（containerd）
- ✅ 支持多种 CNI 插件（Flannel、Calico、Weave）
- ✅ 自动生成 bootstrap token
- ✅ Worker 节点自动加入集群
- ✅ 使用置放组确保节点分散部署

## 使用示例

### 基本用法

```hcl
module "k8s_cluster" {
  source = "./k8s/simple"

  # 实例配置
  instance_type            = "ecs.t1.c2m4"      # 2核4G
  instance_system_disk_size = 40                 # 40GB 系统盘

  # K8s 配置
  k8s_version      = "1.28.0"                   # K8s 版本
  worker_count     = 2                          # Worker 节点数量
  pod_network_cidr = "10.244.0.0/16"            # Pod 网络 CIDR
  service_cidr     = "10.96.0.0/12"             # Service 网络 CIDR
  cni_plugin       = "flannel"                  # CNI 插件
}

# 输出集群信息
output "master_ip" {
  value = module.k8s_cluster.k8s_master_ip
}

output "master_endpoint" {
  value = module.k8s_cluster.k8s_master_endpoint
}

output "worker_ips" {
  value = module.k8s_cluster.k8s_worker_ips
}

output "cluster_info" {
  value = module.k8s_cluster.cluster_info
}
```

### 高级配置

```hcl
module "k8s_cluster_prod" {
  source = "./k8s/simple"

  # 使用更高配置的实例
  instance_type            = "ecs.t1.c4m8"      # 4核8G
  instance_system_disk_size = 80                 # 80GB 系统盘

  # 更多 Worker 节点
  worker_count = 5

  # 使用 Calico CNI
  cni_plugin = "calico"
}
```

## 变量说明

### 通用变量（common_variables.tf）

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `instance_type` | string | `ecs.t1.c2m4` | 实例规格 |
| `instance_system_disk_size` | number | `40` | 系统盘大小（GiB），最小 20GB |

### K8s 特定变量（k8s_variables.tf）

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `k8s_version` | string | `1.28.0` | Kubernetes 版本 |
| `worker_count` | number | `2` | Worker 节点数量（1-10） |
| `pod_network_cidr` | string | `10.244.0.0/16` | Pod 网络 CIDR |
| `service_cidr` | string | `10.96.0.0/12` | Service 网络 CIDR |
| `cni_plugin` | string | `flannel` | CNI 插件（flannel/calico/weave） |

## 输出说明

| 输出名 | 说明 |
|--------|------|
| `k8s_master_endpoint` | Kubernetes API Server 地址 |
| `k8s_master_ip` | Master 节点 IP |
| `k8s_master_password` | Master 节点 SSH 密码（敏感） |
| `k8s_worker_ips` | Worker 节点 IP 列表 |
| `k8s_worker_passwords` | Worker 节点 SSH 密码映射（敏感） |
| `k8s_bootstrap_token` | K8s bootstrap token（敏感） |
| `cluster_info` | 集群信息汇总 |
| `kubeconfig_command` | 获取 kubeconfig 的命令 |

## 获取 kubeconfig

集群创建完成后，使用以下方法获取 kubeconfig：

```bash
# 方法 1：使用输出的命令
terraform output -raw kubeconfig_command | bash

# 方法 2：直接 SSH 到 master 节点
ssh root@<master_ip> 'cat /etc/kubernetes/admin.conf' > kubeconfig.yaml

# 方法 3：在 master 节点上查看
ssh root@<master_ip>
cat /etc/kubernetes/admin.conf
```

然后设置 KUBECONFIG 环境变量：

```bash
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
```

## 最小配置要求

- **Master 节点**: 至少 2C4G（ecs.t1.c2m4）
- **Worker 节点**: 至少 2C4G（ecs.t1.c2m4）
- **系统盘**: 至少 20GB（推荐 40GB）

## 网络要求

- Master 和 Worker 节点必须在同一 VPC/子网
- 需要开放以下端口：
  - **Master**: 6443 (API Server), 2379-2380 (etcd), 10250-10252
  - **Worker**: 10250 (kubelet), 30000-32767 (NodePort)

## 注意事项

1. **初始化时间**: 集群初始化大约需要 5-10 分钟
2. **网络连接**: 需要稳定的外网连接下载 K8s 组件和镜像
3. **资源清理**: 删除集群前，请先删除所有 K8s 资源（PV、LoadBalancer 等）
4. **安全性**: 生产环境建议修改默认配置，加强安全防护
5. **证书管理**: K8s 证书默认 1 年有效期，注意续期

## 故障排查

### 查看初始化日志

```bash
# Master 节点
ssh root@<master_ip>
journalctl -u kubelet -f

# Worker 节点
ssh root@<worker_ip>
journalctl -u kubelet -f
```

### 检查集群状态

```bash
# 在 master 节点上
kubectl get nodes
kubectl get pods -A
```

### 重新加入 Worker 节点

如果 Worker 节点加入失败，可以手动重新加入：

```bash
# 在 master 节点上生成 join 命令
kubeadm token create --print-join-command

# 在 worker 节点上执行该命令
```

## 支持的 CNI 插件

- **Flannel**: 简单易用，默认选项，适合大多数场景
- **Calico**: 功能强大，支持网络策略，适合安全要求高的场景
- **Weave**: 轻量级，支持加密，适合跨云部署

## 版本兼容性

- Terraform: >= 0.12.0
- Qiniu Provider: ~> 1.0.0
- Kubernetes: 1.28.x（可配置其他版本）

## 许可证

本模块遵循 MIT 许可证。
