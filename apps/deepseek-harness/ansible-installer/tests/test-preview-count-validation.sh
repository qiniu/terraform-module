#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_dir/env.sh"
cd "$project_dir"

run_invalid_count() {
  local preview_count="$1"
  local output_file
  output_file="$(mktemp)"
  trap 'rm -f "$output_file"' RETURN

  if DSH_PUBLIC_AUTHORITY='harness.example.test' \
    DSH_CODE_SERVER_PUBLIC_AUTHORITY='code.example.test' \
    DSH_WEB_PASSWORD='test-password' \
    DSH_CODE_SERVER_PASSWORD='test-password' \
    DSH_PREVIEW_COUNT="$preview_count" \
    DSH_PREVIEW_PUBLIC_AUTHORITIES='[]' \
    uv run --locked ansible-playbook \
      -i tests/inventory.yml \
      playbooks/site.yml \
      -e ansible_become=false \
      --check >"$output_file" 2>&1; then
    printf 'invalid DSH_PREVIEW_COUNT unexpectedly succeeded: %s\n' "$preview_count" >&2
    cat "$output_file" >&2
    exit 1
  fi

  rg -q 'Provide endpoint authorities and passwords through inventory or extra vars\.' "$output_file" || {
    printf 'invalid DSH_PREVIEW_COUNT did not fail validation: %s\n' "$preview_count" >&2
    cat "$output_file" >&2
    exit 1
  }
}

run_invalid_count 'abc'
run_invalid_count '1.5'
run_invalid_count '5'

printf 'PASS preview count validation\n'
