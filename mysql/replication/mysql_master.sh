#!/bin/bash
set -e

# 设置环境变量（使用 printf 避免特殊字符问题）
MYSQL_ADMIN_USERNAME='${mysql_admin_username}'
MYSQL_ADMIN_PASSWORD='${mysql_admin_password}'
MYSQL_REPLICATION_USERNAME='${mysql_replication_username}'
MYSQL_REPLICATION_PASSWORD='${mysql_replication_password}'
MYSQL_DB_NAME='${mysql_db_name}'

# Install MySQL if not already installed
echo "Checking for MySQL installation..."
if ! command -v mysql &> /dev/null; then
    echo "MySQL not found, installing..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-client-8.0 mysql-server-8.0 mysql-router mysql-shell
fi

echo "This is the primary node."

# 允许外部IP访问
sed -i 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# 确保删除旧的server uuid配置文件，防止uuid冲突
rm -f /var/lib/mysql/auto.cnf

# 配置主从复制
tee /etc/mysql/mysql.conf.d/replication.cnf >/dev/null <<EOF
[mysqld]
server_id = ${mysql_server_id}
log_bin = /var/log/mysql/mysql-bin.log  # binlog 路径前缀
binlog_format = ROW # binlog 格式
gtid_mode = ON # 开启 GTID 模式
expire_logs_days = 7 # 自动清理7天前的binlog
max_binlog_size = 100M # 单个binlog文件最大大小
enforce_gtid_consistency = ON # 强制保证 GTID 一致性（避免非事务操作）
EOF

# 重启 MySQL 服务
systemctl restart mysql

# 等待 MySQL 服务重启完成
while ! mysqladmin ping --silent; do sleep 1; done  

mysql -uroot <<EOF
  ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ADMIN_PASSWORD';
  CREATE USER IF NOT EXISTS '$MYSQL_ADMIN_USERNAME'@'%' IDENTIFIED BY '$MYSQL_ADMIN_PASSWORD';
  ALTER USER '$MYSQL_ADMIN_USERNAME'@'%' IDENTIFIED BY '$MYSQL_ADMIN_PASSWORD';
  GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_ADMIN_USERNAME'@'%' WITH GRANT OPTION;

  CREATE USER IF NOT EXISTS '$MYSQL_REPLICATION_USERNAME'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_REPLICATION_PASSWORD';
  ALTER USER '$MYSQL_REPLICATION_USERNAME'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_REPLICATION_PASSWORD';
  GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICATION_USERNAME'@'%';
  FLUSH PRIVILEGES;
EOF

# 如果 mysql_db_name 不为空，则创建数据库
if [[ -n "$MYSQL_DB_NAME" ]]; then
  mysql -u"$MYSQL_ADMIN_USERNAME" -p"$MYSQL_ADMIN_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB_NAME\`;
EOF
fi

# 查看数据库
mysql -u"$MYSQL_ADMIN_USERNAME" -p"$MYSQL_ADMIN_PASSWORD" -e "SHOW DATABASES;"
