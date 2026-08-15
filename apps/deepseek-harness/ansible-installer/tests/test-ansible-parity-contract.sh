#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

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
    printf 'unexpected legacy content %s in %s\n' "$expression" "$target" >&2
    exit 1
  }
}

site="$project_dir/playbooks/site.yml"
base_tasks="$project_dir/roles/base/tasks/main.yml"
node_tasks="$project_dir/roles/nodejs/tasks/main.yml"
node_cleanup="$project_dir/roles/nodejs/tasks/cleanup.yml"
node_defaults="$project_dir/roles/nodejs/defaults/main.yml"
harness_tasks="$project_dir/roles/deepseek_harness/tasks/main.yml"
nginx_defaults="$project_dir/roles/nginx/defaults/main.yml"
nginx_template="$project_dir/roles/nginx/templates/deepseek-harness.conf.j2"
skill_defaults="$project_dir/roles/las_dsh_environment/defaults/main.yml"
skill_template="$project_dir/roles/las_dsh_environment/templates/SKILL.md.j2"

require_text "$nginx_defaults" '^nginx_proxy_port: 3081$'
reject_text "$nginx_defaults" 'dsh_proxy_port'
require_text "$nginx_template" 'nginx_proxy_port'
reject_text "$nginx_template" 'dsh_proxy_port'
require_text "$site" 'nginx_proxy_port'
reject_text "$site" 'dsh_proxy_port'

require_text "$site" 'dsh_all_ports'
require_text "$site" 'dsh_port'
require_text "$site" 'code_server_port'
require_text "$site" 'code_server_proxy_port'
require_text "$site" 'unique \| list \| length'
require_text "$site" "select\('>=', 1\)"
require_text "$site" "select\('<=', 65535\)"

require_text "$base_tasks" 'SYS_GID_MAX'
require_text "$base_tasks" 'SYS_UID_MAX'
require_text "$base_tasks" '      - getent'
require_text "$base_tasks" '      - group'
require_text "$base_tasks" '      - passwd'
require_text "$base_tasks" 'sudo|admin|wheel'
require_text "$base_tasks" 'password_lock: true'

require_text "$harness_tasks" 'retries: 5'
require_text "$harness_tasks" 'until: dsh_prewarm.rc == 0'
reject_text "$harness_tasks" 'ansible\.builtin\.async_status'
reject_text "$harness_tasks" '^  async:'

require_text "$node_defaults" 'nodejs_managed_marker: \.las-dsh-managed'
require_text "$node_tasks" 'nodejs_managed_marker'
require_text "$node_tasks" 'content: "node:\{\{ nodejs_version \}\}\\n"'
require_text "$node_defaults" 'managed-toolchains'
require_text "$node_cleanup" 'realpath'
require_text "$node_cleanup" 'marker_version="\$\{registration##\*/node-v\}"'
require_text "$node_cleanup" 'node:\$marker_version'
require_text "$node_cleanup" 'cat "\$marker"'
require_text "$node_cleanup" 'nodejs_cleanup'
require_text "$node_defaults" 'nodejs_managed_toolchains_dir'

require_text "$skill_defaults" 'uv_version: 0.12.5'
require_text "$skill_template" '/opt/node-v\{\{ nodejs_version \}\}'
require_text "$skill_template" '/opt/uv-v\{\{ uv_version \}\}'
require_text "$skill_template" 'node --version'
require_text "$skill_template" 'uv init'
require_text "$skill_template" '不得改动 root 的 `/opt`、`/usr/local/bin` 或 `\{\{ dsh_ansible_venv_dir \}\}`'
require_text "$project_dir/README.md" 'nginx_proxy_port'

printf 'PASS Ansible parity contract\n'
