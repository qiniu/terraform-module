#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

require_text() {
  local target="$1" expression="$2"
  rg -q -- "$expression" "$target" || {
    printf 'missing required content %s in %s\n' "$expression" "$target" >&2
    exit 1
  }
}

reject_text() {
  local target="$1" expression="$2"
  ! rg -q -- "$expression" "$target" || {
    printf 'unexpected content %s in %s\n' "$expression" "$target" >&2
    exit 1
  }
}

for file in main.tf variables.tf outputs.tf versions.tf transfer.tftest.hcl; do
  [[ -f "$module_dir/$file" ]] || {
    printf 'missing required file: %s\n' "$file" >&2
    exit 1
  }
done

require_text "$module_dir/versions.tf" 'qiniu/qiniu'
require_text "$module_dir/versions.tf" '1\.0\.0'
require_text "$module_dir/variables.tf" 'variable "private_key"'
require_text "$module_dir/variables.tf" 'sensitive[[:space:]]*=[[:space:]]*true'
require_text "$module_dir/variables.tf" 'content_base64'
require_text "$module_dir/variables.tf" 'content_sha256'
require_text "$module_dir/variables.tf" 'destination_path'
require_text "$module_dir/main.tf" 'qiniu_compute_instance_exec" "prepare"'
require_text "$module_dir/main.tf" 'qiniu_compute_instance_exec" "chunks"'
require_text "$module_dir/main.tf" 'for_each[[:space:]]*='
require_text "$module_dir/main.tf" 'qiniu_compute_instance_exec\.prepare'
require_text "$module_dir/main.tf" 'qiniu_compute_instance_exec" "finalize"'
require_text "$module_dir/main.tf" 'qiniu_compute_instance_exec\.chunks'
require_text "$module_dir/main.tf" 'store_stdout[[:space:]]*=[[:space:]]*false'
require_text "$module_dir/main.tf" 'store_stderr[[:space:]]*=[[:space:]]*false'
require_text "$module_dir/main.tf" 'instance-exec-file-transfer-managed'
require_text "$module_dir/main.tf" 'realpath -e'
require_text "$module_dir/main.tf" 'stat -c'
require_text "$module_dir/main.tf" 'mktemp'
require_text "$module_dir/main.tf" 'mv -f'
require_text "$module_dir/main.tf" 'sha256sum'
require_text "$module_dir/main.tf" 'base64 -d'
require_text "$module_dir/main.tf" '8192'
require_text "$module_dir/outputs.tf" 'qiniu_compute_instance_exec\.finalize\.id'
reject_text "$module_dir/main.tf" 'web_password|code_server_password|authority|extra_vars'

printf 'PASS instance exec file transfer contract\n'
