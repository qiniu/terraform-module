#!/bin/bash
set -euo pipefail
set +x

exec > >(tee -a /var/log/mysql-router-bootstrap.log) 2>&1

BOOTSTRAP_HOSTNAME='${bootstrap_hostname}'
MYSQL_ADMIN_USERNAME='${mysql_admin_username}'
MYSQL_ADMIN_PASSWORD="$(printf '%s' '${mysql_admin_password_b64}' | base64 -d)"

log() {
  echo "[$(date -Is)] $*"
}

id mysqlrouter >/dev/null 2>&1 || useradd --system --home /var/lib/mysqlrouter --create-home --shell /usr/sbin/nologin mysqlrouter
install -d -o mysqlrouter -g mysqlrouter -m 0750 /var/lib/mysqlrouter /var/log/mysqlrouter /etc/mysqlrouter
systemctl stop mysqlrouter >/dev/null 2>&1 || true

waited=0
until printf '%s\n%s\n' "$MYSQL_ADMIN_PASSWORD" "$MYSQL_ADMIN_PASSWORD" | \
  mysqlrouter --bootstrap "$MYSQL_ADMIN_USERNAME@$BOOTSTRAP_HOSTNAME:3306" --user=mysqlrouter --force; do
  if [ "$waited" -ge 900 ]; then
    log "Timed out bootstrapping MySQL Router against $BOOTSTRAP_HOSTNAME"
    exit 1
  fi
  log "Waiting for MySQL Router bootstrap metadata..."
  rm -rf /var/lib/mysqlrouter/.mysqlrouter
  sleep 10
  waited=$((waited + 10))
done

chown -R mysqlrouter:mysqlrouter /var/lib/mysqlrouter /var/log/mysqlrouter /etc/mysqlrouter
cat >/etc/systemd/system/mysqlrouter.service <<'EOF'
[Unit]
Description=MySQL Router
After=network-online.target mysql.service
Wants=network-online.target

[Service]
Type=simple
User=mysqlrouter
Group=mysqlrouter
ExecStart=/usr/bin/mysqlrouter -c /etc/mysqlrouter/mysqlrouter.conf
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable mysqlrouter
systemctl restart mysqlrouter
touch /var/log/mysql-router-ready
