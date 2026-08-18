#!/bin/bash
set -e

# 设置环境变量（使用单引号避免特殊字符问题）
MYSQL_USERNAME='${mysql_username}'
MYSQL_PASSWORD='${mysql_password}'
MYSQL_DB_NAME='${mysql_db_name}'

# Install MySQL if not already installed

echo "Checking for MySQL installation..."

if ! command -v mysql &> /dev/null; then
    echo "MySQL not found, installing..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-client-8.0 mysql-server-8.0 mysql-router mysql-shell
fi

echo "Setting up MySQL standalone instance..."

# 允许外部IP访问
sed -i 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# 确保删除旧的server uuid配置文件，防止uuid冲突
rm -f /var/lib/mysql/auto.cnf

# 重启 MySQL 服务
systemctl restart mysql

# 等待 MySQL 服务重启完成
while ! mysqladmin ping --silent; do sleep 1; done  

# 配置基础用户
mysql -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
CREATE USER '$MYSQL_USERNAME'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USERNAME'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# 如果 mysql_db_name 不为空，则创建数据库
if [[ -n "$MYSQL_DB_NAME" ]]; then
  mysql -u"$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB_NAME\`;
EOF
fi

echo "MySQL standalone setup completed successfully!"