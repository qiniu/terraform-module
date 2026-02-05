# 架构说明

## 整体流程图

```
┌─────────────────────────────────────────────────────────────────┐
│                     Terraform 部署流程                            │
└─────────────────────────────────────────────────────────────────┘

1. 用户配置
   ├── terraform.tfvars (你的配置)
   │   ├── github_repo_url
   │   ├── github_token
   │   └── instance_type
   │
2. Terraform 初始化
   ├── terraform init
   │   └── 下载 qiniu、random provider
   │
3. 资源规划
   ├── terraform plan
   │   ├── 查询 Ubuntu 24.04 镜像 (data.tf)
   │   ├── 生成随机后缀 (data.tf)
   │   └── 计算本地变量 (data.tf)
   │
4. 资源创建
   ├── terraform apply
   │   ├── 创建随机密码 (main.tf)
   │   ├── 创建虚拟机 (main.tf)
   │   │   ├── 规格: instance_type
   │   │   ├── 镜像: Ubuntu 24.04
   │   │   └── 初始化脚本: runner_setup.sh
   │   │
   │   └── 虚拟机启动后自动执行:
   │       └── runner_setup.sh
   │           ├── [1/7] 更新系统 & 安装依赖
   │           ├── [2/7] 创建 runner 用户
   │           ├── [3/7] 安装 Docker (可选)
   │           ├── [4/7] 下载 GitHub Runner
   │           ├── [5/7] 获取 Registration Token
   │           ├── [6/7] 配置 Runner
   │           └── [7/7] 安装为系统服务并启动
   │
5. 输出结果
   └── terraform output
       ├── runner_name
       ├── runner_private_ip
       ├── runner_labels
       └── instance_password (sensitive)
```

## 文件关系图

```
┌────────────────────────────────────────────────────────────────┐
│                        文件依赖关系                              │
└────────────────────────────────────────────────────────────────┘

terraform.tfvars.example  ←── 复制修改 ──→  terraform.tfvars (你的配置)
                                                    │
                                                    ↓
                                            variables.tf (定义变量)
                                                    │
                    ┌───────────────────────────────┼───────────────────┐
                    │                               │                   │
                    ↓                               ↓                   ↓
              versions.tf                       data.tf            main.tf
         (Provider 版本要求)              (数据查询 & 本地变量)   (创建虚拟机)
                                                                        │
                                                                        ↓
                                                              runner_setup.sh
                                                           (虚拟机初始化脚本)
                                                                        │
                    ┌───────────────────────────────────────────────────┘
                    │
                    ↓
              outputs.tf
         (输出部署结果信息)
```

## 核心组件说明

### 1. versions.tf - Provider 配置

```hcl
provider "qiniu"  ──→  连接七牛云 API
provider "random" ──→  生成随机字符串/密码
```

**作用**: 定义 Terraform 使用哪些云服务商的 API

### 2. variables.tf - 输入参数

```hcl
variable "github_repo_url"        ──→  你要部署 Runner 的仓库
variable "github_token"           ──→  用于注册 Runner 的 Token
variable "instance_type"          ──→  虚拟机规格 (2核4GB, 4核8GB...)
variable "enable_docker"          ──→  是否安装 Docker
variable "runner_labels"          ──→  自定义标签
```

**作用**: 用户可配置的参数，通过 `terraform.tfvars` 传入

### 3. data.tf - 数据查询 & 计算

```hcl
┌─────────────────────────────────────────────┐
│ 数据查询                                     │
├─────────────────────────────────────────────┤
│ data "qiniu_compute_images"                 │
│   ├── 查询所有官方镜像                        │
│   └── 筛选 Ubuntu 24.04 LTS                 │
├─────────────────────────────────────────────┤
│ 资源创建                                     │
├─────────────────────────────────────────────┤
│ resource "random_string"                    │
│   └── 生成 6 位随机后缀 (abc123)             │
├─────────────────────────────────────────────┤
│ 本地变量计算                                  │
├─────────────────────────────────────────────┤
│ locals {                                    │
│   runner_suffix   = "abc123"                │
│   ubuntu_image_id = "img-xxxxx"             │
│   runner_name     = "runner-abc123"         │
│   runner_labels   = ["self-hosted", ...]    │
│   github_owner    = "your-org"              │
│   github_repo     = "your-repo"             │
│ }                                           │
└─────────────────────────────────────────────┘
```

**作用**: 查询镜像、生成后缀、计算变量

### 4. main.tf - 核心资源

```hcl
┌────────────────────────────────────────────┐
│ 1. 生成虚拟机密码                            │
├────────────────────────────────────────────┤
│ random_password "runner_instance_password" │
│   └── 16位随机密码 (包含大小写数字特殊字符)   │
├────────────────────────────────────────────┤
│ 2. 创建虚拟机实例                            │
├────────────────────────────────────────────┤
│ qiniu_compute_instance "github_runner"     │
│   ├── name: github-runner-abc123           │
│   ├── instance_type: ecs.t1.c2m4           │
│   ├── image_id: Ubuntu 24.04               │
│   ├── system_disk_size: 50GB               │
│   ├── password: <随机密码>                  │
│   └── user_data: <runner_setup.sh 脚本>    │
└────────────────────────────────────────────┘
```

**作用**: 创建虚拟机并注入初始化脚本

### 5. runner_setup.sh - 初始化脚本

```bash
┌──────────────────────────────────────────────────┐
│ 虚拟机启动后自动执行                              │
├──────────────────────────────────────────────────┤
│ [1/7] apt update & install 基础软件              │
│       ├── curl, jq, git                          │
│       └── 用户指定的额外软件包                     │
├──────────────────────────────────────────────────┤
│ [2/7] 创建 runner 用户                           │
│       ├── useradd -m -s /bin/bash runner         │
│       ├── 添加到 sudo 组                          │
│       └── 配置无密码 sudo (仅 docker/systemctl)  │
├──────────────────────────────────────────────────┤
│ [3/7] 安装 Docker (如果 enable_docker=true)      │
│       ├── 添加 Docker 官方源                      │
│       ├── 安装 Docker Engine                     │
│       └── 添加 runner 到 docker 组                │
├──────────────────────────────────────────────────┤
│ [4/7] 下载 GitHub Actions Runner                │
│       ├── 查询最新版本号                          │
│       ├── 下载 tar.gz                            │
│       └── 解压到 /home/runner/actions-runner     │
├──────────────────────────────────────────────────┤
│ [5/7] 获取 Registration Token                   │
│       ├── 解析 github_repo_url                   │
│       └── 调用 GitHub API 获取 token             │
├──────────────────────────────────────────────────┤
│ [6/7] 配置 Runner                                │
│       └── ./config.sh --url ... --token ...      │
├──────────────────────────────────────────────────┤
│ [7/7] 安装为系统服务                              │
│       ├── ./svc.sh install runner                │
│       └── ./svc.sh start                         │
└──────────────────────────────────────────────────┘
```

**作用**: 自动化配置整个 Runner 环境

### 6. outputs.tf - 输出结果

```hcl
┌────────────────────────────────────────────┐
│ 部署完成后显示的信息                         │
├────────────────────────────────────────────┤
│ ✓ runner_instance_id    → i-xxxxxxxx       │
│ ✓ runner_name           → runner-abc123    │
│ ✓ runner_private_ip     → 10.0.0.123       │
│ ✓ runner_labels         → [self-hosted...] │
│ ✓ ssh_connection_command → ssh root@...    │
│ ✓ runner_status_check   → ssh ... status   │
│ ✓ instance_password     → *** (sensitive)  │
└────────────────────────────────────────────┘
```

**作用**: 显示部署结果和操作指南

## Terraform 工作原理

### State 管理

```
terraform.tfstate (本地状态文件)
├── 记录所有已创建的资源
├── 包含资源的真实 ID 和属性
└── 用于对比配置变化

工作流程:
1. terraform plan
   ├── 读取配置文件 (*.tf)
   ├── 读取状态文件 (terraform.tfstate)
   └── 对比差异 → 显示变更计划

2. terraform apply
   ├── 执行变更计划
   ├── 调用云服务商 API
   └── 更新状态文件
```

### 依赖关系自动解析

```
Terraform 自动分析资源之间的依赖:

random_string
     │
     ├──→ locals.runner_suffix
     │         │
     │         └──→ main.tf 中的虚拟机名称
     │
random_password
     │
     └──→ main.tf 中的虚拟机密码

data.qiniu_compute_images
     │
     ├──→ locals.ubuntu_image_id
     │         │
     │         └──→ main.tf 中的镜像 ID

执行顺序:
1. 先创建 random_string、random_password
2. 查询 data source
3. 计算 locals
4. 最后创建虚拟机 (依赖前面所有结果)
```

## 与 MySQL 模板的对比

| 特性 | MySQL 模板 | GitHub Runner 模板 |
|------|-----------|-------------------|
| **核心资源** | MySQL 数据库实例 | GitHub Actions Runner |
| **初始化脚本** | `mysql_standalone.sh` | `runner_setup.sh` |
| **主要配置** | 用户名、密码、数据库名 | GitHub URL、Token、标签 |
| **输出信息** | MySQL 连接地址 | Runner 名称、IP、SSH 命令 |
| **可选功能** | 无 | Docker、额外软件包 |
| **外部 API** | 无 | GitHub API (获取 token) |
| **服务管理** | systemd (mysql) | systemd (actions.runner) |

## 技术亮点

### 1. 模板化脚本 (templatefile)

```hcl
user_data = base64encode(templatefile("${path.module}/runner_setup.sh", {
  github_token = var.github_token,
  runner_name  = local.runner_name,
  ...
}))
```

**好处**:
- 将配置参数安全地注入到 shell 脚本
- 使用单引号避免特殊字符问题
- 脚本模板化，易于维护

### 2. 变量验证 (validation)

```hcl
validation {
  condition     = can(regex("^https://github\\.com/...", var.github_repo_url))
  error_message = "必须是有效的 GitHub 仓库 URL"
}
```

**好处**:
- 在 plan 阶段就发现配置错误
- 提供清晰的错误提示
- 避免部署后才发现问题

### 3. 敏感信息保护 (sensitive)

```hcl
variable "github_token" {
  sensitive = true
}

output "instance_password" {
  sensitive = true
}
```

**好处**:
- 防止密码在日志中明文显示
- 需要显式 `terraform output <name>` 查看

### 4. 自动化 Token 获取

```bash
# 通过 API 自动获取 Registration Token
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/actions/runners/registration-token \
  | jq -r '.token')
```

**好处**:
- 解决 Token 1 小时过期问题
- 用户只需提供长期 PAT
- 自动化程度高

## 使用场景决策树

```
需要 CI/CD Runner?
    │
    ├─ 是 → 工作负载类型?
    │       ├─ 轻量级测试 → ecs.t1.c2m4 (2核4GB)
    │       ├─ 前端构建   → ecs.t1.c4m8 (4核8GB)
    │       ├─ 后端编译   → ecs.t1.c8m16 (8核16GB)
    │       └─ Docker构建 → ecs.t1.c8m16 + enable_docker=true
    │
    └─ 否 → 考虑其他模板 (如 mysql)
```

## 扩展思路

### 未来可以添加的功能

1. **自动扩缩容**
   - 根据 GitHub workflow queue 长度自动创建/销毁 Runner
   - 需要配合 Lambda/Serverless 函数

2. **监控告警**
   - 集成七牛云监控
   - Runner 离线/磁盘满自动告警

3. **多 Runner 支持**
   - 使用 `count` 或 `for_each` 创建多个实例
   - 自动分配不同标签

4. **安全加固**
   - 配置防火墙规则
   - 定期自动更新系统
   - 日志收集

5. **备份恢复**
   - 定期备份虚拟机快照
   - 一键恢复功能
