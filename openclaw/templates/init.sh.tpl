#!/bin/bash
# OpenClaw 初始化脚本（预制镜像版）
# 预制镜像已包含 Node.js 和 OpenClaw
set -euo pipefail

OPENCLAW_USER="openclaw"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/openclaw-init.log
}

run_as_openclaw() {
    runuser -u "$OPENCLAW_USER" -- "$@"
}

log "Starting OpenClaw initialization..."

# 1. 创建 openclaw 用户
if ! id -u "$OPENCLAW_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$OPENCLAW_USER"
    usermod -aG sudo "$OPENCLAW_USER"
    log "openclaw user created."
fi

printf '%s:%s\n' "$OPENCLAW_USER" '${openclaw_password}' | chpasswd
loginctl enable-linger "$OPENCLAW_USER" || true

# 2. 通过 CLI 写入配置
log "Configuring OpenClaw..."

MODEL_ID="${default_model}"

case "$MODEL_ID" in
    "minimax/minimax-m2.5")    REASONING=false; CTX_WINDOW=200000; MAX_TOKENS=128000 ;;
    "deepseek/deepseek-chat")  REASONING=false; CTX_WINDOW=64000;  MAX_TOKENS=8192  ;;
    "deepseek/deepseek-r1")    REASONING=true;  CTX_WINDOW=64000;  MAX_TOKENS=8192  ;;
    "qwen/qwen-max")           REASONING=false; CTX_WINDOW=32000;  MAX_TOKENS=8192  ;;
    "kimi/kimi-k2")            REASONING=false; CTX_WINDOW=128000; MAX_TOKENS=8192  ;;
    *)                         REASONING=false; CTX_WINDOW=128000; MAX_TOKENS=8192  ;;
esac

PROVIDER_JSON=$(cat <<ENDJSON
{"baseUrl":"https://api.qnaigc.com/v1","apiKey":"${maas_api_key}","api":"openai-completions","models":[{"id":"$MODEL_ID","name":"$MODEL_ID","reasoning":$REASONING,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":$CTX_WINDOW,"maxTokens":$MAX_TOKENS}]}
ENDJSON
)

run_as_openclaw openclaw config set models.mode merge
run_as_openclaw openclaw config set "models.providers.qiniu" --strict-json "$PROVIDER_JSON"
run_as_openclaw openclaw models set "qiniu/$MODEL_ID"

touch /var/log/openclaw-init-complete
log "OpenClaw initialization completed."
