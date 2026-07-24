#!/usr/bin/env bash
#
# 一键 SSH 登录 CI Runner 服务器（内部调试用）
# 用法:
#   ./scripts/ssh.sh              # 交互式登录
#   ./scripts/ssh.sh <command>    # 远程执行命令
#
set -euo pipefail

cd "$(dirname "$0")/.."

# ---------- 读取 terraform 信息 ----------
output="$(terraform output -json)"

endpoint="$(echo "$output" | jq -r '.ssh_endpoints.value[0] // empty')"

if [[ -z "$endpoint" ]]; then
    echo "错误: 无 SSH 端点，请确认 enable_ssh_port_forward = true 且已 terraform apply" >&2
    exit 1
fi

host="${endpoint%%:*}"
port="${endpoint##*:}"

# ---------- 从 state 中提取部署私钥（内部使用） ----------
private_key="$(terraform state show -json module.infrastructure.qiniu_compute_key_pair.deployment 2>/dev/null | jq -r '.values.private_key // empty')"

if [[ -z "$private_key" ]]; then
    echo "错误: 无法从 terraform state 获取部署私钥。" >&2
    echo "若已设置 instance_password，可直接: ssh -p $port root@$host" >&2
    exit 1
fi

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
