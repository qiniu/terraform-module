#!/bin/bash
set -euo pipefail
set +x

exec > >(tee -a /var/log/mysql-data-storage.log) 2>&1

DATA_DISK_ID='${data_disk_id}'
DATA_ROOT=/data
MYSQL_DATA_DIR=/data/mysql
MARKER="$MYSQL_DATA_DIR/.terraform-mysql-data-ready"

find_data_disk() {
  local link target
  link="$(find /dev/disk/by-id -maxdepth 1 -type l -name "*$DATA_DISK_ID*" -printf '%f\n' | sort | head -n1)"
  [ -n "$link" ] || return 1
  target="$(readlink -f "/dev/disk/by-id/$link")"
  [ -b "$target" ] || return 1
  DATA_DEVICE="$target"
}

if [ -n "$DATA_DISK_ID" ]; then
  DATA_DEVICE=""
  for _ in $(seq 1 60); do
    find_data_disk && break
    sleep 2
  done
  [ -n "$DATA_DEVICE" ] || { echo "Data disk $DATA_DISK_ID was not found" >&2; exit 1; }

  filesystem="$(blkid -o value -s TYPE "$DATA_DEVICE" || true)"
  if [ -z "$filesystem" ]; then
    mkfs.ext4 -F "$DATA_DEVICE"
  elif [ "$filesystem" != "ext4" ]; then
    echo "Data disk $DATA_DISK_ID uses unsupported filesystem $filesystem" >&2
    exit 1
  fi

  uuid="$(blkid -o value -s UUID "$DATA_DEVICE")"
  mkdir -p "$DATA_ROOT"
  grep -v '# BEGIN terraform-mysql-data-disk\|# END terraform-mysql-data-disk' /etc/fstab > /tmp/fstab.mysql
  {
    echo '# BEGIN terraform-mysql-data-disk'
    echo "UUID=$uuid $DATA_ROOT ext4 defaults,nofail 0 2"
    echo '# END terraform-mysql-data-disk'
  } >> /tmp/fstab.mysql
  cat /tmp/fstab.mysql > /etc/fstab
  rm -f /tmp/fstab.mysql
  mountpoint -q "$DATA_ROOT" || mount "$DATA_ROOT"
else
  mkdir -p "$DATA_ROOT"
fi

systemctl stop mysql >/dev/null 2>&1 || true
if [ ! -e "$MARKER" ]; then
  if [ -d "$MYSQL_DATA_DIR" ] && [ "$(find "$MYSQL_DATA_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    echo "$MYSQL_DATA_DIR contains unmanaged data" >&2
    exit 1
  fi
  install -d -o mysql -g mysql -m 0750 "$MYSQL_DATA_DIR"
  if [ -d /var/lib/mysql ]; then
    tar -C /var/lib/mysql -cpf - . | tar -C "$MYSQL_DATA_DIR" -xpf -
    rm -rf /var/lib/mysql/*
  fi
  chown -R mysql:mysql "$MYSQL_DATA_DIR"
  touch "$MARKER"
fi

install -d -m 0755 /etc/systemd/system/mysql.service.d
cat >/etc/systemd/system/mysql.service.d/terraform-data-directory.conf <<EOF
[Unit]
RequiresMountsFor=$MYSQL_DATA_DIR
EOF

if [ -d /etc/apparmor.d/local ]; then
  cat >/etc/apparmor.d/local/usr.sbin.mysqld <<EOF
$MYSQL_DATA_DIR/ r,
$MYSQL_DATA_DIR/** rwk,
EOF
  command -v apparmor_parser >/dev/null 2>&1 && apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld || true
fi
systemctl daemon-reload
