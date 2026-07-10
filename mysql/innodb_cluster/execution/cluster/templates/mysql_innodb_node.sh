#!/bin/bash
set -euo pipefail
set +x

exec > >(tee -a /var/log/mysql-innodb-node-setup.log) 2>&1

SERVER_ID=${server_id}
NODE_HOSTNAME='${node_hostname}'
BOOTSTRAP_HOSTNAME='${bootstrap_hostname}'
GROUP_REPLICATION_UUID='${group_replication_uuid}'
MYSQL_ADMIN_USERNAME='${mysql_admin_username}'
MYSQL_ADMIN_PASSWORD="$(printf '%s' '${mysql_admin_password_b64}' | base64 -d)"
INSTALL_MYSQL_ROUTER='${install_mysql_router}'

log() {
  echo "[$(date -Is)] $*"
}

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

missing_packages=()
if ! command -v mysql >/dev/null 2>&1 || ! command -v mysqld >/dev/null 2>&1; then
  missing_packages+=(mysql-client-8.0 mysql-server-8.0)
fi
command -v mysqlsh >/dev/null 2>&1 || missing_packages+=(mysql-shell)
if [ "$INSTALL_MYSQL_ROUTER" = "true" ] && ! command -v mysqlrouter >/dev/null 2>&1; then
  missing_packages+=(mysql-router)
fi

if [ "$${#missing_packages[@]}" -gt 0 ]; then
  log "Installing missing MySQL packages..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$${missing_packages[@]}"
else
  log "Required MySQL packages are already installed."
fi

log "Configuring MySQL for InnoDB Cluster..."
cat >/etc/mysql/mysql.conf.d/zz-innodb-cluster.cnf <<EOF
[mysqld]
server_id = $SERVER_ID
bind-address = 0.0.0.0
mysqlx-bind-address = 0.0.0.0
report_host = $NODE_HOSTNAME
report_port = 3306
log_bin = mysql-bin
binlog_format = ROW
gtid_mode = ON
enforce_gtid_consistency = ON
binlog_transaction_dependency_tracking = WRITESET
master_info_repository = TABLE
relay_log_info_repository = TABLE
log_slave_updates = ON
disabled_storage_engines = MyISAM,BLACKHOLE,FEDERATED,ARCHIVE,MEMORY
loose-plugin_load_add = group_replication.so
loose-group_replication_group_name = "$GROUP_REPLICATION_UUID"
loose-group_replication_start_on_boot = OFF
loose-group_replication_local_address = "$NODE_HOSTNAME:33061"
loose-group_replication_group_seeds = "$BOOTSTRAP_HOSTNAME:33061"
loose-group_replication_bootstrap_group = OFF
EOF

systemctl restart mysql
until mysqladmin ping --silent >/dev/null 2>&1; do
  log "Waiting for local MySQL..."
  sleep 2
done

password_sql="$(sql_escape "$MYSQL_ADMIN_PASSWORD")"
mysql -uroot <<EOF
CREATE USER IF NOT EXISTS '$MYSQL_ADMIN_USERNAME'@'%' IDENTIFIED BY '$password_sql';
ALTER USER '$MYSQL_ADMIN_USERNAME'@'%' IDENTIFIED BY '$password_sql';
GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_ADMIN_USERNAME'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

touch /var/log/mysql-innodb-node-ready
log "MySQL node setup complete."
