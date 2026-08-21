#!/usr/bin/env bash
# DeepSeek Harness 服务器内部调试：./scripts/ssh.sh [command]
set -euo pipefail

for command in terraform jq; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "错误: 缺少必需命令: $command" >&2
        exit 1
    fi
done

cd "$(dirname "$0")/.."

if [[ ! -d .terraform ]]; then
    echo "错误: 尚未执行 terraform init" >&2
    exit 1
fi
if ! terraform state pull >/dev/null 2>&1; then
    echo "错误: 无法读取 Terraform state，请确认已成功 apply" >&2
    exit 1
fi

if ! outputs_json="$(terraform output -json 2>/dev/null)"; then
    echo "错误: 无法读取 Terraform output，请确认已成功 apply" >&2
    exit 1
fi
if ! jq -e . >/dev/null 2>&1 <<<"$outputs_json"; then
    echo "错误: Terraform output 不是有效 JSON" >&2
    exit 1
fi
ssh_cmd="$(jq -r '.ssh_command.value // empty' <<<"$outputs_json")"
if [[ -z "$ssh_cmd" ]]; then
    echo "错误: SSH 未启用，请设置 enable_ssh_port_forward = true 并执行 terraform apply" >&2
    exit 1
fi

if ! endpoint="$(jq -er '.ssh_command.value | capture("ssh -p (?<port>[0-9]+) root@(?<host>[^ ]+)") | "\(.host) \(.port)"' <<<"$outputs_json" 2>/dev/null)"; then
    echo "错误: 无法解析 Terraform 输出中的 SSH 端点" >&2
    exit 1
fi
read -r host port <<<"$endpoint"

known_hosts_file="${HOME}/.ssh/known_hosts"

if ! state_json="$(terraform show -json 2>/dev/null)"; then
    echo "错误: 无法读取 Terraform state JSON，请确认 state 完整可用" >&2
    exit 1
fi
if ! private_key="$(jq -er '[
  .values.root_module.child_modules[]?
  | select(.address == "module.infrastructure")
  | .resources[]?
  | select(.type == "qiniu_compute_key_pair")
  | .values.private_key
] | first // empty' <<<"$state_json" 2>/dev/null)"; then
    echo "错误: Terraform state 中没有部署私钥，请确认已成功 apply" >&2
    exit 1
fi

key_file="$(mktemp "${TMPDIR:-/tmp}/deepseek_harness_key.XXXXXX")"
ssh_error_file="$(mktemp "${TMPDIR:-/tmp}/deepseek_harness_ssh.XXXXXX")"
chmod 600 "$key_file"
trap 'rm -f "$key_file" "$ssh_error_file"' EXIT
printf '%s\n' "$private_key" >"$key_file"

echo "正在连接 ${host}:${port} ..."
connect() {
    ssh -i "$key_file" -p "$port" \
        -o ConnectTimeout=15 \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile="$known_hosts_file" \
        -o ServerAliveInterval=30 \
        root@"$host" "$@"
}

if connect "$@" 2>"$ssh_error_file"; then
    cat "$ssh_error_file" >&2
    exit 0
else
    ssh_status=$?
fi

if [[ "$ssh_status" -eq 255 ]] && grep -Fq 'REMOTE HOST IDENTIFICATION HAS CHANGED!' "$ssh_error_file"; then
    ssh-keygen -R "[${host}]:${port}" -f "$known_hosts_file" >/dev/null 2>&1 || true
    connect "$@"
    exit $?
fi

cat "$ssh_error_file" >&2
exit "$ssh_status"
