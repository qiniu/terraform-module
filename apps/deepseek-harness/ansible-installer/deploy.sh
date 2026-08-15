#!/usr/bin/env bash
set -euo pipefail

dsh_ansible_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
inventory_file="${ANSIBLE_INVENTORY:-$dsh_ansible_dir/inventory/hosts.yml}"

if [[ ! -f "$inventory_file" ]]; then
  printf 'inventory not found: %s\n' "$inventory_file" >&2
  printf 'copy inventory/hosts.yml.example and provide a reachable host first\n' >&2
  exit 1
fi

: "${DSH_WEB_PASSWORD:?DSH_WEB_PASSWORD must be set}"
: "${DSH_CODE_SERVER_PASSWORD:?DSH_CODE_SERVER_PASSWORD must be set}"

source "$dsh_ansible_dir/env.sh"
cd -- "$dsh_ansible_dir"
exec uv run --locked ansible-playbook -i "$inventory_file" playbooks/site.yml "$@"
