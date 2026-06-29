# MySQL InnoDB Cluster

基于已有 VPC/Subnet 部署 MySQL InnoDB Cluster。默认创建 4 台数据库节点，使用 Single-Primary 模式，并在每台数据库节点上安装并 bootstrap MySQL Router。

## 职责边界

本模块负责：

- 创建 MySQL 数据库云主机。
- 创建置放组与安全组。
- 通过 `user_data` 安装 MySQL Server、MySQL Shell、MySQL Router。
- 初始化 InnoDB Cluster，并将其余节点加入集群。
- 在每台数据库节点上启动 MySQL Router，输出 `6446` 读写入口和 `6447` 只读入口。

本模块不负责：

- 创建 VPC/Subnet。
- 创建 EIP/NAT/SNAT/DNAT。
- 暴露公网访问入口。
- 在业务服务器侧安装 Router。

如需一键创建 VPC 和 NAT 出网，可参考 `examples/with_vpc_nat`。

## 前置条件

- 子网内实例需要能出网安装 `mysql-server-8.0`、`mysql-shell`、`mysql-router` 等包。可由调用方提前配置 NAT/SNAT，或使用预装镜像。
- VPC 内需要能解析实例 hostname。本模块按固定 hostname 创建节点，并通过 hostname 创建 InnoDB Cluster。
- 模块默认不创建公网入口。业务侧推荐自行部署 MySQL Router 并连接本地 `127.0.0.1:6446/6447`；本模块在 DB 节点上部署的 Router 可作为开箱即用入口或兜底入口。

## 使用方式

```hcl
module "mysql_innodb_cluster" {
  source = "./mysql/innodb_cluster"

  vpc_id    = "vpc-xxxx"
  subnet_id = "subnet-xxxx"

  mysql_node_count = 4
}
```

连接入口输出为 `hostname:port`，调用方需要确保业务服务器或运维节点能解析这些 hostname：

- 读写：`mysql_router_read_write_endpoints`，端口 `6446`
- 只读：`mysql_router_read_only_endpoints`，端口 `6447`
- 直连数据库：`mysql_direct_endpoints`，端口 `3306`

## 安全组说明

由于当前 qiniu provider 在 `qiniu_compute_security_group_rule_set` 的动态嵌套规则中无法处理未知值，本模块只生成静态规则，开放 MySQL、Group Replication 和 Router 必需端口：

- `3306`：MySQL Classic protocol
- `33060`：MySQL X protocol
- `33061`：Group Replication
- `6446`：Router 读写入口
- `6447`：Router 只读入口
- `6448`/`6449`：Router X protocol 入口

模块默认不分配公网 IP，也不创建 DNAT。若调用方额外暴露实例公网访问，应额外收紧安全组规则。

## 验证

```bash
terraform init
terraform validate
terraform test
```

完整部署验收可在示例目录启用：

```bash
cd examples/with_vpc_nat
terraform apply -var='enable_validation=true' -var='enable_nat=false'
```

启用后示例会给 MySQL 节点临时分配独立公网 IP；本地脚本通过 Docker MySQL 客户端验证 Router 写读、只读查询和停止当前 primary 后的自动切主。验收完成后应执行 `terraform destroy` 清理资源。

实例初始化日志位于：

```text
/var/log/mysql-innodb-init.log
```
