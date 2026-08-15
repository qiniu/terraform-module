#!/usr/bin/env bash
set -euo pipefail

tmp_dir="$(mktemp -d)"
upstream_pid=""
nginx_pid=""
cleanup() {
  [ -n "$nginx_pid" ] && kill "$nginx_pid" 2>/dev/null || true
  [ -n "$upstream_pid" ] && kill "$upstream_pid" 2>/dev/null || true
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

upstream_port=13001
proxy_port=30822
headers_file="$tmp_dir/headers"
repo_root="$(cd "$(dirname "$0")/../../../../.." && pwd)"
installer_template="${INSTALLER_TEMPLATE:-$repo_root/apps/deepseek-harness/modules/installer/templates/install.sh.tftpl}"
mkdir -p "$tmp_dir/logs"

python3 - "$upstream_port" "$headers_file" <<'PY' &
import socketserver, sys
port, output = int(sys.argv[1]), sys.argv[2]
class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        request = self.rfile.readline().decode('iso-8859-1')
        headers = {}
        while True:
            line = self.rfile.readline().decode('iso-8859-1').strip('\r\n')
            if not line: break
            key, value = line.split(':', 1)
            headers[key.lower()] = value.strip()
        if request.startswith('GET /__ready__ '):
            self.wfile.write(b'HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n')
            return
        with open(output, 'a', encoding='utf-8') as f:
            f.write('|'.join('%s=%s' % (k, headers.get(k, '')) for k in ('authorization','host','origin','sec-fetch-site','upgrade','connection')) + '\n')
        if headers.get('upgrade', '').lower() == 'websocket':
            self.wfile.write(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')
        else:
            self.wfile.write(b'HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n')
class Server(socketserver.ThreadingTCPServer): allow_reuse_address = True
Server(('127.0.0.1', port), Handler).serve_forever()
PY
upstream_pid="$!"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if python3 - "$upstream_port" <<'PY'
import socket, sys
with socket.create_connection(('127.0.0.1', int(sys.argv[1])), timeout=1) as sock:
    sock.sendall(b'GET /__ready__ HTTP/1.0\r\nHost: readiness\r\n\r\n')
    sock.recv(128)
PY
  then
    break
  fi
  sleep 0.1
done
python3 - "$upstream_port" <<'PY'
import socket, sys
with socket.create_connection(('127.0.0.1', int(sys.argv[1])), timeout=3) as sock:
    sock.sendall(b'GET /__ready__ HTTP/1.0\r\nHost: readiness\r\n\r\n')
    sock.recv(128)
PY
: > "$headers_file"

# Keep the runtime test tied to the actual installer configuration.  Extract
# exactly its NGINX_CONFIG heredoc, then substitute only isolated test ports.
{
  printf 'events {}\nhttp {\n'
  awk '/^map_hash_bucket_size 512;/{copy=1} copy && /^NGINX_CONFIG$/{exit} copy { print }' "$installer_template" |
    awk -v dsh_port="$upstream_port" -v proxy_port="$proxy_port" '
      { gsub(/\$\{proxy_port\}/, proxy_port); gsub(/\$\{dsh_port\}/, dsh_port); gsub(/\$\{public_authority\}/, "harness.runtime.test"); print }
    '
  printf '}\n'
} > "$tmp_dir/nginx.conf"
grep -q 'proxy_set_header Connection \$connection_upgrade' "$tmp_dir/nginx.conf"
if [ "${NGINX_RUNTIME_VALIDATE_CONFIG_ONLY:-}" = 1 ]; then
  echo "rendered Preview configuration extraction passed"
  exit 0
fi
if ! command -v nginx >/dev/null 2>&1; then
  echo "nginx is required for this runtime test (run it on the Qiniu VM)" >&2
  exit 77
fi
nginx -p "$tmp_dir" -c nginx.conf -g "pid $tmp_dir/logs/nginx.pid;"
nginx_pid="$(cat "$tmp_dir/logs/nginx.pid")"
curl --silent --show-error --max-time 3 -H 'Authorization: Basic should-not-pass' "http://127.0.0.1:$proxy_port/" >/dev/null
python3 - "$proxy_port" <<'PY'
import socket, sys
s = socket.create_connection(('127.0.0.1', int(sys.argv[1])), timeout=3)
s.sendall(b'GET /ws HTTP/1.1\r\nHost: test\r\nAuthorization: Bearer should-not-pass\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n')
assert b' 101 ' in s.recv(1024)
PY

for _ in 1 2 3 4 5; do [ "$(wc -l < "$headers_file" 2>/dev/null || true)" -eq 2 ] && break; sleep 1; done
test "$(wc -l < "$headers_file")" -eq 2
grep -Ex 'authorization=\|host=127\.0\.0\.1:13001\|origin=http://127\.0\.0\.1:13001\|sec-fetch-site=same-origin\|upgrade=\|connection=close' "$headers_file"
grep -Ex 'authorization=\|host=127\.0\.0\.1:13001\|origin=http://127\.0\.0\.1:13001\|sec-fetch-site=same-origin\|upgrade=websocket\|connection=upgrade' "$headers_file"
echo "nginx runtime HTTP and WebSocket header checks passed"
