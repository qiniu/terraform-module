#!/bin/bash
set -e

# Install MySQL if not already installed

echo "Checking for MySQL installation..."

if ! command -v mysql &> /dev/null; then
    echo "MySQL not found, installing..."
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-client-8.0 mysql-server-8.0 mysql-router mysql-shell
fi``

echo "Setting up MySQL standalone instance..."

# 允许外部IP访问
sed -i 's/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf

# 确保删除旧的server uuid配置文件，防止uuid冲突
rm -f /var/lib/mysql/auto.cnf

# 重启 MySQL 服务
systemctl restart mysql
sleep 1 # 等待 MySQL 服务重启完成

# 配置基础用户
mysql -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysql_password}';
CREATE USER '${mysql_username}'@'%' IDENTIFIED BY '${mysql_password}';
GRANT ALL PRIVILEGES ON *.* TO '${mysql_username}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# 如果 mysql_db_name 不为空，则创建数据库
if [[ -n "${mysql_db_name}" ]]; then
  mysql -u"${mysql_username}" -p"${mysql_password}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${mysql_db_name}\`;
EOF
fi

echo "MySQL standalone setup completed successfully!"