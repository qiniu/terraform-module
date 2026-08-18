# CodeAgent Standard Edition

## 简介

CodeAgent 标准版 Terraform 模块，用于在七牛云上快速部署 CodeAgent 服务。该版本不包含 GitLab 服务，适合已有代码托管平台或只需要 CodeAgent 核心功能的场景。

## 功能特性

- ✅ 自动部署 CodeAgent 服务
- ✅ 支持配置 AI Model API Key
- ✅ 可选配置 GitLab 集成
- ✅ 自动配置公网访问
- ✅ 基于预配置镜像快速启动

## 快速开始

### 1. 配置认证

```bash
export QINIU_ACCESS_KEY="your-access-key"
export QINIU_SECRET_KEY="your-secret-key"
```

### 2. 创建配置文件

复制示例文件并修改：

```bash
cp terraform.tfvars.example terraform.tfvars
```

编辑 `terraform.tfvars`，填入必需参数：

```hcl
# 必填参数
model_api_key = "your-ai-model-api-key"

# 可选参数（根据需要取消注释）
# gitlab_base_url       = "http://111.62.212.109"
# gitlab_webhook_secret = "your-webhook-secret"
# gitlab_token          = "glpat-your-token"
```

### 3. 部署

```bash
terraform init
terraform plan
terraform apply
```

### 4. 获取访问信息

```bash
# 查看公网 IP
terraform output codeagent_public_ip

# 查看实例密码
terraform output -raw codeagent_instance_password
```

## 参数说明

### 必填参数

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `model_api_key` | string | AI 模型 API 密钥（必填） |

### 实例配置（可选）

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `instance_type` | string | `ecs.c1.c16m32` | ECS 实例规格（16核32G） |
| `instance_system_disk_size` | number | `100` | 系统盘大小（GB） |
| `internet_max_bandwidth` | number | `100` | 公网带宽（Mbps） |
| `cost_charge_type` | string | `PostPaid` | 计费类型（PostPaid/PrePaid） |
| `image_id` | string | `image-6937bf2694bf7c0fa986611a` | 预配置镜像 ID |

### GitLab 配置（可选）

| 参数名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `gitlab_base_url` | string | `""` | GitLab 实例 URL |
| `gitlab_webhook_secret` | string | `""` | Webhook 密钥（敏感信息） |
| `gitlab_token` | string | `""` | Personal Access Token（敏感信息） |

## 输出信息

| 输出名 | 说明 |
|--------|------|
| `codeagent_instance_id` | 实例 ID |
| `codeagent_public_ip` | 公网 IP 地址 |
| `codeagent_private_ip` | 内网 IP 地址 |
| `codeagent_instance_password` | SSH 登录密码（敏感） |
| `instance_details` | 实例完整信息 |

## 配置示例

### 基础配置（最小化）

```hcl
model_api_key = "sk-xxx"
```

### 完整配置（含 GitLab）

```hcl
# 基础配置
model_api_key = "sk-xxx"

# 实例配置
instance_type             = "ecs.c1.c16m32"
instance_system_disk_size = 100
internet_max_bandwidth    = 100
cost_charge_type          = "PostPaid"

# GitLab 集成
gitlab_base_url       = "http://111.62.212.109"
gitlab_webhook_secret = "012345"
gitlab_token          = "glpat-xxxxxxxxxx"
```

