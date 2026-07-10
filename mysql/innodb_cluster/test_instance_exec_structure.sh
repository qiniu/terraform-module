#!/bin/bash
set -euo pipefail

module_dir="$(cd "$(dirname "$0")" && pwd)"

test -f "$module_dir/execution/discovery/main.tf"
test -f "$module_dir/execution/cluster/main.tf"
test ! -f "$module_dir/command_execution.tf"
rg -q 'output "mysql_node_instance_ids"' "$module_dir/outputs.tf"
test -f "$module_dir/scripts/templates/mysql_innodb_node.sh"
test -f "$module_dir/scripts/templates/mysql_cluster_reconcile.sh"
if rg -q 'internet_(max_bandwidth|charge_type|public_ip_type)' "$module_dir/examples/with_vpc_nat/main.tf"; then
  echo "The example must not configure public internet access for database nodes." >&2
  exit 1
fi

if rg -q 'resource "qiniu_compute_eip"' "$module_dir/examples/with_vpc_nat" --glob '*.tf'; then
  echo "InstanceConnect end-to-end validation must not require an EIP." >&2
  exit 1
fi

if rg -q '^  user_data\s*=' "$module_dir" --glob '*.tf'; then
  echo "MySQL instances must not use user_data for deployment." >&2
  exit 1
fi
