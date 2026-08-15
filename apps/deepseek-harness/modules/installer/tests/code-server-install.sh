#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../../.." && pwd)"
template="$repo_root/apps/deepseek-harness/modules/installer/templates/install.sh.tftpl"

require() {
  local pattern="$1"
  local message="$2"
  if ! grep -Eq "$pattern" "$template"; then
    echo "missing: $message" >&2
    exit 1
  fi
}

require 'code-server-\$\{code_server_version\}-linux-amd64\.tar\.gz' 'amd64 release archive'
require 'code-server-\$\{code_server_version\}-linux-arm64\.tar\.gz' 'arm64 release archive'
require 'a38d26f4cb81f768feddff79e2937fd3f39c83d3da8be3da7225e1087e62e4ed' 'amd64 release checksum'
require 'ade569a677d1c04ee66ef153382b7e15bf261f955407663c7ddc6b87f9ee29fc' 'arm64 release checksum'
require 'sha256sum -c -' 'release checksum verification'
require 'tar --no-same-owner -xzf' 'safe release extraction'
require 'if ! mv "\$code_server_extract" "\$code_server_prefix"' 'failed install rollback'
require 'mv "\$code_server_prefix.old" "\$code_server_prefix"' 'restore old release'
require 'restore_code_server()' 'service failure rollback'
require 'code_server_previous_config' 'previous config backup'
require 'mv -Tf "\$code_server_link_tmp" /usr/local/bin/code-server' 'atomic executable switch'
require 'bind-addr: 127\.0\.0\.1:\$\{code_server_port\}' 'loopback config'
require 'password:.*code_server_password_decoded' 'quoted password config'
require 'install -o dsh -g dsh -m 0600' 'config ownership and mode'
require 'User=dsh' 'systemd user'
require 'ExecStart=/usr/local/bin/code-server --config' 'systemd config startup'
require 'listen 0\.0\.0\.0:\$\{code_server_proxy_port\}' 'proxy listener'
require 'proxy_pass http://127\.0\.0\.1:\$\{code_server_port\}' 'proxy upstream'
require 'proxy_set_header Authorization ""' 'proxy auth isolation'
require 'proxy_set_header Host \$\{code_server_public_authority\}' 'fixed proxy host'
require 'systemctl restart code-server\.service' 'independent service restart'
require 'code_server_proxy_http_code=' 'proxy health check'
require '401:401\|401:302\|302:401\|302:302' 'code-server unauthenticated health responses'

bash -n "$template"
echo 'code-server installer contract passed'
