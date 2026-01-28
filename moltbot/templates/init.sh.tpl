#!/bin/bash
# ============================================================================
# Clawdbot 初始化脚本
# ============================================================================
# 本脚本在实例首次启动时执行，完成以下任务：
# 1. 创建 clawd 用户并配置权限
# 2. 通过官方安装脚本安装 Clawdbot（会自动安装 Node.js）
# 3. 生成 Clawdbot 配置文件
# 4. 启动 Clawdbot Gateway 服务
# ============================================================================

set -euo pipefail

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/clawdbot-init.log
}

log "Starting Clawdbot initialization..."

# ============================================================================
# 1. 创建或更新 clawd 用户
# ============================================================================

log "Setting up clawd user..."

if ! id -u clawd &>/dev/null; then
    log "Creating clawd user..."
    useradd -m -s /bin/bash clawd
    usermod -aG sudo clawd
    log "clawd user created."
fi

# 更新密码
echo "clawd:${clawd_password}" | chpasswd
log "clawd user password updated."

# 允许后台常驻（关掉 SSH 也能跑）
loginctl enable-linger clawd || true

# ============================================================================
# 2. 安装 Clawdbot（通过官方安装脚本，会自动安装 Node.js）
# ============================================================================

install_clawdbot() {
    log "Installing Clawdbot via official install script..."

    # 使用 clawd 用户运行官方安装脚本
    # --no-onboard: 跳过交互式引导
    # --no-prompt: 禁用提示（非交互模式）
    runuser -u clawd -- bash -c 'curl -fsSL https://molt.bot/install.sh | bash -s -- --no-onboard --no-prompt'

    log "Clawdbot installed successfully."
}

# 检查是否已安装 clawdbot
if runuser -u clawd -- bash -c 'command -v clawdbot' &>/dev/null || \
   [ -x "/home/clawd/.npm-global/bin/clawdbot" ]; then
    log "Clawdbot already installed."
else
    install_clawdbot
fi

# ============================================================================
# 3. 生成 Clawdbot 配置文件
# ============================================================================

log "Generating Clawdbot configuration..."

CLAWDBOT_CONFIG_DIR="/home/clawd/.clawdbot"
CLAWDBOT_WORKSPACE="/home/clawd/clawd"
mkdir -p "$CLAWDBOT_CONFIG_DIR"
mkdir -p "$CLAWDBOT_WORKSPACE"

# 生成配置文件
cat > "$CLAWDBOT_CONFIG_DIR/clawdbot.json" << 'CLAWDBOT_CONFIG_EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.1.24-3",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  },
  "wizard": {
    "lastRunAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "lastRunVersion": "2026.1.24-3",
    "lastRunCommand": "terraform-init",
    "lastRunMode": "local"
  },
  "models": {
    "mode": "merge",
    "providers": {
      "qiniu": {
        "baseUrl": "https://api.qnaigc.com",
        "apiKey": "${llm_api_key}",
        "api": "anthropic-messages",
        "models": [
          {
            "id": "minimax/minimax-m2.1",
            "name": "MiniMax-M2.1",
            "reasoning": false,
            "input": ["text"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 200000,
            "maxTokens": 128000
          },
          {
            "id": "deepseek/deepseek-chat",
            "name": "DeepSeek Chat",
            "reasoning": false,
            "input": ["text"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
            "contextWindow": 64000,
            "maxTokens": 8192
          },
          {
            "id": "qwen/qwen-max",
            "name": "Qwen Max",
            "reasoning": false,
            "input": ["text"],
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            },
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
      "workspace": "/home/clawd/clawd",
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto"
  },
  "gateway": {
    "port": ${gateway_port},
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "${dashboard_token}"
    },
    "tailscale": {
      "mode": "off",
      "resetOnExit": false
    }
  }
}
CLAWDBOT_CONFIG_EOF

# ============================================================================
# 4. 设置文件权限
# ============================================================================

log "Setting file permissions..."

chown -R clawd:clawd "$CLAWDBOT_CONFIG_DIR"
chown -R clawd:clawd "$CLAWDBOT_WORKSPACE"
chmod 600 "$CLAWDBOT_CONFIG_DIR/clawdbot.json"

# ============================================================================
# 5. 启动 Clawdbot Gateway
# ============================================================================

log "Installing and starting Clawdbot gateway..."

# 获取 clawd 用户的 UID
CLAWD_UID=$(id -u clawd)

# 设置 systemd --user 需要的环境变量
export XDG_RUNTIME_DIR="/run/user/$CLAWD_UID"

# 确保 runtime 目录存在
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chown clawd:clawd "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

# 使用 runuser 并设置正确的环境变量启动用户服务
# clawdbot 会被安装到 ~/.npm-global/bin 目录
runuser -u clawd -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" bash -c 'source ~/.bashrc && clawdbot gateway install' || {
    log "WARNING: Failed to install clawdbot gateway service."
}

runuser -u clawd -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" bash -c 'source ~/.bashrc && clawdbot gateway restart' || {
    log "WARNING: Failed to restart clawdbot gateway. It may need manual configuration."
}

# ============================================================================
# 6. 等待服务就绪
# ============================================================================

log "Waiting for Clawdbot gateway to be ready..."

MAX_WAIT=120
WAIT_INTERVAL=5
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    if ss -lntp | grep -q ":${gateway_port}"; then
        log "Clawdbot gateway is ready on port ${gateway_port}!"
        break
    fi
    sleep $WAIT_INTERVAL
    ELAPSED=$((ELAPSED + WAIT_INTERVAL))
    log "Waiting for gateway... ($ELAPSED/$MAX_WAIT seconds)"
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    log "WARNING: Clawdbot gateway did not start within $MAX_WAIT seconds."
    log "Check status with: ss -lntp | grep ${gateway_port}"
fi

# ============================================================================
# 7. 输出完成信息
# ============================================================================

PUBLIC_IP=$(curl -sf http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")

log "=============================================="
log "Clawdbot initialization completed!"
log "=============================================="
log "SSH as clawd: ssh clawd@$PUBLIC_IP"
log "Gateway port: ${gateway_port}"
log ""
log "To access dashboard from local machine:"
log "  ssh -N -L ${gateway_port}:127.0.0.1:${gateway_port} clawd@$PUBLIC_IP"
log "  Then open: http://localhost:${gateway_port}/?token=${dashboard_token}"
log ""
log "LLM Provider: Qiniu MaaS"
log "API URL: https://api.qnaigc.com"
log "Default Model: qiniu/${default_model}"
log "=============================================="

# 写入完成标记
touch /var/log/clawdbot-init-complete

log "Initialization script finished."
