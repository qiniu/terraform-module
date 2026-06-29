#!/bin/bash
set +x
set -euo pipefail

exec > >(tee -a /var/log/mysql-innodb-init.log) 2>&1

NODE_INDEX=${node_index}
SERVER_ID=${server_id}
NODE_HOSTNAME='${node_hostname}'
BOOTSTRAP_HOSTNAME='${bootstrap_hostname}'
MEMBER_HOSTS=(${member_hostnames})
GROUP_REPLICATION_UUID='${group_replication_uuid}'
GROUP_SEEDS='${group_seeds}'
MYSQL_ADMIN_USERNAME='${mysql_admin_username}'
MYSQL_ADMIN_PASSWORD="$(printf '%s' '${mysql_admin_password_b64}' | base64 -d)"
INSTALL_MYSQL_ROUTER='${install_mysql_router}'

log() {
  echo "[$(date -Is)] $*"
}

sql_escape() {
  printf "%s" "$1" | sed "s/'/''/g"
}

wait_for_tcp() {
  local host="$1"
  local port="$2"
  local timeout_seconds="$3"
  local waited=0

  until nc -z "$host" "$port" >/dev/null 2>&1; do
    if [ "$waited" -ge "$timeout_seconds" ]; then
      log "Timed out waiting for $host:$port"
      return 1
    fi
    log "Waiting for $host:$port..."
    sleep 5
    waited=$((waited + 5))
  done
}

wait_for_hostname() {
  local host="$1"
  local timeout_seconds="$2"
  local waited=0

  until getent hosts "$host" >/dev/null; do
    if [ "$waited" -ge "$timeout_seconds" ]; then
      log "Timed out waiting for hostname $host"
      return 1
    fi
    log "Waiting for hostname $host..."
    sleep 5
    waited=$((waited + 5))
  done
}

wait_for_mysql_login() {
  local host="$1"
  local timeout_seconds="$2"
  local waited=0

  until mysqladmin ping -h "$host" -u"$MYSQL_ADMIN_USERNAME" -p"$MYSQL_ADMIN_PASSWORD" --silent >/dev/null 2>&1; do
    if [ "$waited" -ge "$timeout_seconds" ]; then
      log "Timed out waiting for MySQL login on $host"
      return 1
    fi
    log "Waiting for MySQL admin login on $host..."
    sleep 5
    waited=$((waited + 5))
  done
}

install_packages() {
  log "Installing MySQL packages if needed..."
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    mysql-client-8.0 \
    mysql-server-8.0 \
    mysql-shell \
    netcat-openbsd

  if [ "$INSTALL_MYSQL_ROUTER" = "true" ]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-router
  fi
}

configure_mysql() {
  log "Configuring MySQL for InnoDB Cluster..."
  rm -f /etc/mysql/mysql.conf.d/innodb-cluster.cnf
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
loose-group_replication_group_seeds = "$GROUP_SEEDS"
loose-group_replication_bootstrap_group = OFF
EOF

  rm -f /var/lib/mysql/auto.cnf
  systemctl restart mysql
  until mysqladmin ping --silent >/dev/null 2>&1; do
    log "Waiting for local MySQL..."
    sleep 2
  done
}

configure_mysql_users() {
  log "Configuring MySQL administrator user..."
  local password_sql
  password_sql="$(sql_escape "$MYSQL_ADMIN_PASSWORD")"

  if mysql -uroot -e "SELECT 1" >/dev/null 2>&1; then
    MYSQL_ROOT_CMD=(mysql -uroot)
  else
    MYSQL_ROOT_CMD=(mysql -uroot -p"$MYSQL_ADMIN_PASSWORD")
  fi

  "$${MYSQL_ROOT_CMD[@]}" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$password_sql';
CREATE USER IF NOT EXISTS '$MYSQL_ADMIN_USERNAME'@'%' IDENTIFIED BY '$password_sql';
ALTER USER '$MYSQL_ADMIN_USERNAME'@'%' IDENTIFIED BY '$password_sql';
GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_ADMIN_USERNAME'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
RESET MASTER;
EOF
}

wait_for_cluster_members() {
  for host in "$${MEMBER_HOSTS[@]}"; do
    log "Checking cluster member hostname $host"
    wait_for_hostname "$host" 900
    wait_for_tcp "$host" 3306 900
    wait_for_mysql_login "$host" 900
  done
}

create_innodb_cluster() {
  log "Creating or reconciling InnoDB Cluster on $BOOTSTRAP_HOSTNAME..."
  cat >/tmp/innodb_cluster_bootstrap.py <<'EOF'
import json

cluster_name = ${cluster_name_json}
user = ${mysql_admin_username_js}
password = ${mysql_admin_password_js}
hosts = ${member_hostnames_json}


def call(obj, snake_name, camel_name, *args):
    method = getattr(obj, snake_name, None)
    if method is None:
        method = getattr(obj, camel_name)
    return method(*args)


def instance_config(host):
    return {
        "scheme": "mysql",
        "user": user,
        "password": password,
        "host": host,
        "port": 3306,
    }


shell.connect(instance_config(hosts[0]))

try:
    cluster = call(dba, "get_cluster", "getCluster", cluster_name)
    print("Found existing cluster " + cluster_name)
except Exception:
    print("Creating cluster " + cluster_name)
    cluster = call(dba, "create_cluster", "createCluster", cluster_name, {"memberSslMode": "REQUIRED"})

for host in hosts[1:]:
    member_key = host + ":3306"
    topology = cluster.status().get("defaultReplicaSet", {}).get("topology", {})
    if member_key in topology:
        print("Instance " + host + " is already in cluster; skipping")
        continue

    try:
        print("Adding instance " + host)
        call(cluster, "add_instance", "addInstance", instance_config(host), {"recoveryMethod": "clone", "interactive": False})
    except Exception as err:
        print("addInstance failed for " + host + ": " + str(err))
        try:
            print("Trying to rejoin instance " + host)
            call(cluster, "rejoin_instance", "rejoinInstance", instance_config(host))
        except Exception as rejoin_err:
            print("rejoinInstance failed for " + host + ": " + str(rejoin_err))
            raise

print(json.dumps(cluster.status(), indent=2))
EOF

  mysqlsh --py --file=/tmp/innodb_cluster_bootstrap.py
  touch /var/log/mysql-innodb-cluster-ready
}

wait_for_cluster_metadata() {
  local waited=0
  until mysql -h "$BOOTSTRAP_HOSTNAME" -u"$MYSQL_ADMIN_USERNAME" -p"$MYSQL_ADMIN_PASSWORD" \
    -N -e "SELECT COUNT(*) FROM mysql_innodb_cluster_metadata.clusters" >/dev/null 2>&1; do
    if [ "$waited" -ge 1200 ]; then
      log "Timed out waiting for InnoDB Cluster metadata"
      return 1
    fi
    log "Waiting for InnoDB Cluster metadata..."
    sleep 10
    waited=$((waited + 10))
  done
}

bootstrap_mysql_router() {
  if [ "$INSTALL_MYSQL_ROUTER" != "true" ]; then
    log "MySQL Router installation disabled."
    return
  fi

  log "Bootstrapping MySQL Router against $BOOTSTRAP_HOSTNAME..."
  id mysqlrouter >/dev/null 2>&1 || useradd --system --home /var/lib/mysqlrouter --create-home --shell /usr/sbin/nologin mysqlrouter
  install -d -o mysqlrouter -g mysqlrouter -m 0750 /var/lib/mysqlrouter /var/log/mysqlrouter /etc/mysqlrouter
  systemctl stop mysqlrouter >/dev/null 2>&1 || true

  local waited=0
  local bootstrap_timeout_seconds=900
  until printf '%s\n%s\n' "$MYSQL_ADMIN_PASSWORD" "$MYSQL_ADMIN_PASSWORD" | \
    mysqlrouter --bootstrap "$MYSQL_ADMIN_USERNAME@$BOOTSTRAP_HOSTNAME:3306" \
      --user=mysqlrouter \
      --force; do
    if [ "$waited" -ge "$bootstrap_timeout_seconds" ]; then
      log "Timed out bootstrapping MySQL Router against $BOOTSTRAP_HOSTNAME"
      return 1
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
}

install_packages
configure_mysql
configure_mysql_users
touch /var/log/mysql-innodb-node-ready

if [ "$NODE_INDEX" -eq 0 ]; then
  wait_for_cluster_members
  create_innodb_cluster
else
  wait_for_cluster_metadata
fi

bootstrap_mysql_router
log "MySQL InnoDB node initialization complete."
