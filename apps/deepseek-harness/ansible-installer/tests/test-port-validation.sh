#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_dir/env.sh"
cd "$project_dir"

run_invalid_ports() {
  local description="$1"
  shift
  local output_file
  output_file="$(mktemp)"
  trap 'rm -f "$output_file"' RETURN

  if DSH_PUBLIC_AUTHORITY='harness.example.test' \
    DSH_CODE_SERVER_PUBLIC_AUTHORITY='code.example.test' \
    DSH_WEB_PASSWORD='test-password' \
    DSH_CODE_SERVER_PASSWORD='test-password' \
    DSH_PREVIEW_COUNT='1' \
    DSH_PREVIEW_PUBLIC_AUTHORITIES='["preview.example.test"]' \
    uv run --locked ansible-playbook \
      -i tests/inventory.yml \
      playbooks/site.yml \
      -e ansible_become=false \
      "$@" \
      --check >"$output_file" 2>&1; then
    printf 'invalid ports unexpectedly succeeded: %s\n' "$description" >&2
    cat "$output_file" >&2
    exit 1
  fi

  rg -q 'Provide valid endpoint authorities, passwords, and distinct service ports through inventory or extra vars\.' "$output_file" || {
    printf 'invalid ports did not fail validation: %s\n' "$description" >&2
    cat "$output_file" >&2
    exit 1
  }
}

run_invalid_ports 'out of range service port' -e 'nginx_proxy_port=65536'
run_invalid_ports 'conflicting service ports' -e 'nginx_proxy_port=3080'
run_invalid_ports 'non-integer Preview port' -e 'dsh_preview_ports=[30080,30081,30082,"30083.5"]'

printf 'PASS port validation\n'
