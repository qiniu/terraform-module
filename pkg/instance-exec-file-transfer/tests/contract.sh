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

for file in main.tf variables.tf outputs.tf versions.tf transfer.tftest.hcl templates/prepare.sh.tftpl templates/chunk.sh.tftpl templates/finalize.sh.tftpl; do
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
require_text "$module_dir/main.tf" 'templatefile\('
reject_text "$module_dir/main.tf" '<<-BASH'
require_text "$module_dir/main.tf" '8192'
require_text "$module_dir/main.tf" 'prepare_generation'
require_text "$module_dir/main.tf" 'instance-exec-file-transfer-managed'
require_text "$module_dir/templates/prepare.sh.tftpl" 'marker_name'
require_text "$module_dir/templates/prepare.sh.tftpl" 'realpath -e'
require_text "$module_dir/templates/prepare.sh.tftpl" 'stat -c'
require_text "$module_dir/templates/prepare.sh.tftpl" 'target_sha='
require_text "$module_dir/templates/prepare.sh.tftpl" 'target marker hash mismatch'
require_text "$module_dir/templates/prepare.sh.tftpl" 'refusing unmanaged target'
require_text "$module_dir/templates/chunk.sh.tftpl" 'mktemp'
require_text "$module_dir/templates/chunk.sh.tftpl" 'mv -f'
require_text "$module_dir/templates/finalize.sh.tftpl" 'marker_temporary'
require_text "$module_dir/templates/finalize.sh.tftpl" 'sha256sum'
require_text "$module_dir/templates/finalize.sh.tftpl" 'base64 -d'
require_text "$module_dir/templates/finalize.sh.tftpl" 'mv -f -- "\$temporary" "\$destination"; mv -f -- "\$marker_temporary" "\$target_marker"'
require_text "$module_dir/outputs.tf" 'qiniu_compute_instance_exec\.finalize\.id'
for source_file in "$module_dir/main.tf" "$module_dir/variables.tf" "$module_dir/outputs.tf" "$module_dir"/templates/*.sh.tftpl; do
  reject_text "$source_file" 'web_password|code_server_password|authority|extra_vars'
  reject_text "$source_file" 'base64decode\('
  reject_text "$source_file" 'sha256\(base64'
done

for template in "$module_dir"/templates/*.sh.tftpl; do
  rendered="$(mktemp)"
  trap 'rm -f -- "$rendered"' EXIT
  sed -e 's/\$${/${/g' -e 's/\${[^}]*}/placeholder/g' "$template" >"$rendered"
  bash -n "$rendered"
  rm -f -- "$rendered"
  trap - EXIT
done

printf 'PASS instance exec file transfer contract\n'
