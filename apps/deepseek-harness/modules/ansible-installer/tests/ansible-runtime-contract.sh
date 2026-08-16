#!/usr/bin/env bash
set -euo pipefail

runtime_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../ansible" && pwd)"

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

site="$runtime_dir/playbooks/site.yml"
ansible_cfg="$runtime_dir/ansible.cfg"
inventory="$runtime_dir/inventory/default/hosts.yml"
group_vars="$runtime_dir/inventory/default/group_vars/all/main.yml"
base_tasks="$runtime_dir/roles/base/tasks/main.yml"
node_tasks="$runtime_dir/roles/nodejs/tasks/main.yml"
node_cleanup="$runtime_dir/roles/nodejs/tasks/cleanup.yml"
node_defaults="$runtime_dir/roles/nodejs/defaults/main.yml"
harness_tasks="$runtime_dir/roles/deepseek_harness/tasks/main.yml"
nginx_defaults="$runtime_dir/roles/nginx/defaults/main.yml"
nginx_template="$runtime_dir/roles/nginx/templates/deepseek-harness.conf.j2"
skill_defaults="$runtime_dir/roles/las_dsh_environment/defaults/main.yml"
skill_template="$runtime_dir/roles/las_dsh_environment/templates/SKILL.md.j2"

for role in base nodejs code_server deepseek_harness nginx las_dsh_environment; do
  [[ -f "$runtime_dir/roles/$role/tasks/main.yml" ]] || exit 1
  [[ -f "$runtime_dir/roles/$role/defaults/main.yml" ]] || exit 1
  require_text "$site" "^    - $role$"
done

[[ -f "$inventory" ]] || exit 1
[[ -f "$group_vars" ]] || exit 1
require_text "$ansible_cfg" '^inventory = ./inventory/default$'
reject_text "$site" 'vars_files:'

require_text "$runtime_dir/pyproject.toml" 'ansible-core==2\.20\.2'
require_text "$nginx_defaults" '^nginx_proxy_port: 3081$'
reject_text "$nginx_defaults" 'dsh_proxy_port'
require_text "$nginx_template" 'nginx_proxy_port'
reject_text "$nginx_template" 'dsh_proxy_port'
require_text "$site" 'dsh_all_ports'
require_text "$site" 'unique \| list \| length'
require_text "$site" "select\('>=', 1\)"
require_text "$site" "select\('<=', 65535\)"

require_text "$base_tasks" 'SYS_GID_MAX'
require_text "$base_tasks" 'SYS_UID_MAX'
require_text "$base_tasks" 'sudo|admin|wheel'
require_text "$base_tasks" 'password_lock: true'
require_text "$harness_tasks" 'retries: 5'
require_text "$harness_tasks" 'until: dsh_prewarm.rc == 0'
reject_text "$harness_tasks" 'ansible\.builtin\.async_status'
require_text "$node_defaults" 'nodejs_managed_marker: \.las-dsh-managed'
require_text "$node_tasks" 'nodejs_managed_marker'
require_text "$node_cleanup" 'realpath'
require_text "$node_cleanup" 'nodejs_cleanup'
require_text "$node_cleanup" '^  environment:'
reject_text "$node_cleanup" '^    argv:'
require_text "$skill_defaults" 'uv_version: 0.12.5'
require_text "$skill_template" '/opt/node-v\{\{ nodejs_version \}\}'
require_text "$skill_template" '/opt/uv-v\{\{ uv_version \}\}'
require_text "$skill_template" 'uv init'

printf 'PASS bundled Ansible runtime contract\n'
