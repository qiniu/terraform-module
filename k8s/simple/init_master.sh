#!/bin/bash
set -e

# K8s Master Node Initialization Script
# This script installs and configures Kubernetes master node

echo "=== Starting K8s Master Node Initialization ==="

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

# Install kubeadm, kubelet, kubectl
echo "Installing Kubernetes components version ${k8s_version}..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Initialize K8s cluster
echo "Initializing K8s cluster..."
kubeadm init \
  --pod-network-cidr=${pod_network_cidr} \
  --service-cidr=${service_cidr} \
  --token=${k8s_token} \
  --token-ttl=0 \
  --ignore-preflight-errors=NumCPU,Mem

# Configure kubectl for root user
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Wait for kube-apiserver to be ready
echo "Waiting for kube-apiserver to be ready..."
while ! kubectl get nodes &> /dev/null; do
  echo "Waiting for API server..."
  sleep 5
done

# Install CNI plugin
echo "Installing CNI plugin: ${cni_plugin}..."
kubectl apply -f ${cni_manifest_url}

# Generate and save join command
echo "Generating worker join command..."
kubeadm token create ${k8s_token} --print-join-command --ttl=0 > /tmp/k8s_join_command.txt

# Get CA cert hash for join command
CA_CERT_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
  openssl rsa -pubin -outform der 2>/dev/null | \
  openssl dgst -sha256 -hex | sed 's/^.* //')

echo "$CA_CERT_HASH" > /tmp/k8s_ca_cert_hash.txt

# Make master node schedulable (for small clusters)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

echo "=== K8s Master Node Initialization Complete ==="
echo "Cluster endpoint: https://$(hostname -I | awk '{print $1}'):6443"
echo "Token: ${k8s_token}"
echo "CA cert hash: sha256:$CA_CERT_HASH"
