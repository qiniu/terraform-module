#!/bin/bash
set -euo pipefail
set +x

hosts_file="/etc/hosts"
temporary_hosts_file="$(mktemp)"

sed '/# BEGIN terraform-mysql-innodb-cluster/,/# END terraform-mysql-innodb-cluster/d' "$hosts_file" >"$temporary_hosts_file"
cat >>"$temporary_hosts_file" <<'EOF'
# BEGIN terraform-mysql-innodb-cluster
${hosts_file_entries}
# END terraform-mysql-innodb-cluster
EOF

cat "$temporary_hosts_file" >"$hosts_file"
rm -f "$temporary_hosts_file"
