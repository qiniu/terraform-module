#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

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

require_file "$project_dir/env.sh"
require_file "$project_dir/deploy.sh"
require_file "$project_dir/pyproject.toml"
require_file "$project_dir/uv.lock"
require_file "$project_dir/ansible.cfg"
require_file "$project_dir/playbooks/site.yml"
require_file "$project_dir/inventory/hosts.yml.example"
require_file "$project_dir/tests/terraform/main.tf"
require_file "$project_dir/tests/provision-qiniu.sh"
require_file "$project_dir/tests/test-idempotence.sh"
require_file "$project_dir/tests/destroy-qiniu.sh"
require_file "$project_dir/README.md"
require_file "$project_dir/tests/inventory.yml"
require_file "$project_dir/tests/nodejs-version-check.yml"
require_file "$project_dir/tests/test-nodejs-version-check.sh"

git -C "$project_dir/../../.." check-ignore -q -- \
  "apps/deepseek-harness/ansible-installer/env.sh" && {
  printf 'env.sh is required by deploy.sh and must not be ignored\n' >&2
  exit 1
}

[[ ! -e "$project_dir/group_vars/all/main.yml.example" ]] || {
  printf 'group_vars/all/main.yml.example is redundant because main.yml is safe to track\n' >&2
  exit 1
}

for role in base nodejs code_server deepseek_harness nginx deployment_skill; do
  require_file "$project_dir/roles/$role/tasks/main.yml"
  require_file "$project_dir/roles/$role/defaults/main.yml"
  require_text "$project_dir/playbooks/site.yml" "^    - $role$"
done

require_text "$project_dir/env.sh" 'UV_UNMANAGED_INSTALL'
require_text "$project_dir/env.sh" '\.tools/uv'
require_text "$project_dir/deploy.sh" 'uv run --locked ansible-playbook'
require_text "$project_dir/pyproject.toml" 'ansible-core'
require_text "$project_dir/pyproject.toml" 'requires-python'
require_text "$project_dir/ansible.cfg" '^roles_path ='
require_text "$project_dir/roles/base/tasks/main.yml" 'ansible\.builtin\.apt'
require_text "$project_dir/roles/base/tasks/main.yml" 'ansible\.builtin\.user'
require_text "$project_dir/roles/nodejs/tasks/main.yml" 'ansible\.builtin\.get_url'
require_text "$project_dir/roles/nodejs/tasks/main.yml" 'ansible\.builtin\.unarchive'
require_text "$project_dir/roles/code_server/tasks/main.yml" 'ansible\.builtin\.get_url'
require_text "$project_dir/roles/code_server/tasks/main.yml" 'ansible\.builtin\.systemd_service'
require_text "$project_dir/roles/deepseek_harness/tasks/main.yml" '/usr/local/bin/npm'
require_text "$project_dir/roles/deepseek_harness/tasks/main.yml" '^      - exec$'
require_text "$project_dir/roles/deepseek_harness/tasks/main.yml" '^  async: 1800$'
require_text "$project_dir/roles/deepseek_harness/tasks/main.yml" 'ansible\.builtin\.async_status'
require_text "$project_dir/roles/deepseek_harness/templates/deepseek-harness.service.j2" -- '--offline'
require_text "$project_dir/roles/nginx/tasks/main.yml" 'htpasswd'
require_text "$project_dir/roles/nginx/handlers/main.yml" '^      - nginx$'
require_text "$project_dir/roles/nginx/handlers/main.yml" '^      - -t$'
require_text "$project_dir/roles/nginx/templates/deepseek-harness.conf.j2" 'proxy_pass http://127.0.0.1:'
require_text "$project_dir/roles/nginx/defaults/main.yml" 'dsh_proxy_port: 3081'
require_text "$project_dir/roles/nginx/defaults/main.yml" 'code_server_proxy_port: 3087'
! rg -q 'preview_proxy_port|preview_port' "$project_dir/roles/nginx" || {
  printf 'Preview must use direct HTTPProxy instead of an Nginx proxy\n' >&2
  exit 1
}
require_text "$project_dir/roles/code_server/defaults/main.yml" 'code_server_port: 3086'
require_text "$project_dir/group_vars/all/main.yml" 'DSH_PREVIEW_COUNT'
require_text "$project_dir/group_vars/all/main.yml" 'dsh_preview_count_raw'
require_text "$project_dir/group_vars/all/main.yml" 'DSH_PREVIEW_PUBLIC_AUTHORITIES'
require_text "$project_dir/playbooks/site.yml" 'dsh_preview_public_authorities is not mapping'
require_text "$project_dir/playbooks/site.yml" "dsh_preview_count_raw is match\('^\\(0|\[1-4\]\)\\$'\)"
require_text "$project_dir/roles/nodejs/tasks/main.yml" 'Read the installed Node.js version'
require_text "$project_dir/roles/nodejs/tasks/main.yml" 'nodejs_needs_install'
require_text "$project_dir/roles/deployment_skill/templates/SKILL.md.j2" 'dsh_preview_ports'
require_text "$project_dir/roles/deployment_skill/templates/SKILL.md.j2" '503'
require_text "$project_dir/tests/terraform/main.tf" 'preview_count'
require_text "$project_dir/tests/terraform/main.tf" 'preview_public_authorities'
require_text "$project_dir/roles/deployment_skill/templates/SKILL.md.j2" 'deployment-environment'
require_text "$project_dir/playbooks/site.yml" 'ansible\.builtin\.uri'
require_text "$project_dir/tests/provision-qiniu.sh" 'apps/ci-runner/single/env.sh'
require_text "$project_dir/tests/provision-qiniu.sh" 'chmod 600'
require_text "$project_dir/tests/test-idempotence.sh" 'changed=0'
require_text "$project_dir/tests/test-idempotence.sh" 'DSH_PREVIEW_PUBLIC_AUTHORITIES'
require_text "$project_dir/tests/destroy-qiniu.sh" 'terraform destroy'

if command -v zsh >/dev/null 2>&1; then
  zsh_uv_dir="$(zsh -fc 'source "$1"; printf "%s" "$dsh_uv_dir"' zsh "$project_dir/env.sh")"
  [[ "$zsh_uv_dir" == "$project_dir/.tools/uv" ]] || {
    printf 'env.sh must resolve its own .tools/uv directory when sourced from zsh\n' >&2
    exit 1
  }
fi

printf 'PASS project contract\n'
