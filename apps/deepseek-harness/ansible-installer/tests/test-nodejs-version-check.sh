#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_dir/env.sh"

output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT
nodejs_test_prefix="$(dirname -- "$(dirname -- "$(command -v node)")")"
(
  cd "$project_dir"
  uv run --locked ansible-playbook \
    -i tests/inventory.yml \
    tests/nodejs-version-check.yml \
    -e "nodejs_prefix=$nodejs_test_prefix" \
    -e 'nodejs_version=0.0.0' \
    --tags nodejs-version-check >"$output_file" 2>&1
)

rg -q 'Verify a mismatched Node.js binary requires installation' "$output_file" || {
  printf 'Node.js version mismatch did not require installation\n' >&2
  cat "$output_file" >&2
  exit 1
}

printf 'PASS nodejs version reconciliation\n'
