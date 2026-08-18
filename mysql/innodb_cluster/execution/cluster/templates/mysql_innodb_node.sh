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

log() {
  echo "[$(date -Is)] $*"
}

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

log "Configuring MySQL for InnoDB Cluster..."
cat >/etc/mysql/mysql.conf.d/zz-innodb-cluster.cnf <<EOF
[mysqld]
datadir = /data/mysql
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
chmod 0644 /etc/mysql/mysql.conf.d/zz-innodb-cluster.cnf

if [ ! -f /var/log/mysql-innodb-node-ready ]; then
  systemctl stop mysql
  rm -f /data/mysql/auto.cnf
fi

systemctl restart mysql
until mysqladmin ping --silent >/dev/null 2>&1; do
  log "Waiting for local MySQL..."
  sleep 2
done

actual_server_id="$(mysql -uroot -NBe 'SELECT @@server_id')"
actual_report_host="$(mysql -uroot -NBe 'SELECT @@report_host')"
if [ "$actual_server_id" != "$SERVER_ID" ] || [ "$actual_report_host" != "$NODE_HOSTNAME" ]; then
  log "MySQL did not load the InnoDB Cluster configuration: server_id=$actual_server_id report_host=$actual_report_host"
  exit 1
fi

password_sql="$(sql_escape "$MYSQL_ADMIN_PASSWORD")"
mysql -uroot <<EOF
CREATE USER IF NOT EXISTS '$MYSQL_ADMIN_USERNAME'@'%' IDENTIFIED BY '$password_sql';
ALTER USER '$MYSQL_ADMIN_USERNAME'@'%' IDENTIFIED BY '$password_sql';
GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_ADMIN_USERNAME'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

touch /var/log/mysql-innodb-node-ready
log "MySQL node setup complete."
