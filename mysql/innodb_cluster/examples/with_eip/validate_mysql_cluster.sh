#!/bin/bash
set -euo pipefail
set +x

BOOTSTRAP_HOSTNAME='${bootstrap_hostname}'
MYSQL_NODE_COUNT=${mysql_node_count}
MYSQL_USER='${mysql_admin_username}'
MYSQL_PASSWORD="$(printf '%s' '${mysql_admin_password_b64}' | base64 -d)"

log() { echo "[$(date -Is)] $*"; }

mysql_query() {
  local port="$1" query="$2"
  MYSQL_PWD="$MYSQL_PASSWORD" mysql --connect-timeout=10 --batch --raw --skip-column-names \
    -h 127.0.0.1 -P "$port" -u "$MYSQL_USER" -e "$query"
}

wait_for_query() {
  local port="$1" query="$2" timeout_seconds="$3" waited=0
  until mysql_query "$port" "$query" >/dev/null 2>&1; do
    [ "$waited" -lt "$timeout_seconds" ] || { log "Timed out waiting for Router port $port"; return 1; }
    sleep 5
    waited=$((waited + 5))
  done
}

restore_mysql() { systemctl start mysql >/dev/null 2>&1 || true; }

wait_for_query 6446 "SELECT 1" 900
wait_for_query 6447 "SELECT 1" 900

primary_before="$(mysql_query 6446 "SELECT MEMBER_HOST FROM performance_schema.replication_group_members WHERE MEMBER_ROLE = 'PRIMARY' LIMIT 1;")"
[ "$primary_before" = "$BOOTSTRAP_HOSTNAME" ] || { log "Unexpected initial primary: $primary_before"; exit 1; }

run_id="$(date +%s)"
mysql_query 6446 "CREATE DATABASE IF NOT EXISTS mysql_ha_validation; CREATE TABLE IF NOT EXISTS mysql_ha_validation.validation_rows (id BIGINT PRIMARY KEY, note VARCHAR(64) NOT NULL) ENGINE=InnoDB; REPLACE INTO mysql_ha_validation.validation_rows (id, note) VALUES ($run_id, 'before-failover');" >/dev/null
[ "$(mysql_query 6447 "SELECT COUNT(*) FROM mysql_ha_validation.validation_rows WHERE id = $run_id;")" = "1" ] || { log "Read-only Router did not return the validation row"; exit 1; }

trap restore_mysql EXIT
systemctl stop mysql
new_primary=""
for _ in $(seq 1 90); do
  if mysql_query 6446 "REPLACE INTO mysql_ha_validation.validation_rows (id, note) VALUES (999999, 'after-failover');" >/dev/null 2>&1; then
    new_primary="$(mysql_query 6446 "SELECT MEMBER_HOST FROM performance_schema.replication_group_members WHERE MEMBER_ROLE = 'PRIMARY' LIMIT 1;" || true)"
    [ -n "$new_primary" ] && [ "$new_primary" != "$BOOTSTRAP_HOSTNAME" ] && break
  fi
  sleep 5
done
[ -n "$new_primary" ] && [ "$new_primary" != "$BOOTSTRAP_HOSTNAME" ] || { log "Primary did not fail over"; exit 1; }
[ "$(mysql_query 6447 "SELECT COUNT(*) FROM mysql_ha_validation.validation_rows WHERE id = 999999;")" = "1" ] || { log "Read-only Router did not return the post-failover row"; exit 1; }

restore_mysql
trap - EXIT
for _ in $(seq 1 90); do
  online_count="$(mysql_query 6446 "SELECT COUNT(*) FROM performance_schema.replication_group_members WHERE MEMBER_STATE = 'ONLINE';" || true)"
  [ "$online_count" = "$MYSQL_NODE_COUNT" ] && { log "VALIDATION PASSED"; exit 0; }
  sleep 5
done
log "Original primary did not rejoin the cluster"
exit 1
