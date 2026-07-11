#!/bin/bash
set -euo pipefail
set +x

exec > >(tee -a /var/log/mysql-packages.log) 2>&1

missing_packages=()
if ! command -v mysql >/dev/null 2>&1 || ! command -v mysqld >/dev/null 2>&1; then
  missing_packages+=(mysql-client-8.0 mysql-server-8.0)
fi
command -v mysqlsh >/dev/null 2>&1 || missing_packages+=(mysql-shell)
if ! command -v mysqlrouter >/dev/null 2>&1; then
  missing_packages+=(mysql-router)
fi

if [ "$${#missing_packages[@]}" -gt 0 ]; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$${missing_packages[@]}"
fi
