#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../../.." && pwd)"
template="$repo_root/apps/deepseek-harness/modules/installer/templates/install.sh.tftpl"
helper="${NGINX_TRANSACTION_HELPER:-$repo_root/apps/deepseek-harness/modules/installer/templates/nginx-transaction.sh}"

require() {
  local pattern="$1"
  local message="$2"
  if ! grep -Eq "$pattern" "$template"; then
    echo "missing: $message" >&2
    exit 1
  fi
}

if grep -Eq 'preview_proxy_port|preview_port|listen 0\.0\.0\.0:\$\{preview' "$template"; then
  echo 'Preview must not be rendered through Nginx' >&2
  exit 1
fi
require 'map \$http_upgrade \$connection_upgrade' 'conditional upgrade map'
require 'proxy_set_header Connection \$connection_upgrade' 'conditional Connection header'
require 'proxy_set_header X-Forwarded-Host \$http_x_forwarded_host' 'preserved forwarded host'
require 'proxy_set_header X-Forwarded-Proto \$http_x_forwarded_proto' 'preserved forwarded protocol'
require 'proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for' 'forwarded chain'
require 'proxy_buffering off' 'unbuffered proxying'
require 'proxy_read_timeout 3600s' 'long read timeout'
require 'auth_basic "DeepSeek Harness"' 'Harness authentication'
require 'source "\$nginx_transaction_helper"' 'sourceable transaction helper'
grep -q 'commit_nginx_candidate()' "$helper"
grep -q 'snapshot_nginx_candidate' "$helper"
grep -q 'restore_nginx_candidate' "$helper"
grep -q 'nginx_test || return 1' "$helper"
grep -q 'nginx_systemctl reload nginx' "$helper"
grep -q 'nginx_systemctl restart nginx' "$helper"
grep -q 'install_nginx_candidate_file()' "$helper"
grep -q 'mktemp "\$nginx_candidate_dir/.deepseek-harness.XXXXXX"' "$helper"
grep -q 'mv -f "\$nginx_candidate_tmp" "\$nginx_candidate_dest"' "$helper"
require 'listen 0\.0\.0\.0:\$\{code_server_proxy_port\}' 'code-server listener'
require 'proxy_pass http://127\.0\.0\.1:\$\{code_server_port\}' 'code-server upstream'
require 'proxy_set_header Authorization ""' 'code-server authorization isolation'
require 'proxy_set_header Host \$\{code_server_public_authority\}' 'code-server fixed Host'
require 'code_server_proxy_http_code=' 'code-server health check'

# Model the installer transaction with an injectable nginx -t command.  These
# cases exercise the two states that are easy to lose during rollback: an
# absent old file/link and a link which used to point somewhere else.
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
snapshot() {
  local source="$1" name="$2"
  if [ -L "$source" ]; then printf '%s\n' symlink > "$fixture_dir/$name.kind"; readlink "$source" > "$fixture_dir/$name.target"
  elif [ -e "$source" ]; then printf '%s\n' file > "$fixture_dir/$name.kind"; cp -a "$source" "$fixture_dir/$name.file"
  else printf '%s\n' absent > "$fixture_dir/$name.kind"; fi
}
restore() {
  local target="$1" name="$2"
  rm -f "$target"
  case "$(cat "$fixture_dir/$name.kind")" in
    absent) ;;
    file) cp -a "$fixture_dir/$name.file" "$target" ;;
    symlink) ln -s "$(cat "$fixture_dir/$name.target")" "$target" ;;
  esac
}
mock_nginx_test_calls=0
mock_nginx_test() { mock_nginx_test_calls=$((mock_nginx_test_calls + 1)); return 1; }
candidate="$fixture_dir/candidate"
enabled="$fixture_dir/enabled"
snapshot "$candidate" candidate
snapshot "$enabled" enabled
printf 'new candidate\n' > "$candidate"
ln -s "$candidate" "$enabled"
if ! mock_nginx_test; then
  restore "$candidate" candidate
  restore "$enabled" enabled
  ! mock_nginx_test
fi
test ! -e "$candidate" && test ! -L "$candidate"
test ! -e "$enabled" && test ! -L "$enabled"
test "$mock_nginx_test_calls" -eq 2

ln -s /old/nginx-target "$enabled"
snapshot "$enabled" old-link
rm -f "$enabled"
ln -s /new/nginx-target "$enabled"
restore "$enabled" old-link
test "$(readlink "$enabled")" = /old/nginx-target

# Exercise the production helper itself with injected commands and a temporary
# filesystem.  The failing nginx test forces its real rollback path.
helper_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir" "$helper_dir"' EXIT
nginx_backup_dir="$helper_dir/backup"; mkdir "$nginx_backup_dir"
nginx_auth_dest="$helper_dir/auth"; nginx_config_dest="$helper_dir/config"; nginx_enabled_dest="$helper_dir/enabled"
auth_tmp="$helper_dir/auth.new"; nginx_tmp="$helper_dir/config.new"
printf old > "$nginx_auth_dest"; printf old > "$nginx_config_dest"; ln -s /old-target "$nginx_enabled_dest"
printf new > "$auth_tmp"; printf new > "$nginx_tmp"
install() {
  [ "${INSTALL_FAIL:-false}" = true ] && return 1
  cp "${@: -2:1}" "${@: -1}"
}
mock_bin="$helper_dir/mock"
printf '#!/usr/bin/env bash\nexit 1\n' > "$mock_bin"; chmod +x "$mock_bin"
source "$helper"
NGINX_BIN="$mock_bin"; SYSTEMCTL_BIN=true
if commit_nginx_candidate; then echo 'expected candidate validation failure' >&2; exit 1; fi
test "$(cat "$nginx_auth_dest")" = old && test "$(cat "$nginx_config_dest")" = old
test "$(readlink "$nginx_enabled_dest")" = /old-target

# A candidate file installation failure must fail the transaction and restore
# every previously committed path.
printf old > "$nginx_auth_dest"; printf old > "$nginx_config_dest"; rm -f "$nginx_enabled_dest"; ln -s /old-target "$nginx_enabled_dest"
INSTALL_FAIL=true NGINX_BIN=true SYSTEMCTL_BIN=true
if commit_nginx_candidate; then echo 'expected candidate install failure' >&2; exit 1; fi
test "$(cat "$nginx_auth_dest")" = old && test "$(cat "$nginx_config_dest")" = old
test "$(readlink "$nginx_enabled_dest")" = /old-target
INSTALL_FAIL=false

# Drive the production commit helper's service state machine, rather than a
# second model.  The mock records the real calls made by commit_nginx_candidate.
mock_log="$helper_dir/systemctl.log"
MOCK_LOG="$mock_log"
systemctl_mock="$helper_dir/systemctl"
cat > "$systemctl_mock" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LOG"
if [ "$1" = is-active ]; then [ "${MOCK_ACTIVE:-false}" = true ]; fi
MOCK
chmod +x "$systemctl_mock"
printf '#!/usr/bin/env bash\nexit 0\n' > "$mock_bin"; chmod +x "$mock_bin"
NGINX_BIN="$mock_bin"; SYSTEMCTL_BIN="$systemctl_mock"; export MOCK_LOG
run_commit_case() {
  local active="$1" changed="$2"
  : > "$mock_log"
  rm -rf "$nginx_backup_dir"; mkdir "$nginx_backup_dir"
  rm -f "$nginx_auth_dest" "$nginx_config_dest" "$nginx_enabled_dest"
  printf old > "$nginx_auth_dest"; printf old > "$nginx_config_dest"; ln -s "$nginx_config_dest" "$nginx_enabled_dest"
  if [ "$changed" = true ]; then printf new > "$auth_tmp"; printf new > "$nginx_tmp"; else printf old > "$auth_tmp"; printf old > "$nginx_tmp"; fi
  MOCK_ACTIVE="$active" commit_nginx_candidate
}
run_commit_case true true
grep -qx 'reload nginx' "$mock_log"
run_commit_case false false
grep -qx 'restart nginx' "$mock_log"
run_commit_case true false
if grep -Eq '^(reload|restart) nginx$' "$mock_log"; then
  echo 'active unchanged candidate must not reload or restart nginx' >&2
  exit 1
fi

echo "nginx config contract and mocked transition checks passed"
