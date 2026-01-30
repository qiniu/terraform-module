#!/bin/bash
# ============================================================================
# OpenClaw 初始化脚本（预制镜像版）
# ============================================================================
# 本脚本在基于预制 OpenClaw 镜像的实例首次启动时执行，完成以下任务：
# 1. 创建 openclaw 用户并设置密码
# 2. 生成环境变量和自定义配置
# 3. 启动 OpenClaw Gateway 服务
#
# 前置条件（预制镜像已包含）：
# - Node.js 已安装
# - OpenClaw 已安装
# ============================================================================

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/openclaw-init.log
}

log "Starting OpenClaw initialization (prebuilt image)..."

# ============================================================================
# 1. 创建 openclaw 用户
# ============================================================================

log "Setting up openclaw user..."

if ! id -u openclaw &>/dev/null; then
    useradd -m -s /bin/bash openclaw
    usermod -aG sudo openclaw
    log "openclaw user created."
fi

printf '%s:%s\n' openclaw '${openclaw_password}' | chpasswd
loginctl enable-linger openclaw || true

# ============================================================================
# 2. 生成配置文件
# ============================================================================

log "Generating OpenClaw configuration..."

OPENCLAW_CONFIG_DIR="/home/openclaw/.openclaw"
OPENCLAW_WORKSPACE="/home/openclaw/.openclaw/workspace"
OPENCLAW_CREDENTIALS="/home/openclaw/.openclaw/credentials"
mkdir -p "$OPENCLAW_CONFIG_DIR"
mkdir -p "$OPENCLAW_WORKSPACE"
mkdir -p "$OPENCLAW_CREDENTIALS"

cat > "$OPENCLAW_CONFIG_DIR/openclaw.json" << 'CONFIG_EOF'
{
  "models": {
    "mode": "merge",
    "providers": {
      "qiniu": {
        "baseUrl": "https://api.qnaigc.com",
        "apiKey": "${maas_api_key}",
        "api": "anthropic-messages",
        "models": [
          {
            "id": "${default_model}",
            "name": "${default_model}",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 200000,
            "maxTokens": 128000
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "qiniu/${default_model}"
      },
      "models": {
        "qiniu/${default_model}": {}
      },
      "workspace": "/home/openclaw/.openclaw/workspace"
    }
  },
  "gateway": {
    "port": ${gateway_port},
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "${dashboard_token}"
    }
  }
}
CONFIG_EOF

# ============================================================================
# 3. 设置文件权限
# ============================================================================

log "Setting file permissions..."
chmod 700 "$OPENCLAW_CONFIG_DIR"
chown -R openclaw:openclaw "$OPENCLAW_CONFIG_DIR"
chmod 600 "$OPENCLAW_CONFIG_DIR/openclaw.json"

# ============================================================================
# 4. 启动 OpenClaw Gateway
# ============================================================================

log "Starting OpenClaw gateway..."

OPENCLAW_UID=$(id -u openclaw)
export XDG_RUNTIME_DIR="/run/user/$OPENCLAW_UID"

if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chown openclaw:openclaw "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

runuser -u openclaw -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" bash -c 'openclaw gateway install' || {
    log "WARNING: Failed to install openclaw gateway service."
}

runuser -u openclaw -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" bash -c 'openclaw gateway restart' || {
    log "WARNING: Failed to restart openclaw gateway."
}

# ============================================================================
# 5. 等待服务就绪
# ============================================================================

log "Waiting for OpenClaw gateway to be ready..."

MAX_WAIT=60
WAIT_INTERVAL=5
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if ss -lntp | grep -q ":${gateway_port}"; then
        log "OpenClaw gateway is ready on port ${gateway_port}!"
        break
    fi
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
    log "Waiting for gateway... ($ELAPSED/$MAX_WAIT seconds)"
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    log "WARNING: OpenClaw gateway did not start within $MAX_WAIT seconds."
fi

# ============================================================================
# 6. 完成
# ============================================================================

touch /var/log/openclaw-init-complete
log "OpenClaw initialization completed."
