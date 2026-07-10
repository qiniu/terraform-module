#!/bin/bash
set -euo pipefail

module_dir="$(cd "$(dirname "$0")" && pwd)"

test -f "$module_dir/execution/discovery/main.tf"
test -f "$module_dir/execution/cluster/main.tf"
test -f "$module_dir/execution/discovery/templates/discover_private_ip.sh"
test -f "$module_dir/execution/cluster/scripts.tf"
test -f "$module_dir/execution/cluster/templates/mysql_innodb_node.sh"
test -f "$module_dir/execution/cluster/templates/mysql_cluster_reconcile.sh"
test ! -d "$module_dir/scripts"
test ! -f "$module_dir/command_execution.tf"
rg -q 'output "mysql_node_instance_ids"' "$module_dir/outputs.tf"
if rg -q 'internet_(max_bandwidth|charge_type|public_ip_type)|disable_public_ip|public_ip_addresses' "$module_dir" --glob '*.tf'; then
  echo "The MySQL module must not configure or expose public IP resources." >&2
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
