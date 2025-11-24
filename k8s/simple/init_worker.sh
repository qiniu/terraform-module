#!/bin/bash
set -e

# K8s Worker Node Initialization Script
# This script installs and configures Kubernetes worker node

echo "=== Starting K8s Worker Node Initialization ==="

# Wait for master to be fully initialized (simple delay)
echo "Waiting for master node to initialize..."
sleep 120

# Disable swap (required for K8s)
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# Load required kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Set required sysctl parameters
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Install containerd
echo "Installing containerd..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Install containerd
apt-get install -y containerd

# Configure containerd
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubelet
echo "Installing Kubernetes components version ${k8s_version}..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm
apt-mark hold kubelet kubeadm

# Wait for master API to be reachable
echo "Checking master node connectivity..."
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if nc -z ${master_ip} 6443 2>/dev/null; then
    echo "Master API server is reachable"
    break
  fi
  echo "Waiting for master API server... (attempt $((RETRY_COUNT+1))/$MAX_RETRIES)"
  sleep 10
  RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: Could not reach master API server after $MAX_RETRIES attempts"
  exit 1
fi

# Additional wait to ensure master is fully ready
sleep 30

# Join the cluster with discovery-token-unsafe-skip-ca-verification
echo "Joining K8s cluster..."
kubeadm join ${master_ip}:6443 \
  --token=${k8s_token} \
  --discovery-token-unsafe-skip-ca-verification \
  --ignore-preflight-errors=NumCPU,Mem

echo "=== K8s Worker Node Initialization Complete ==="
echo "Joined cluster at: ${master_ip}:6443"
