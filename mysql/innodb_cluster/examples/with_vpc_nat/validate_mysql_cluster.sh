#!/bin/bash
set -euo pipefail

MYSQL_USER="${MYSQL_ADMIN_USERNAME:?MYSQL_ADMIN_USERNAME is required}"
MYSQL_PASSWORD="$(printf '%s' "${MYSQL_ADMIN_PASSWORD_B64:?MYSQL_ADMIN_PASSWORD_B64 is required}" | base64 -d)"
ROUTER_RW_ENDPOINTS=(${ROUTER_RW_ENDPOINTS:?ROUTER_RW_ENDPOINTS is required})
ROUTER_RO_ENDPOINTS=(${ROUTER_RO_ENDPOINTS:?ROUTER_RO_ENDPOINTS is required})
MYSQL_DIRECT_ENDPOINTS=(${MYSQL_DIRECT_ENDPOINTS:?MYSQL_DIRECT_ENDPOINTS is required})
MYSQL_NODE_HOSTNAMES=(${MYSQL_NODE_HOSTNAMES:?MYSQL_NODE_HOSTNAMES is required})
MYSQL_NODE_SSH_ENDPOINTS=(${MYSQL_NODE_SSH_ENDPOINTS:?MYSQL_NODE_SSH_ENDPOINTS is required})
MYSQL_INSTANCE_PASSWORDS_B64=(${MYSQL_INSTANCE_PASSWORDS:?MYSQL_INSTANCE_PASSWORDS is required})

MYSQL_IMAGE="${MYSQL_VALIDATION_IMAGE:-mysql:8.0}"
SSH_WAIT_TIMEOUT_SECONDS="${MYSQL_VALIDATION_SSH_TIMEOUT_SECONDS:-900}"
SSH_OPTIONS=(
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=10
)

log() {
  echo "[$(date -Is)] $*"
}

endpoint_host() {
  printf '%s' "$1" | cut -d: -f1
}

endpoint_port() {
  printf '%s' "$1" | cut -d: -f2
}

node_password() {
  local index="$1"
  printf '%s' "${MYSQL_INSTANCE_PASSWORDS_B64[$index]}" | base64 -d
}

ssh_node() {
  local index="$1"
  local command="$2"
  local endpoint="${MYSQL_NODE_SSH_ENDPOINTS[$index]}"
  local password

  password="$(node_password "$index")"
  SSHPASS="$password" sshpass -e ssh \
    "${SSH_OPTIONS[@]}" \
    -p "$(endpoint_port "$endpoint")" \
    "root@$(endpoint_host "$endpoint")" \
    "set +x; $command"
}

ssh_node_stdin() {
  local index="$1"
  local command="$2"
  local endpoint="${MYSQL_NODE_SSH_ENDPOINTS[$index]}"
  local password

  password="$(node_password "$index")"
  SSHPASS="$password" sshpass -e ssh \
    "${SSH_OPTIONS[@]}" \
    -p "$(endpoint_port "$endpoint")" \
    "root@$(endpoint_host "$endpoint")" \
    "set +x; $command"
}

wait_for_ssh_output() {
  local index="$1"
  local command="$2"
  local timeout_seconds="$3"
  local waited=0
  local output

  until output="$(ssh_node "$index" "$command" 2>/tmp/mysql-validation-ssh.err)" && [ -n "$output" ]; do
    if [ "$waited" -ge "$timeout_seconds" ]; then
      log "Timed out waiting for SSH on ${MYSQL_NODE_HOSTNAMES[$index]}" >&2
      tail -n 40 /tmp/mysql-validation-ssh.err >&2 || true
      return 1
    fi
    log "Waiting for SSH on ${MYSQL_NODE_HOSTNAMES[$index]}..." >&2
    sleep 10
    waited=$((waited + 10))
  done

  printf '%s' "$output"
}

mysql_query() {
  local endpoint="$1"
  local query="$2"

  docker run --rm \
    -e MYSQL_PWD="$MYSQL_PASSWORD" \
    "$MYSQL_IMAGE" \
    mysql \
      --connect-timeout=10 \
      --batch \
      --raw \
      --skip-column-names \
      -h "$(endpoint_host "$endpoint")" \
      -P "$(endpoint_port "$endpoint")" \
      -u "$MYSQL_USER" \
      -e "$query"
}

wait_for_query() {
  local endpoint="$1"
  local query="$2"
  local timeout_seconds="$3"
  local waited=0

  until mysql_query "$endpoint" "$query" >/tmp/mysql-validation-query.out 2>/tmp/mysql-validation-query.err; do
    if [ "$waited" -ge "$timeout_seconds" ]; then
      log "Timed out waiting for query on $endpoint"
      cat /tmp/mysql-validation-query.err
      return 1
    fi
    log "Waiting for MySQL endpoint $endpoint..."
    sleep 10
    waited=$((waited + 10))
  done
}

prepare_host_aliases() {
  local private_ips=()
  local hosts_block
  local i

  log "Preparing VPC hostname aliases on MySQL nodes..."
  for i in "${!MYSQL_NODE_HOSTNAMES[@]}"; do
    private_ips[$i]="$(wait_for_ssh_output "$i" "hostname -I | cut -d' ' -f1" "$SSH_WAIT_TIMEOUT_SECONDS")"
  done

  hosts_block=$'\n# mysql-innodb-cluster hosts\n'
  for i in "${!MYSQL_NODE_HOSTNAMES[@]}"; do
    hosts_block+="${private_ips[$i]} ${MYSQL_NODE_HOSTNAMES[$i]}"$'\n'
  done

  for i in "${!MYSQL_NODE_HOSTNAMES[@]}"; do
    printf '%s' "$hosts_block" | ssh_node_stdin "$i" "cat >>/etc/hosts"
  done
}

first_live_direct_endpoint() {
  local endpoint
  for endpoint in "${MYSQL_DIRECT_ENDPOINTS[@]}"; do
    if mysql_query "$endpoint" "SELECT 1" >/dev/null 2>&1; then
      printf '%s' "$endpoint"
      return 0
    fi
  done

  return 1
}

first_writable_router_endpoint() {
  local query="$1"
  local endpoint

  for endpoint in "${ROUTER_RW_ENDPOINTS[@]}"; do
    if mysql_query "$endpoint" "$query" >/dev/null 2>&1; then
      printf '%s' "$endpoint"
      return 0
    fi
  done

  return 1
}

current_primary_hostname() {
  local endpoint
  endpoint="$(first_live_direct_endpoint)"
  mysql_query "$endpoint" "SELECT MEMBER_HOST FROM performance_schema.replication_group_members WHERE MEMBER_ROLE = 'PRIMARY' LIMIT 1;"
}

node_index_by_hostname() {
  local hostname="$1"
  local i

  for i in "${!MYSQL_NODE_HOSTNAMES[@]}"; do
    if [ "${MYSQL_NODE_HOSTNAMES[$i]}" = "$hostname" ]; then
      printf '%s' "$i"
      return 0
    fi
  done

  return 1
}

wait_for_cluster() {
  local endpoint

  for endpoint in "${ROUTER_RW_ENDPOINTS[@]}"; do
    wait_for_query "$endpoint" "SELECT 1;" 1800
  done

  wait_for_query "${ROUTER_RO_ENDPOINTS[0]}" "SELECT 1;" 1800
  wait_for_query "${MYSQL_DIRECT_ENDPOINTS[0]}" "SELECT COUNT(*) FROM performance_schema.replication_group_members;" 1800
}

validate_router_read_write() {
  local run_id
  local row_count

  run_id="$(date +%s)"
  log "Validating Router read/write endpoints..."
  first_writable_router_endpoint "
CREATE DATABASE IF NOT EXISTS mysql_ha_validation;
CREATE TABLE IF NOT EXISTS mysql_ha_validation.validation_rows (
  id BIGINT PRIMARY KEY,
  note VARCHAR(64) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
REPLACE INTO mysql_ha_validation.validation_rows (id, note) VALUES ($run_id, 'before-failover');
" >/tmp/mysql-validation-rw-endpoint

  log "Validating Router read-only endpoint ${ROUTER_RO_ENDPOINTS[0]}..."
  row_count="$(mysql_query "${ROUTER_RO_ENDPOINTS[0]}" "SELECT COUNT(*) FROM mysql_ha_validation.validation_rows WHERE id = $run_id;")"
  if [ "$row_count" != "1" ]; then
    log "Expected validation row to be visible through read-only Router, got $row_count"
    return 1
  fi
}

validate_failover() {
  local old_primary
  local old_primary_index
  local old_primary_ssh_endpoint
  local old_primary_password
  local new_primary=""
  local i

  old_primary="$(current_primary_hostname)"
  old_primary_index="$(node_index_by_hostname "$old_primary")"
  old_primary_ssh_endpoint="${MYSQL_NODE_SSH_ENDPOINTS[$old_primary_index]}"
  old_primary_password="$(printf '%s' "${MYSQL_INSTANCE_PASSWORDS_B64[$old_primary_index]}" | base64 -d)"

  log "Current primary is $old_primary. Stopping MySQL through $old_primary_ssh_endpoint to validate failover..."
  sshpass -p "$old_primary_password" ssh \
    "${SSH_OPTIONS[@]}" \
    -p "$(endpoint_port "$old_primary_ssh_endpoint")" \
    "root@$(endpoint_host "$old_primary_ssh_endpoint")" \
    "systemctl stop mysql"

  for i in $(seq 1 90); do
    if first_writable_router_endpoint "REPLACE INTO mysql_ha_validation.validation_rows (id, note) VALUES (999999, 'after-failover');" >/dev/null; then
      new_primary="$(current_primary_hostname || true)"
      if [ -n "$new_primary" ] && [ "$new_primary" != "$old_primary" ]; then
        log "Failover succeeded: $old_primary -> $new_primary"
        break
      fi
    fi
    log "Waiting for primary failover..."
    sleep 5
  done

  log "Restarting MySQL on original primary through $old_primary_ssh_endpoint..."
  sshpass -p "$old_primary_password" ssh \
    "${SSH_OPTIONS[@]}" \
    -p "$(endpoint_port "$old_primary_ssh_endpoint")" \
    "root@$(endpoint_host "$old_primary_ssh_endpoint")" \
    "systemctl start mysql || true"

  if [ -z "$new_primary" ] || [ "$new_primary" = "$old_primary" ]; then
    log "Primary did not fail over from $old_primary"
    return 1
  fi
}

if [ "${#MYSQL_NODE_SSH_ENDPOINTS[@]}" -eq 0 ]; then
  log "No MySQL node SSH endpoints were provided."
  exit 1
fi

log "Pulling MySQL validation image if needed..."
docker image inspect "$MYSQL_IMAGE" >/dev/null 2>&1 || docker pull "$MYSQL_IMAGE"

prepare_host_aliases
wait_for_cluster
validate_router_read_write
validate_failover

log "VALIDATION PASSED: MySQL Router read/write, read-only replication, and primary failover are working."
