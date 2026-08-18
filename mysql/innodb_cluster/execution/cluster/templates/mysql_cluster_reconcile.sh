#!/bin/bash
set -euo pipefail
set +x

cat >/tmp/mysql_cluster_reconcile.py <<'PYTHON'
import json
import time

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


def wait_for_instance(host):
    deadline = time.time() + 900
    while time.time() < deadline:
        try:
            shell.connect(instance_config(host))
            session.run_sql("SELECT 1")
            shell.disconnect()
            return
        except Exception as err:
            print("Waiting for " + host + ": " + str(err))
            time.sleep(5)
    raise RuntimeError("Timed out waiting for MySQL on " + host)


for host in hosts:
    wait_for_instance(host)

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

    print("Adding instance " + host)
    call(cluster, "add_instance", "addInstance", instance_config(host), {"recoveryMethod": "clone", "interactive": False})

print(json.dumps(cluster.status(), indent=2))
PYTHON

mysqlsh --py --file=/tmp/mysql_cluster_reconcile.py
touch /var/log/mysql-innodb-cluster-ready
