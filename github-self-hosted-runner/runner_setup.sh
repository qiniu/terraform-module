#!/bin/bash
set -e

# ==========================================
# GitHub Actions Self-hosted Runner Setup
# 参考文档: how-to-setup-self-github-action-runner.md
# ==========================================

# Terraform 模板变量（单引号避免特殊字符问题）
GITHUB_TOKEN='${github_token}'
GITHUB_REPO_URL='${github_repo_url}'
RUNNER_NAME='${runner_name}'
RUNNER_LABELS='${runner_labels}'
RUNNER_USERNAME='${runner_username}'
ENABLE_DOCKER='${enable_docker}'
ADDITIONAL_PACKAGES='${additional_packages}'

echo "=========================================="
echo "Starting GitHub Runner Setup"
echo "=========================================="

# ==========================================
# Step 1: 系统更新和基础依赖安装
# ==========================================

echo "[1/7] Updating system and installing dependencies..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    jq \
    git \
    build-essential \
    libssl-dev \
    ca-certificates \
    gnupg \
    lsb-release

# 安装用户指定的额外软件包
if [[ -n "$ADDITIONAL_PACKAGES" ]]; then
    echo "Installing additional packages: $ADDITIONAL_PACKAGES"
    DEBIAN_FRONTEND=noninteractive apt-get install -y $ADDITIONAL_PACKAGES
fi

# ==========================================
# Step 2: 创建 Runner 专用账户
# 参考文档第3节：为什么不能用 root
# ==========================================

echo "[2/7] Creating runner user account..."

# 检查用户是否已存在
if id "$RUNNER_USERNAME" &>/dev/null; then
    echo "User $RUNNER_USERNAME already exists"
else
    # 创建用户并添加到 sudo 组
    useradd -m -s /bin/bash "$RUNNER_USERNAME"
    usermod -aG sudo "$RUNNER_USERNAME"

    # 配置无密码 sudo（仅针对 Docker 和 systemctl）
    echo "$RUNNER_USERNAME ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/systemctl" >> /etc/sudoers.d/runner-nopasswd
    chmod 0440 /etc/sudoers.d/runner-nopasswd
fi

# ==========================================
# Step 3: 安装 Docker (可选)
# ==========================================

if [[ "$ENABLE_DOCKER" == "true" ]]; then
    echo "[3/7] Installing Docker..."

    # 添加 Docker 官方 GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # 添加 Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 安装 Docker
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # 添加 runner 用户到 docker 组
    usermod -aG docker "$RUNNER_USERNAME"

    # 启动 Docker
    systemctl enable docker
    systemctl start docker
else
    echo "[3/7] Skipping Docker installation"
fi

# ==========================================
# Step 4: 下载 GitHub Actions Runner
# 参考文档 Step 2
# ==========================================

echo "[4/7] Downloading GitHub Actions Runner..."

# 切换到 runner 用户的 home 目录
RUNNER_HOME="/home/$RUNNER_USERNAME"
RUNNER_DIR="$RUNNER_HOME/actions-runner"

# 创建 runner 目录
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# 获取最新版本的 runner
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')

# 下载 runner
curl -o actions-runner-linux-x64-$RUNNER_VERSION.tar.gz \
    -L "https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz"

# 解压
tar xzf ./actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
rm -f ./actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

# 修改所有者为 runner 用户
chown -R "$RUNNER_USERNAME:$RUNNER_USERNAME" "$RUNNER_DIR"

# ==========================================
# Step 5: 获取 Registration Token
# 参考文档第6节：Token 机制
# ==========================================

echo "[5/7] Obtaining registration token from GitHub..."

# 从 repo URL 中提取 owner 和 repo
REPO_PATH=$(echo "$GITHUB_REPO_URL" | sed 's|https://github.com/||')
OWNER=$(echo "$REPO_PATH" | cut -d'/' -f1)
REPO=$(echo "$REPO_PATH" | cut -d'/' -f2)

# 通过 API 获取 registration token
REG_TOKEN=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$OWNER/$REPO/actions/runners/registration-token" \
    | jq -r '.token')

if [[ -z "$REG_TOKEN" || "$REG_TOKEN" == "null" ]]; then
    echo "Error: Failed to obtain registration token. Check if:"
    echo "1. GitHub token has correct permissions (admin:org or repo)"
    echo "2. Repository URL is correct"
    exit 1
fi

echo "Registration token obtained successfully"

# ==========================================
# Step 6: 配置 Runner
# 参考文档 Step 3
# ==========================================

echo "[6/7] Configuring GitHub Actions Runner..."

# 切换到 runner 用户执行配置
su - "$RUNNER_USERNAME" -c "cd $RUNNER_DIR && ./config.sh \
    --url $GITHUB_REPO_URL \
    --token $REG_TOKEN \
    --name $RUNNER_NAME \
    --labels $RUNNER_LABELS \
    --work _work \
    --unattended \
    --replace"

# ==========================================
# Step 7: 安装为系统服务并启动
# 参考文档第7节：svc.sh 详解
# ==========================================

echo "[7/7] Installing runner as a service..."

# 安装服务（需要 root 权限）
cd "$RUNNER_DIR"
./svc.sh install "$RUNNER_USERNAME"

# 启动服务
./svc.sh start

# 查看状态
./svc.sh status

echo "=========================================="
echo "GitHub Runner Setup Completed!"
echo "=========================================="
echo "Runner Name: $RUNNER_NAME"
echo "Runner Labels: $RUNNER_LABELS"
echo "Repository: $GITHUB_REPO_URL"
echo ""
echo "Check runner status:"
echo "  sudo ./svc.sh status"
echo ""
echo "View logs:"
echo "  journalctl -u actions.runner.* -f"
echo "=========================================="
