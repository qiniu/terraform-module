#!/bin/bash
# ============================================================================
# Moltbot 初始化脚本（预制镜像版）
# ============================================================================
# 本脚本在基于预制 Moltbot 镜像的实例首次启动时执行，完成以下任务：
# 1. 创建 clawd 用户并设置密码
# 2. 生成环境变量和自定义配置
# 3. 启动 Moltbot Gateway 服务
#
# 前置条件（预制镜像已包含）：
# - Node.js 已安装
# - Moltbot 已安装
# ============================================================================

set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/moltbot-init.log
}

log "Starting Moltbot initialization (prebuilt image)..."

# ============================================================================
# 1. 创建 clawd 用户
# ============================================================================

log "Setting up clawd user..."

if ! id -u clawd &>/dev/null; then
    useradd -m -s /bin/bash clawd
    log "clawd user created."
fi

printf '%s:%s\n' clawd '${clawd_password}' | chpasswd
loginctl enable-linger clawd || true

# ============================================================================
# 2. 生成配置文件
# ============================================================================

log "Generating Moltbot configuration..."

MOLTBOT_CONFIG_DIR="/home/clawd/.clawdbot"
MOLTBOT_WORKSPACE="/home/clawd/clawd"
mkdir -p "$MOLTBOT_CONFIG_DIR"
mkdir -p "$MOLTBOT_WORKSPACE"

cat > "$MOLTBOT_CONFIG_DIR/clawdbot.json" << 'CONFIG_EOF'
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
            "id": "minimax/minimax-m2.1",
            "name": "MiniMax-M2.1",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 200000,
            "maxTokens": 128000
          },
          {
            "id": "deepseek/deepseek-chat",
            "name": "DeepSeek Chat",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 64000,
            "maxTokens": 8192
          },
          {
            "id": "qwen/qwen-max",
            "name": "Qwen Max",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 32000,
            "maxTokens": 8192
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
        "qiniu/minimax/minimax-m2.1": {},
        "qiniu/deepseek/deepseek-chat": {},
        "qiniu/qwen/qwen-max": {}
      },
      "workspace": "/home/clawd/clawd"
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
chown -R clawd:clawd "$MOLTBOT_CONFIG_DIR"
chown -R clawd:clawd "$MOLTBOT_WORKSPACE"
chmod 600 "$MOLTBOT_CONFIG_DIR/clawdbot.json"

# ============================================================================
# 4. 启动 Moltbot Gateway
# ============================================================================

log "Starting Moltbot gateway..."

CLAWD_UID=$(id -u clawd)
export XDG_RUNTIME_DIR="/run/user/$CLAWD_UID"

if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chown clawd:clawd "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

runuser -u clawd -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" bash -c 'clawdbot gateway install' || {
    log "WARNING: Failed to install clawdbot gateway service."
}

runuser -u clawd -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" bash -c 'clawdbot gateway restart' || {
    log "WARNING: Failed to restart clawdbot gateway."
}

# ============================================================================
# 5. 等待服务就绪
# ============================================================================

log "Waiting for Moltbot gateway to be ready..."

MAX_WAIT=60
WAIT_INTERVAL=5
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if ss -lntp | grep -q ":${gateway_port}"; then
        log "Moltbot gateway is ready on port ${gateway_port}!"
        break
    fi
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
    log "Waiting for gateway... ($ELAPSED/$MAX_WAIT seconds)"
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    log "WARNING: Moltbot gateway did not start within $MAX_WAIT seconds."
fi

# ============================================================================
# 6. 完成
# ============================================================================

touch /var/log/moltbot-init-complete
log "Moltbot initialization completed."
