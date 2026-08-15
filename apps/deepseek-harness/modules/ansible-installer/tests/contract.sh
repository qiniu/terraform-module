#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

require_file() {
  local target="$1"
  [[ -f "$target" ]] || {
    printf 'missing required file: %s\n' "$target" >&2
    exit 1
  }
}

require_text() {
  local target="$1"
  local expression="$2"
  rg -q -- "$expression" "$target" || {
    printf 'missing required content %s in %s\n' "$expression" "$target" >&2
    exit 1
  }
}

reject_text() {
  local target="$1"
  local expression="$2"
  ! rg -q -- "$expression" "$target" || {
    printf 'unexpected content %s in %s\n' "$expression" "$target" >&2
    exit 1
  }
}

main_tf="$module_dir/main.tf"
variables_tf="$module_dir/variables.tf"
versions_tf="$module_dir/versions.tf"
bootstrap="$module_dir/templates/install.sh.tftpl"
skill_template="$module_dir/ansible/roles/las_dsh_environment/templates/SKILL.md.j2"

for file in "$main_tf" "$variables_tf" "$versions_tf" "$bootstrap" "$skill_template"; do
  require_file "$file"
done

reject_text "$versions_tf" 'hashicorp/archive'
reject_text "$main_tf" 'archive_file'
reject_text "$main_tf" 'tar\.gz'
require_text "$main_tf" 'ansible_runtime_files'
require_text "$main_tf" 'runtime_manifest'
require_text "$main_tf" 'filebase64'
require_text "$main_tf" 'filesha256'
require_text "$module_dir/outputs.tf" 'runtime_file_contents'
require_text "$module_dir/outputs.tf" 'runtime_file_metadata'
require_text "$module_dir/outputs.tf" 'runtime_manifest'
require_text "$module_dir/outputs.tf" 'bootstrap'
require_text "$module_dir/outputs.tf" 'length\(local\.install_command\)[[:space:]]*<=[[:space:]]*8192'
require_text "$module_dir/outputs.tf" 'sensitive[[:space:]]*=[[:space:]]*true'
require_text "$variables_tf" 'variable "uv_version"'
require_text "$variables_tf" 'default[[:space:]]*=[[:space:]]*"0\.12\.5"'

require_text "$bootstrap" 'set -euo pipefail'
require_text "$bootstrap" 'umask 077'
require_text "$bootstrap" 'x86_64-unknown-linux-gnu'
require_text "$bootstrap" 'aarch64-unknown-linux-gnu'
require_text "$bootstrap" 'uv-\$\$\{uv_target\}\.tar\.gz'
require_text "$bootstrap" 'sha256sum -c'
require_text "$bootstrap" '/opt/uv-v'
require_text "$bootstrap" 'uv_link_dir=/usr/local/bin'
require_text "$bootstrap" 'uv:'
require_text "$bootstrap" 'UV_PROJECT_ENVIRONMENT=/opt/las-dsh-installer/\.venv'
require_text "$bootstrap" 'UV_CACHE_DIR=/var/cache/las-dsh-installer/uv'
require_text "$bootstrap" 'uv sync --locked'
require_text "$bootstrap" 'uv run --locked ansible-playbook'
require_text "$bootstrap" 'cleanup_superseded_uv'
require_text "$bootstrap" 'uv-v\*'
require_text "$bootstrap" 'current_registration'
require_text "$bootstrap" 'realpath -e'
require_text "$bootstrap" 'stat -c'
require_text "$bootstrap" 'uv:\$\$\{registered_version\}'
require_text "$bootstrap" 'unsafe managed uv registration'
require_text "$bootstrap" 'rm -rf -- "\$\$\{prefix\}"'
require_text "$bootstrap" 'rm -f -- "\$\$\{registration\}"'
require_text "$bootstrap" 'verify_existing_uv_prefix_is_managed'
require_text "$bootstrap" 'unsafe existing uv prefix'
require_text "$bootstrap" 'current_registration="\$\$\{managed_toolchains_dir\}/uv-v\$\$\{uv_version\}"'
require_text "$bootstrap" 'uv:\$\$\{uv_version\}'
require_text "$bootstrap" 'checksum_manifest'
require_text "$bootstrap" 'awk -v archive="\$\$\{uv_archive\}"'
require_text "$bootstrap" 'checksum_count != 1'
require_text "$bootstrap" 'sha256sum -c "\$\$\{checksum_manifest\}"'
require_text "$bootstrap" 'mktemp "\$\$\{uv_link_dir\}/\.\$\$\{executable\}\.XXXXXX"'
require_text "$bootstrap" 'rm -f -- "\$\$\{link_candidate\}"'
require_text "$bootstrap" 'mktemp'
require_text "$bootstrap" 'chmod 600'
require_text "$bootstrap" 'runtime_manifest_path='
require_text "$bootstrap" 'runtime_manifest_sha256='
require_text "$bootstrap" 'uv_version="\$1"'
require_text "$bootstrap" 'runtime manifest SHA-256 mismatch'
require_text "$bootstrap" 'sha256sum -c \.runtime-sha256'
reject_text "$bootstrap" 'ansible_archive'
reject_text "$bootstrap" 'web_password='
reject_text "$bootstrap" 'code_server_password='
require_text "$skill_template" '/usr/local/bin/uvx'
require_text "$skill_template" 'uvx --version'
reject_text "$skill_template" '本阶段不会安装或更新 uv'

for forbidden in '.tools' '.venv' 'tests/' 'docs/' 'deploy.sh' 'env.sh' 'inventory/hosts.yml.example'; do
  reject_text "$main_tf" "$forbidden"
done

rendered="$(mktemp)"
trap 'rm -f -- "$rendered"' EXIT
sed \
  -e 's/%{[^}]*}//g' \
  -e 's/\${[^}]*}/placeholder/g' \
  "$bootstrap" >"$rendered"
bash -n "$rendered"

printf 'PASS ansible installer module contract\n'
