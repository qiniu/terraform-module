# MySQL InnoDB Cluster

基于已有 VPC/Subnet 部署 MySQL InnoDB Cluster。默认创建 4 台数据库节点，使用 Single-Primary 模式，并在每台数据库节点上安装并 bootstrap MySQL Router。

## 职责边界

本模块负责：

- 创建 MySQL 数据库云主机。
- 创建置放组与数据库节点。
- 通过 InstanceConnect 和 `qiniu_compute_instance_exec` 安装 MySQL Server、MySQL Shell、MySQL Router。
- 初始化 InnoDB Cluster，并将其余节点加入集群。
- 在每台数据库节点上启动 MySQL Router，输出 `6446` 读写入口和 `6447` 只读入口。

本模块不负责：

- 创建 VPC/Subnet。
- 创建或配置安全组、EIP、NAT、SNAT、DNAT。
- 暴露公网访问入口。
- 在业务服务器侧安装 Router。

通过 InstanceConnect 执行验收可参考 `examples/with_vpc_nat`；它消费已有 VPC、子网和安全组，同样不创建网络出口。

## 前置条件

- 子网内实例需要能出网安装 `mysql-server-8.0`、`mysql-shell`、`mysql-router` 等包。可由调用方提前配置 NAT/SNAT；使用包含这些命令的预装镜像时，脚本会跳过安装。
- 调用方必须提供已有安全组：仅允许集群节点之间访问 `3306`、`33060`、`33061`，并仅允许业务安全组访问 Router 端口 `6446` 至 `6449`。
- 模块会采集节点私网 IP 并在数据库节点内维护 hostname 到 IP 的映射。
- 模块默认不创建公网入口。业务侧推荐自行部署 MySQL Router 并连接本地 `127.0.0.1:6446/6447`；本模块在 DB 节点上部署的 Router 可作为开箱即用入口或兜底入口。

## 使用方式

```hcl
module "mysql_innodb_cluster" {
  source = "./mysql/innodb_cluster"

  vpc_id    = "vpc-xxxx"
  subnet_id = "subnet-xxxx"
  security_group_ids = ["sg-xxxx"]

  mysql_node_count = 4
}
```

连接入口输出为 `hostname:port`，调用方需要确保业务服务器或运维节点能解析这些 hostname：

- 读写：`mysql_router_read_write_endpoints`，端口 `6446`
- 只读：`mysql_router_read_only_endpoints`，端口 `6447`
- 直连数据库：`mysql_direct_endpoints`，端口 `3306`

## 安全组说明

安全组由调用方管理。应按以下端口最小化放行：

- `3306`：MySQL Classic protocol
- `33060`：MySQL X protocol
- `33061`：Group Replication
- `6446`：Router 读写入口
- `6447`：Router 只读入口
- `6448`/`6449`：Router X protocol 入口

模块不分配公网 IP，也不创建 DNAT。不要为数据库端口配置 `0.0.0.0/0` 入站规则。

## 验证

```bash
terraform init
terraform validate
terraform test
```

完整部署验收可在示例目录启用：

```bash
cd examples/with_vpc_nat
terraform apply -var='enable_validation=true'
```

启用后示例通过 InstanceConnect 在首节点验证 Router 写读、只读查询、停止当前 primary 后的自动切主及原主重新加入；不分配数据库节点公网 IP。示例仅创建 VPC 和子网，首次安装前仍需为子网提供 NAT/SNAT，或改用包含所需 MySQL 软件包的预装镜像。验收完成后应执行 `terraform destroy` 清理资源。

实例初始化日志位于：

```text
/var/log/mysql-innodb-node-setup.log
```
