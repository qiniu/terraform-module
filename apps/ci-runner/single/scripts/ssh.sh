#!/usr/bin/env bash
#
# 一键 SSH 登录 CI Runner 服务器
# 用法:
#   ./ssh.sh              # 交互式登录
#   ./ssh.sh <command>    # 远程执行命令，如 ./ssh.sh "uptime && df -h"
#
set -euo pipefail

cd "$(dirname "$0")/.."

# ---------- 读取 terraform output ----------
output="$(terraform output -json)"

endpoint="$(echo "$output" | jq -r '.ssh_endpoints.value[0] // empty')"
private_key="$(echo "$output" | jq -r '.ssh_private_key.value // empty')"

if [[ -z "$endpoint" || "$private_key" == "null" || -z "$private_key" ]]; then
    echo "错误: 无法从 terraform output 获取 SSH 连接信息。" >&2
    echo "请确认已执行 terraform apply 且 enable_ssh_port_forward = true" >&2
    exit 1
fi

host="${endpoint%%:*}"
port="${endpoint##*:}"

# ---------- 写入临时私钥 ----------
key_file="$(mktemp /tmp/ci_runner_key.XXXXXX)"
chmod 600 "$key_file"
echo "$private_key" > "$key_file"
trap 'rm -f "$key_file"' EXIT

# ---------- 连接 ----------
echo "正在连接 ${host}:${port} ..."
exec ssh -i "$key_file" -p "$port" \
    -o StrictHostKeyChecking=accept-new \
    -o ServerAliveInterval=30 \
    root@"$host" "$@"
