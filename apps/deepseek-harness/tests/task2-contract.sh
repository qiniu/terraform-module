#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

extract_simple_block() {
  local file="$1"
  local kind="$2"
  local name="${3:-}"

  awk -v kind="$kind" -v name="$name" '
    BEGIN { found = 0; complete = 0 }
    !found {
      if (name == "" && $0 ~ "^[[:space:]]*" kind "[[:space:]]*\\{") {
        found = 1
      } else if (name != "" && $0 ~ "^[[:space:]]*" kind "[[:space:]]+\"" name "\"[[:space:]]*\\{") {
        found = 1
      }
    }
    found {
      print
      if ($0 ~ "^[[:space:]]*}[[:space:]]*$") {
        complete = 1
        exit
      }
    }
    END { if (!found || !complete) exit 1 }
  ' "$file"
}

extract_template_vars() {
  local file="$1"

  awk '
    BEGIN { found = 0; complete = 0 }
    /^[[:space:]]*install_command[[:space:]]*=[[:space:]]*templatefile\([^,]+,[[:space:]]*\{[[:space:]]*$/ {
      if (found) exit 1
      found = 1
      next
    }
    found && /^[[:space:]]*}\)[[:space:]]*$/ {
      complete = 1
      exit
    }
    found { print }
    END { if (!found || !complete) exit 1 }
  ' "$file"
}

require_assignment() {
  local block="$1"
  local field="$2"
  local rhs="$3"
  local description="$4"

  if ! grep -Eq "^[[:space:]]*${field}[[:space:]]*=[[:space:]]*${rhs}[[:space:]]*$" <<<"$block"; then
    printf 'missing exact contract: %s\n' "$description" >&2
    return 1
  fi
}

require_text() {
  local text="$1"
  local expected="$2"
  local description="$3"

  if ! grep -Fq "$expected" <<<"$text"; then
    printf 'missing documentation contract: %s\n' "$description" >&2
    return 1
  fi
}

extract_yaml_step() {
  local file="$1"
  local name="$2"

  awk -v name="$name" '
    BEGIN { found = 0 }
    /^[[:space:]]*-[[:space:]]+name:[[:space:]]*/ {
      if (found) exit
      if ($0 ~ "name:[[:space:]]*" name "[[:space:]]*$") found = 1
    }
    found { print }
    END { if (!found) exit 1 }
  ' "$file"
}

require_yaml_step() {
  local file="$1"
  local name="$2"
  local step

  step="$(extract_yaml_step "$file" "$name")" || {
    printf 'missing workflow step: %s\n' "$name" >&2
    exit 1
  }
  printf '%s\n' "$step"
}

require_regex() {
  local text="$1"
  local expression="$2"
  local description="$3"

  if ! grep -Eq "$expression" <<<"$text"; then
    printf 'missing contract: %s\n' "$description" >&2
    return 1
  fi
}

root_main="$repo_dir/main.tf"
installer_main="$repo_dir/modules/installer/main.tf"
workflow_file="$repo_dir/../../.github/workflows/deepseek-harness-test.yml"

locals_block="$(extract_simple_block "$root_main" locals)"
infrastructure_block="$(extract_simple_block "$root_main" module infrastructure)"
installer_block="$(extract_simple_block "$root_main" module installer)"
template_vars="$(extract_template_vars "$installer_main")"

require_assignment "$locals_block" 'preview_ports' '\[30080, 30081, 30082, 30083\]' 'root local.preview_ports'
require_assignment "$locals_block" 'code_server_port' '3086' 'root local.code_server_port = 3086'
require_assignment "$locals_block" 'code_server_proxy_port' '3087' 'root local.code_server_proxy_port = 3087'
require_assignment "$infrastructure_block" 'preview_count' 'var\.preview_count' 'infrastructure receives preview_count'
require_assignment "$infrastructure_block" 'code_server_proxy_port' 'local\.code_server_proxy_port' 'infrastructure receives local.code_server_proxy_port'
require_assignment "$installer_block" 'preview_count' 'var\.preview_count' 'installer receives preview_count'
require_assignment "$installer_block" 'preview_ports' 'local\.preview_ports' 'installer receives preview ports'
require_assignment "$installer_block" 'preview_public_authorities' 'module\.infrastructure\.preview_public_authorities' 'installer directly receives preview authorities'
require_assignment "$installer_block" 'code_server_port' 'local\.code_server_port' 'installer receives local.code_server_port'
require_assignment "$installer_block" 'code_server_proxy_port' 'local\.code_server_proxy_port' 'installer receives local.code_server_proxy_port'
require_assignment "$installer_block" 'code_server_public_authority' 'module\.infrastructure\.code_server_public_authority' 'installer receives infrastructure code-server authority'
require_assignment "$template_vars" 'preview_count' 'var\.preview_count' 'templatefile receives var.preview_count'
require_assignment "$template_vars" 'preview_ports' 'var\.preview_ports' 'templatefile receives var.preview_ports'
require_assignment "$template_vars" 'preview_public_authorities' 'var\.preview_public_authorities' 'templatefile receives var.preview_public_authorities'
require_assignment "$template_vars" 'code_server_version' 'var\.code_server_version' 'templatefile receives var.code_server_version'
require_assignment "$template_vars" 'code_server_port' 'var\.code_server_port' 'templatefile receives var.code_server_port'
require_assignment "$template_vars" 'code_server_proxy_port' 'var\.code_server_proxy_port' 'templatefile receives var.code_server_proxy_port'
require_assignment "$template_vars" 'code_server_public_authority' 'var\.code_server_public_authority' 'templatefile receives var.code_server_public_authority'
require_assignment "$template_vars" 'code_server_password_base64' 'base64encode\(var\.code_server_password\)' 'templatefile receives encoded code-server password'

workflow_text="$(<"$workflow_file")"
require_text "$workflow_text" "'apps/deepseek-harness/**'" 'workflow triggers on DeepSeek Harness changes'

wiring_step="$(require_yaml_step "$workflow_file" 'Test module wiring contracts')"
skill_step="$(require_yaml_step "$workflow_file" 'Test LAS DSH skill installer')"
nginx_step="$(require_yaml_step "$workflow_file" 'Test offline Nginx configuration transaction')"
code_server_step="$(require_yaml_step "$workflow_file" 'Test code-server installer contract')"
ansible_step="$(require_yaml_step "$workflow_file" 'Test Ansible installer')"
require_regex "$wiring_step" '^[[:space:]]*run:[[:space:]]*bash[[:space:]]+apps/deepseek-harness/tests/task2-contract\.sh[[:space:]]*$' 'workflow runs module wiring contract script'
require_regex "$skill_step" '^[[:space:]]*run:[[:space:]]*bash[[:space:]]+apps/deepseek-harness/modules/installer/tests/las-dsh-environment-skill\.sh[[:space:]]*$' 'workflow runs las-dsh-environment skill test'
require_regex "$nginx_step" '^[[:space:]]*run:[[:space:]]*bash[[:space:]]+apps/deepseek-harness/modules/installer/tests/nginx-config\.sh[[:space:]]*$' 'workflow runs Nginx configuration test'
require_regex "$code_server_step" '^[[:space:]]*run:[[:space:]]*bash[[:space:]]+apps/deepseek-harness/modules/installer/tests/code-server-install\.sh[[:space:]]*$' 'workflow runs code-server installer test'
require_text "$ansible_step" 'bash tests/test-project.sh' 'workflow runs Ansible installer contract'
require_text "$ansible_step" 'ansible-playbook --syntax-check' 'workflow validates Ansible playbook syntax'

readme_file="$repo_dir/README.md"
outputs_file="$repo_dir/outputs.tf"
infrastructure_outputs_file="$repo_dir/modules/infrastructure/outputs.tf"
ignore_file="$repo_dir/.gitignore"
readme_text="$(<"$readme_file")"
infrastructure_outputs_text="$(<"$infrastructure_outputs_file")"
ignore_text="$(<"$ignore_file")"
preview_output="$(extract_simple_block "$outputs_file" output preview_url)"
setup_guide_output="$(extract_simple_block "$outputs_file" output setup_guide)"

require_text "$readme_text" 'terraform output -json preview_urls' 'README shows how to read preview_urls'
require_text "$readme_text" 'terraform output -raw code_server_url' 'README shows how to read code-server URL'
require_text "$readme_text" 'code_server_password' 'README identifies code-server password output'
require_text "$readme_text" 'code-server 自带密码' 'README explains code-server authentication'
require_text "$readme_text" '127.0.0.1:3086' 'README documents the code-server loopback port'
require_text "$readme_text" '127.0.0.1:30080' 'README requires the loopback preview listener'
require_text "$readme_text" '502' 'README explains the expected no-upstream response'
require_text "$readme_text" '503' 'README explains alternate HTTPProxy no-upstream response'
require_text "$readme_text" '正常状态' 'README identifies 502 as expected'
require_text "$readme_text" '公开' 'README states that preview is public'
require_text "$readme_text" '任何知道该地址的人都可以访问' 'README states that preview is publicly reachable'
require_text "$readme_text" '不需要 Harness 的 Basic Auth' 'README states that preview does not require Harness Basic Auth'
require_text "$readme_text" '/home/dsh/.agents/skills/las-dsh-environment/SKILL.md' 'README documents the user las-dsh-environment skill path'
require_text "$readme_text" '项目级' 'README explains project skill precedence'
require_text "$readme_text" '遮蔽' 'README explains project skill shadowing'
require_text "$readme_text" '新会话' 'README explains when updated skill text is visible'
require_text "$readme_text" '再次加载' 'README explains reloading updated skill text'
require_text "$readme_text" '页面或日志' 'README prohibits sensitive data in pages and logs'
require_text "$readme_text" '密码' 'README prohibits passwords in pages and logs'
require_text "$readme_text" '令牌' 'README prohibits tokens in pages and logs'
require_text "$readme_text" '私钥' 'README prohibits private keys in pages and logs'
require_text "$infrastructure_outputs_text" 'try(qiniu_compute_instance_public_access.preview[0].endpoint, null)' 'zero-preview compatibility authority output is safe'
require_text "$infrastructure_outputs_text" 'try("https://${qiniu_compute_instance_public_access.preview[0].endpoint}", null)' 'zero-preview compatibility URL output is safe'
require_text "$ignore_text" '__pycache__/' 'DeepSeek Harness ignores Python bytecode directories'
require_text "$ignore_text" '.playwright-cli/' 'DeepSeek Harness ignores Playwright run records'
if grep -Eq '^[[:space:]]*sensitive[[:space:]]*=' <<<"$preview_output"; then
  echo 'preview_url must not be marked sensitive' >&2
  exit 1
fi
require_text "$setup_guide_output" 'preview_url' 'setup_guide identifies the preview output'
require_text "$setup_guide_output" '公开' 'setup_guide states that preview is public'
require_text "$setup_guide_output" '不适用 Harness Basic Auth' 'setup_guide states that preview does not require Harness Basic Auth'
require_text "$setup_guide_output" '127.0.0.1:30080' 'setup_guide identifies the loopback preview listener'
require_text "$setup_guide_output" '502' 'setup_guide explains the expected no-upstream response'
require_text "$setup_guide_output" '正常状态' 'setup_guide identifies 502 as expected'
require_text "$setup_guide_output" '页面或日志' 'setup_guide prohibits sensitive data in pages and logs'
require_text "$setup_guide_output" '密码' 'setup_guide prohibits passwords in pages and logs'
require_text "$setup_guide_output" '令牌' 'setup_guide prohibits tokens in pages and logs'
require_text "$setup_guide_output" '私钥' 'setup_guide prohibits private keys in pages and logs'
