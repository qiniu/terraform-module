# GitHub Self-hosted Runner Terraform 模板

快速在七牛云上部署 GitHub Actions Self-hosted Runner 的 Terraform 模板。

## 目录结构

```
github-self-hosted-runner/
├── README.md                  # 本文档
├── versions.tf                # Terraform 和 Provider 版本定义
├── variables.tf               # 输入变量定义
├── data.tf                    # 数据源和本地变量
├── main.tf                    # 虚拟机资源定义
├── runner_setup.sh            # Runner 自动配置脚本
├── outputs.tf                 # 输出值定义
└── how-to-setup-self-github-action-runner.md  # Runner 设置详细文档
```

## 前置要求

1. **Terraform** 版本 > 0.12.0
2. **七牛云账号** 并配置好认证信息
3. **GitHub Personal Access Token** (需要以下权限之一)
   - 仓库级：`repo` 权限
   - 组织级：`admin:org` 权限

### 获取 GitHub Token

访问 [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)

创建 token 并勾选权限：
- `repo` (完整仓库访问权限)
- 或 `admin:org` (组织管理权限)

## 快速开始

### 1. 创建配置文件

创建 `terraform.tfvars` 文件（注意：此文件包含敏感信息，不要提交到 Git）：

```hcl
# GitHub 配置
github_repo_url = "https://github.com/your-org/your-repo"
github_token    = "ghp_xxxxxxxxxxxxxxxxxxxx"  # 你的 GitHub Token

# 虚拟机配置（可选，使用默认值）
instance_type            = "ecs.t1.c2m4"    # 2核4GB
instance_system_disk_size = 50               # 50GB 磁盘

# Runner 配置（可选）
runner_name   = "my-custom-runner"           # 留空则自动生成
runner_labels = ["gpu", "production"]        # 自定义标签

# 其他配置
enable_docker = true                         # 是否安装 Docker
additional_packages = ["nodejs", "python3-pip"]  # 额外软件包
```

### 2. 初始化 Terraform

```bash
cd github-self-hosted-runner
terraform init
```

**Terraform 知识点：**
- `terraform init` 会下载所需的 provider 插件（qiniu、random）
- 只需要在第一次使用或修改 provider 配置后执行

### 3. 预览部署计划

```bash
terraform plan
```

**Terraform 知识点：**
- `terraform plan` 显示将要创建/修改/删除的资源
- 这是个安全的只读操作，不会真正创建资源
- 可以检查配置是否正确

### 4. 执行部署

```bash
terraform apply
```

**Terraform 知识点：**
- `terraform apply` 会真正创建资源
- 执行前会再次显示计划，需要输入 `yes` 确认
- 部署过程中会创建：
  1. 随机字符串（资源后缀）
  2. 随机密码（虚拟机 root 密码）
  3. 查询 Ubuntu 24.04 镜像
  4. 创建虚拟机实例
  5. 执行初始化脚本（安装 Runner）

### 5. 查看输出信息

部署完成后会显示：

```
Outputs:

runner_instance_id = "i-xxxxxxxx"
runner_name = "runner-abc123"
runner_private_ip = "10.0.0.123"
runner_labels = ["self-hosted", "linux", "x64", "gpu", "production"]
ssh_connection_command = "ssh root@10.0.0.123"
runner_status_check = "ssh root@10.0.0.123 'cd /home/runner/actions-runner && sudo ./svc.sh status'"
```

要查看敏感信息（root 密码）：

```bash
terraform output instance_password
```

## 配置参数说明

### 必填参数

| 参数 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `github_repo_url` | string | GitHub 仓库 URL | `https://github.com/owner/repo` |
| `github_token` | string | GitHub Personal Access Token | `ghp_xxxxxxxxxxxx` |

### 可选参数

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `instance_type` | string | `ecs.t1.c2m4` | 虚拟机规格（见下表） |
| `instance_system_disk_size` | number | `50` | 系统盘大小（GiB） |
| `runner_name` | string | 自动生成 | Runner 名称 |
| `runner_labels` | list(string) | `[]` | 自定义标签 |
| `runner_username` | string | `runner` | Runner 进程的用户名 |
| `enable_docker` | bool | `true` | 是否安装 Docker |
| `additional_packages` | list(string) | `[]` | 额外安装的软件包 |

### 虚拟机规格选择

根据工作负载选择合适的规格：

| 工作类型 | 推荐规格 | CPU/内存 | 适用场景 |
|---------|---------|----------|---------|
| 轻量级测试 | `ecs.t1.c2m4` | 2核/4GB | 单元测试、linting |
| 前端构建 | `ecs.t1.c4m8` | 4核/8GB | npm/yarn 构建 |
| 后端编译 | `ecs.t1.c8m16` | 8核/16GB | Java/Go 编译 |
| Docker 构建 | `ecs.t1.c8m16` | 8核/16GB | 镜像构建 |
| 大型项目 | `ecs.t1.c16m32` | 16核/32GB | 复杂构建流程 |

详细规格参考 `variables.tf` 中的 validation 规则。

## 使用场景示例

### 场景 1: 基础 CI/CD Runner

```hcl
github_repo_url = "https://github.com/myorg/myapp"
github_token    = "ghp_xxxxxxxxxxxx"
instance_type   = "ecs.t1.c2m4"
enable_docker   = true
```

在 workflow 中使用：

```yaml
# .github/workflows/ci.yml
jobs:
  build:
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - run: npm test
```

### 场景 2: Docker 构建专用 Runner

```hcl
github_repo_url = "https://github.com/myorg/myapp"
github_token    = "ghp_xxxxxxxxxxxx"
instance_type   = "ecs.t1.c8m16"
runner_labels   = ["docker", "high-memory"]
enable_docker   = true
```

在 workflow 中使用：

```yaml
jobs:
  docker-build:
    runs-on: [self-hosted, docker, high-memory]
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t myapp .
```

### 场景 3: 多语言开发环境

```hcl
github_repo_url = "https://github.com/myorg/myapp"
github_token    = "ghp_xxxxxxxxxxxx"
instance_type   = "ecs.t1.c4m8"
runner_labels   = ["nodejs", "python", "go"]
additional_packages = [
  "nodejs",
  "npm",
  "python3-pip",
  "golang-go"
]
```

## 部署后管理

### 检查 Runner 状态

```bash
# SSH 登录到虚拟机
ssh root@<runner_private_ip>

# 查看服务状态
cd /home/runner/actions-runner
sudo ./svc.sh status

# 查看实时日志
journalctl -u actions.runner.* -f
```

### 在 GitHub 上验证

访问你的仓库：`Settings` → `Actions` → `Runners`

应该能看到状态为 "Idle" 的 Runner。

### 更新 Runner

```bash
# SSH 登录
ssh root@<runner_private_ip>

# 停止服务
cd /home/runner/actions-runner
sudo ./svc.sh stop

# 切换到 runner 用户
su - runner

# 下载新版本
cd actions-runner
# ... 按照官方文档更新

# 重启服务
sudo ./svc.sh start
```

### 移除 Runner

```bash
# 方法 1: 使用 Terraform 销毁
terraform destroy

# 方法 2: 手动移除（如果需要保留虚拟机）
ssh root@<runner_private_ip>
cd /home/runner/actions-runner
sudo ./svc.sh stop
sudo ./svc.sh uninstall
./config.sh remove --token <new_token>
```

## Terraform 基础知识速查

### 常用命令

```bash
# 初始化项目（下载 provider）
terraform init

# 格式化代码
terraform fmt

# 验证配置
terraform validate

# 查看当前状态
terraform show

# 列出所有资源
terraform state list

# 查看某个资源详情
terraform state show qiniu_compute_instance.github_runner

# 查看所有输出值
terraform output

# 查看特定输出值
terraform output runner_private_ip

# 销毁所有资源
terraform destroy
```

### 工作流程

```
编写配置 → init → plan → apply → 资源创建完成
                           ↓
                        修改配置
                           ↓
                    plan → apply → 资源更新
                           ↓
                        destroy → 资源销毁
```

### 核心概念

1. **Resource（资源）**: 要创建的云资源（虚拟机、数据库等）
2. **Variable（变量）**: 输入参数，可自定义
3. **Output（输出）**: 部署完成后显示的信息
4. **Data Source（数据源）**: 查询已存在的资源
5. **Local（本地变量）**: 内部计算使用的变量
6. **Provider（提供商）**: 云服务商的 API 插件

### State 管理

Terraform 会在本地生成 `terraform.tfstate` 文件记录资源状态：

- 不要手动编辑此文件
- 团队协作时建议使用远程 backend（S3、Consul 等）
- 可以用 `.gitignore` 忽略此文件

## 故障排查

### Runner 未显示在 GitHub

1. 检查 GitHub Token 权限
   ```bash
   # 测试 token 是否有效
   curl -H "Authorization: token ghp_xxxx" https://api.github.com/user
   ```

2. 查看虚拟机日志
   ```bash
   ssh root@<runner_ip>
   journalctl -u actions.runner.* --no-pager -n 100
   ```

3. 检查初始化脚本执行情况
   ```bash
   ssh root@<runner_ip>
   cat /var/log/cloud-init-output.log
   ```

### 磁盘空间不足

```bash
# 清理 Docker 缓存
docker system prune -af --volumes

# 清理旧的 workflow 临时文件
cd /home/runner/actions-runner/_work/_temp
rm -rf *
```

### 连接超时

检查网络配置：
```bash
# 测试网络连接
ping github.com
curl -I https://api.github.com
```

### 重新配置 Runner

如果需要重新配置（比如更换仓库）：

```bash
ssh root@<runner_ip>
cd /home/runner/actions-runner

# 停止服务
sudo ./svc.sh stop

# 移除旧配置
./config.sh remove --token <removal_token>

# 重新配置（获取新的 registration token）
./config.sh --url <new_url> --token <new_token> --labels ...

# 重新安装服务
sudo ./svc.sh install runner
sudo ./svc.sh start
```

## 安全建议

1. **不要将 `terraform.tfvars` 提交到 Git**
   ```bash
   echo "terraform.tfvars" >> .gitignore
   echo "*.tfstate*" >> .gitignore
   ```

2. **使用有限权限的 Token**
   - 仓库级 Runner 只需要 `repo` 权限
   - 避免使用 `admin:org` 除非必要

3. **定期更新系统和 Runner**
   ```bash
   # 登录虚拟机
   apt update && apt upgrade -y
   ```

4. **限制 Runner 用户的 sudo 权限**
   - 模板已默认限制为 `docker` 和 `systemctl`
   - 如需修改，编辑 `runner_setup.sh` 中的 sudo 配置

5. **使用防火墙**
   ```bash
   ufw enable
   ufw allow ssh
   ufw allow out 443/tcp  # HTTPS to GitHub
   ```

## 高级用法

### 一虚拟机多 Runner

修改模板创建多个 runner 目录：

```hcl
# 需要自定义模板，不在本示例范围内
# 建议：生产环境推荐一虚拟机一 Runner，配合自动扩缩容
```

### 组织级 Runner

修改 `runner_setup.sh` 中的 API 端点：

```bash
# 将
https://api.github.com/repos/$OWNER/$REPO/actions/runners/registration-token

# 改为
https://api.github.com/orgs/$ORG/actions/runners/registration-token
```

### 自定义镜像

如果需要使用自定义镜像而不是 Ubuntu 24.04：

修改 `data.tf`:
```hcl
locals {
  ubuntu_image_id = "your-custom-image-id"
}
```

## 参考资料

- [GitHub Actions Self-hosted Runners 官方文档](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Terraform 官方文档](https://www.terraform.io/docs)
- 项目内文档: `how-to-setup-self-github-action-runner.md`

## License

MIT
