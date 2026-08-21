#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

mkdir -p "$test_root/bin" "$test_root/home/.ssh"

ssh-keygen -q -t ed25519 -N '' -f "$test_root/key" >/dev/null
public_key="$(cut -d' ' -f1-2 "$test_root/key.pub")"
printf '[dsh.example.test]:2222 %s\n' "$public_key" > "$test_root/home/.ssh/known_hosts"
printf '[other.example.test]:2222 %s\n' "$public_key" >> "$test_root/home/.ssh/known_hosts"

cat > "$test_root/bin/terraform" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  state) exit 0 ;;
  output) printf '%s\n' '{"ssh_command":{"value":"ssh -p 2222 root@dsh.example.test"}}' ;;
  show) printf '%s\n' '{"values":{"root_module":{"child_modules":[{"address":"module.infrastructure","resources":[{"type":"qiniu_compute_key_pair","values":{"private_key":"test-key"}}]}]}}}' ;;
esac
EOF

cat > "$test_root/bin/jq" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *capture*) printf '%s\n' 'dsh.example.test 2222' ;;
  *private_key*) printf '%s\n' 'test-key' ;;
  *ssh_command.value*) printf '%s\n' 'ssh -p 2222 root@dsh.example.test' ;;
  *) cat ;;
esac
EOF

cat > "$test_root/bin/ssh" <<'EOF'
#!/usr/bin/env bash
if [[ ! -e "${SSH_RETRY_MARKER:?}" ]]; then
  touch "$SSH_RETRY_MARKER"
  echo 'REMOTE HOST IDENTIFICATION HAS CHANGED!' >&2
  exit 255
fi
printf '%s\n' "$*" >> "${SSH_ARGS_FILE:?}"
EOF

chmod 700 "$test_root/bin/terraform" "$test_root/bin/jq" "$test_root/bin/ssh"
mkdir -p "$script_dir/../.terraform"

PATH="$test_root/bin:$PATH" HOME="$test_root/home" SSH_ARGS_FILE="$test_root/ssh-args" SSH_RETRY_MARKER="$test_root/retry-marker" "$script_dir/ssh.sh" true >/dev/null

if ssh-keygen -F '[dsh.example.test]:2222' -f "$test_root/home/.ssh/known_hosts" >/dev/null; then
  echo 'expected the stale target host key to be removed' >&2
  exit 1
fi
ssh-keygen -F '[other.example.test]:2222' -f "$test_root/home/.ssh/known_hosts" >/dev/null
grep -F -- '-p 2222' "$test_root/ssh-args" >/dev/null
grep -F -- 'root@dsh.example.test true' "$test_root/ssh-args" >/dev/null
