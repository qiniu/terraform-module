#!/bin/bash
set -euo pipefail

if [ -n '${data_disk_id}' ]; then
  systemctl stop mysql >/dev/null 2>&1 || true
  umount /data >/dev/null 2>&1 || true
  sed -i '/# BEGIN terraform-mysql-data-disk/,/# END terraform-mysql-data-disk/d' /etc/fstab
fi
