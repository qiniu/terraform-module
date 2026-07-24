#!/usr/bin/env bash
#
# 一键 SSH 登录 CI Runner 服务器（内部调试用）
# 用法:
#   ./scripts/ssh.sh              # 交互式登录
#   ./scripts/ssh.sh <command>    # 远程执行命令
#
set -euo pipefail

cd "$(dirname "$0")/.."

# ---------- 从 terraform 获取连接信息 ----------
ssh_cmd="$(terraform output -raw ssh_command 2>/dev/null || true)"

if [[ -z "$ssh_cmd" || "$ssh_cmd" == "null" ]]; then
    echo "错误: 无 SSH 端点，请确认 enable_ssh_port_forward = true 且已 terraform apply" >&2
    exit 1
fi

port="$(echo "$ssh_cmd" | grep -oP '(?<=-p )\d+')"
host="$(echo "$ssh_cmd" | grep -oP '(?<=root@)\S+')"

# ---------- 从 state 提取部署私钥 ----------
state_json="$(terraform show -json 2>/dev/null)"
private_key="$(echo "$state_json" | jq -r '
  .values.root_module.child_modules[]
  | select(.address == "module.infrastructure")
  | .resources[]
  | select(.type == "qiniu_compute_key_pair")
  | .values.private_key
' 2>/dev/null)"

if [[ -z "$private_key" || "$private_key" == "null" ]]; then
    echo "错误: 无法获取部署私钥，请尝试密码登录: $ssh_cmd" >&2
    exit 1
fi

key_file="$(mktemp /tmp/ci_runner_key.XXXXXX)"
chmod 600 "$key_file"
printf '%s\n' "$private_key" > "$key_file"
trap 'rm -f "$key_file"' EXIT

echo "正在连接 ${host}:${port} ..."
exec ssh -i "$key_file" -p "$port" \
    -o StrictHostKeyChecking=accept-new \
    -o ServerAliveInterval=30 \
    root@"$host" "$@"
