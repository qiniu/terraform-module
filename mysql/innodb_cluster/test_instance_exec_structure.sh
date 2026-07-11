#!/bin/bash
set -euo pipefail

module_dir="$(cd "$(dirname "$0")" && pwd)"

test -f "$module_dir/execution/discovery/main.tf"
test -f "$module_dir/execution/cluster/main.tf"
test -f "$module_dir/execution/discovery/templates/discover_private_ip.sh"
test -f "$module_dir/execution/cluster/scripts.tf"
test -f "$module_dir/execution/cluster/templates/mysql_innodb_node.sh"
test -f "$module_dir/execution/cluster/templates/mysql_cluster_reconcile.sh"
rg -q 'chmod 0644 /etc/mysql/mysql\.conf\.d/zz-innodb-cluster\.cnf' "$module_dir/execution/cluster/templates/mysql_innodb_node.sh"
rg -q 'rm -f /var/lib/mysql/auto\.cnf' "$module_dir/execution/cluster/templates/mysql_innodb_node.sh"
rg -q 'MySQL did not load the InnoDB Cluster configuration' "$module_dir/execution/cluster/templates/mysql_innodb_node.sh"
rg -q 'data "qiniu_compute_region" "current"' "$module_dir/main.tf"
rg -q 'system_disk_type   = "cloud.ssd"' "$module_dir/infrastructure/main.tf"
rg -q '当前区域不支持 EBS 云盘' "$module_dir/infrastructure/main.tf"
test ! -d "$module_dir/scripts"
test ! -f "$module_dir/command_execution.tf"
rg -q 'output "mysql_node_instance_ids"' "$module_dir/outputs.tf"
if rg -q 'internet_(max_bandwidth|charge_type|public_ip_type)|disable_public_ip|public_ip_addresses' \
  "$module_dir" \
  --glob '*.tf' \
  -g '!examples/with_eip/**'; then
  echo "The MySQL module must not configure or expose public IP resources." >&2
  exit 1
fi

if rg -q 'source_cidr_ip\s*=\s*"0\.0\.0\.0/0"' "$module_dir/infrastructure" --glob '*.tf'; then
  echo "The MySQL security group must not expose database ports to every CIDR." >&2
  exit 1
fi

if rg -q 'resource "qiniu_compute_security_group' "$module_dir/infrastructure" --glob '*.tf'; then
  echo "The MySQL module must consume caller-managed security groups." >&2
  exit 1
fi

for resource_type in eip nat_gateway snat_rule; do
  if ! rg -q "resource \"qiniu_compute_${resource_type}\"" "$module_dir/examples/with_eip" --glob '*.tf'; then
    echo "The package-installation example must provision EIP, NAT Gateway, and SNAT." >&2
    exit 1
  fi
done

test -f "$module_dir/examples/without_eip/main.tf"
if rg -q 'resource "qiniu_compute_(eip|nat_gateway|snat_rule)"' "$module_dir/examples/without_eip" --glob '*.tf'; then
  echo "The preinstalled-image example must not create public egress resources." >&2
  exit 1
fi

if rg -q '^  user_data\s*=' "$module_dir" --glob '*.tf'; then
  echo "MySQL instances must not use user_data for deployment." >&2
  exit 1
fi

if rg -q 'random_password.*mysql_instance_password|mysql_instance_passwords|\bpassword\s*=' "$module_dir" --glob '*.tf'; then
  echo "MySQL instance access must use the generated SSH key pair, not passwords." >&2
  exit 1
fi
