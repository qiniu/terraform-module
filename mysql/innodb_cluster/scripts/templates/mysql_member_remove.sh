#!/bin/bash
set -euo pipefail
set +x

cat >/tmp/mysql_member_remove.py <<'PYTHON'
import json

bootstrap_hostname = ${bootstrap_hostname_json}
target_hostname = ${target_hostname_json}
cluster_name = ${cluster_name_json}
user = ${mysql_admin_username_js}
password = ${mysql_admin_password_js}


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


shell.connect(instance_config(bootstrap_hostname))
lock_name = "terraform-mysql-innodb-cluster-membership"
lock_result = session.run_sql("SELECT GET_LOCK(?, 900)", [lock_name]).fetch_one()[0]
if lock_result != 1:
    raise RuntimeError("Unable to acquire cluster membership lock")

try:
    cluster = call(dba, "get_cluster", "getCluster", cluster_name)
    topology = cluster.status().get("defaultReplicaSet", {}).get("topology", {})
    target_key = target_hostname + ":3306"
    if target_key not in topology:
        print("Instance " + target_hostname + " is already absent from the cluster")
    else:
        online_hosts = [
            key.rsplit(":", 1)[0]
            for key, member in topology.items()
            if member.get("status") == "ONLINE"
        ]
        if len(online_hosts) <= 3:
            print("Cluster has three or fewer online members; skipping removal during full destroy")
        else:
            target = topology[target_key]
            if target.get("role") == "PRIMARY":
                candidates = [host for host in online_hosts if host != target_hostname]
                if not candidates:
                    raise RuntimeError("No online member is available to replace the primary")
                call(cluster, "set_primary_instance", "setPrimaryInstance", instance_config(candidates[0]), {"runningTransactionsTimeout": 300})

            options = {"interactive": False}
            if target.get("status") != "ONLINE":
                options["force"] = True
            call(cluster, "remove_instance", "removeInstance", instance_config(target_hostname), options)
            print("Removed instance " + target_hostname + " from the cluster")
finally:
    session.run_sql("SELECT RELEASE_LOCK(?)", [lock_name])
PYTHON

mysqlsh --py --file=/tmp/mysql_member_remove.py
