#!/bin/bash
set -e

echo "This is a replica node."

# 允许外部IP访问
sed -i 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# 确保删除旧的server uuid配置文件，防止uuid冲突
rm -f /var/lib/mysql/auto.cnf

# 配置主从复制
tee /etc/mysql/mysql.conf.d/replication.cnf >/dev/null <<EOF
[mysqld]
server_id = ${mysql_server_id}
relay_log = /var/lib/mysql/mysql-relay-bin # 中继日志路径
read_only = ON # 设置从库为只读
super_read_only = ON # 设置root用户也是只读模式
gtid_mode = ON # 开启 GTID 模式
enforce_gtid_consistency = ON # 强制保证 GTID 一致性（避免非事务操作）
EOF

# 重启 MySQL 服务
systemctl restart mysql
sleep 1 # 等待 MySQL 服务重启完成

# 轮询等待主库启动
while ! mysqladmin ping -h "${mysql_master_ip}" -u"${mysql_replication_username}" -p"${mysql_replication_password}" --silent; do
  echo "Waiting for MySQL master at ${mysql_master_ip} to be ready..."
  sleep 2
done

# 配置从库，将自动将主库所有变更都同步过来，包括用户配置
mysql -uroot <<EOF
  CHANGE MASTER TO
    MASTER_HOST = '${mysql_master_ip}',
    MASTER_USER = '${mysql_replication_username}',
    MASTER_PASSWORD = '${mysql_replication_password}',
    MASTER_AUTO_POSITION = 1;
  START SLAVE;
  SHOW SLAVE STATUS\G;
EOF
