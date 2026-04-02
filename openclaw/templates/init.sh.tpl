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

if [[ -n "${wx_secret}" ]]; then
    log "Configuring OpenClaw Weixin binding..."

    OPENCLAW_HOME=$(getent passwd "$OPENCLAW_USER" | cut -d: -f6)
    ACCOUNT_LINE=$(cat <<'EOF_OPENCLAW_WX'
${wx_secret}
EOF_OPENCLAW_WX
)

    run_as_openclaw env ACCOUNT_LINE="$ACCOUNT_LINE" OPENCLAW_HOME="$OPENCLAW_HOME" bash <<'EOF_OPENCLAW_WX'
set -euo pipefail

IFS='|' read -r BOT_ID TOKEN SAVED_AT BASE_URL USER_ID EXTRA <<<"$${ACCOUNT_LINE}"

if [[ -n "$${EXTRA:-}" ]]; then
  echo "error: expected 5 fields, got extra data" >&2
  exit 1
fi

if [[ -z "$${BOT_ID}" || -z "$${TOKEN}" || -z "$${SAVED_AT}" || -z "$${BASE_URL}" || -z "$${USER_ID}" ]]; then
  echo "error: ACCOUNT_LINE must be botid|token|savedAt|baseUrl|userId" >&2
  exit 1
fi

BASE_DIR="$${OPENCLAW_HOME}/.openclaw/openclaw-weixin"
ACCOUNTS_DIR="$${BASE_DIR}/accounts"
ACCOUNT_FILE="$${ACCOUNTS_DIR}/$${BOT_ID}.json"
INDEX_FILE="$${BASE_DIR}/accounts.json"

mkdir -p "$${ACCOUNTS_DIR}"

cat > "$${INDEX_FILE}" <<EOF
[
  "$${BOT_ID}"
]
EOF

cat > "$${ACCOUNT_FILE}" <<EOF
{
  "token": "$${TOKEN}",
  "savedAt": "$${SAVED_AT}",
  "baseUrl": "$${BASE_URL}",
  "userId": "$${USER_ID}"
}
EOF

chmod 600 "$${ACCOUNT_FILE}" || true

echo "Wrote $${INDEX_FILE}"
echo "Wrote $${ACCOUNT_FILE}"
EOF_OPENCLAW_WX
fi

GATEWAY_JSON=$(cat <<ENDJSON
{"port":${gateway_port},"mode":"local","bind":"${gateway_bind}","auth":{"mode":"token","token":"${dashboard_token}"}}
ENDJSON
)
run_as_openclaw openclaw config set gateway --strict-json "$GATEWAY_JSON"
%{ if gateway_bind == "lan" ~}
run_as_openclaw openclaw config set gateway.controlUi.allowedOrigins --strict-json '["*"]'
%{ endif ~}
%{ if disable_device_auth ~}
run_as_openclaw openclaw config set gateway.controlUi.dangerouslyDisableDeviceAuth true
%{ endif ~}

# 3. 启动 OpenClaw Gateway
log "Starting OpenClaw gateway..."

OPENCLAW_UID=$(id -u "$OPENCLAW_USER")
export XDG_RUNTIME_DIR="/run/user/$OPENCLAW_UID"

if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chown "$OPENCLAW_USER:$OPENCLAW_USER" "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

run_as_openclaw env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" openclaw gateway install || {
    log "WARNING: Failed to install openclaw gateway service."
}

run_as_openclaw env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" openclaw gateway restart || {
    log "WARNING: Failed to restart openclaw gateway."
}

# 4. 等待服务就绪
ELAPSED=0
while [ $ELAPSED -lt 60 ]; do
    if ss -lntp | grep -q ":${gateway_port}"; then
        log "OpenClaw gateway is ready on port ${gateway_port}."
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge 60 ]; then
    log "WARNING: Gateway did not start within 60 seconds."
fi

touch /var/log/openclaw-init-complete
log "OpenClaw initialization completed."
