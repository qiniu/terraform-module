#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$test_dir/.." && pwd)"
generated_dir="$test_dir/generated"
environment_file="$generated_dir/deployment.env"
inventory_file="$generated_dir/hosts.yml"
first_log="$generated_dir/first-playbook.log"
second_log="$generated_dir/second-playbook.log"

[[ -f "$environment_file" && -f "$inventory_file" ]] || {
  printf 'run tests/provision-qiniu.sh before this test\n' >&2
  exit 1
}

source "$environment_file"
export ANSIBLE_INVENTORY="$inventory_file"
"$project_dir/deploy.sh" > "$first_log"
"$project_dir/deploy.sh" > "$second_log"

rg -q 'changed=0.*failed=0' "$second_log" || {
  printf 'the second deployment was not idempotent\n' >&2
  exit 1
}

curl --fail --silent --show-error \
  --user "$DSH_WEB_USERNAME:$DSH_WEB_PASSWORD" \
  "https://$DSH_PUBLIC_AUTHORITY/" >/dev/null

code_server_status="$(curl --silent --output /dev/null --write-out '%{http_code}' "https://$DSH_CODE_SERVER_PUBLIC_AUTHORITY/")"
[[ "$code_server_status" == 302 || "$code_server_status" == 401 ]] || {
  printf 'expected code-server public endpoint to require authentication, got %s\n' "$code_server_status" >&2
  exit 1
}

if (( DSH_PREVIEW_COUNT > 0 )); then
  preview_authority="$(printf '%s' "$DSH_PREVIEW_PUBLIC_AUTHORITIES" | jq -er '.[0]')"
  preview_status="$(curl --silent --output /dev/null --write-out '%{http_code}' "https://$preview_authority/")"
  [[ "$preview_status" == 502 || "$preview_status" == 503 ]] || {
    printf 'expected Preview HTTPProxy without an app listener to return 502 or 503, got %s\n' "$preview_status" >&2
    exit 1
  }
fi

printf 'PASS live deployment and idempotence\n'
