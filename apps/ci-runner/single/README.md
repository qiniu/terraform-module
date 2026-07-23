# CI Runner 单机一键部署

本目录是 [`qiniu/ci-runner`](https://github.com/qiniu/ci-runner) 的 Terraform 单机部署封装，用于在七牛云上创建一台 ECS，并自动安装、配置和启动 `runnerd`。

该模块会创建：

- 一台 Ubuntu 24.04 LTS ECS；
- 一个由七牛云生成的部署密钥对；
- 一个将公网 HTTPS 请求转发到 `runnerd_port` 的 HTTPProxy；
- 可选的 SSH 端口转发；
- `runnerd.yaml`、GitHub App 私钥和 systemd 服务；
- 一个使用本机 SQLite 数据库的单实例 `runnerd`。

`terraform apply` 会等待服务启动并通过 `/healthz` 健康检查。

> 这是单机部署方案，不包含高可用、外部数据库或数据备份。生产使用前请结合 [`ci-runner` 部署检查清单](https://github.com/qiniu/ci-runner/blob/main/docs/deployment-smoke.zh.md) 完成验证。

## 前置条件

- Terraform `>= 1.6.0`；
- Qiniu Provider `1.0.0`；
- 一个支持 `public_access_http_proxy` 的七牛云区域；
- 该区域恰好存在一个可用的 Ubuntu `24.04 LTS` 官方镜像；
- 一个 GitHub.com GitHub App；
- 目标 ECS 能访问 Ubuntu 软件源和 GitHub Releases。

Qiniu Provider 当前需要按仓库根目录的[本地安装说明](../../../README.md#基于本地-terraform-运行)安装。安装后设置七牛云凭证和区域：

```bash
export QINIU_ACCESS_KEY="<qiniu-access-key>"
export QINIU_SECRET_KEY="<qiniu-secret-key>"
export QINIU_REGION_ID="<qiniu-region-id>"
```

## 1. 准备 GitHub App

先创建 GitHub App，并准备以下信息：

- App ID；
- App slug；
- OAuth Client ID 和 Client secret；
- GitHub App PEM 私钥；
- 初始管理员的 GitHub 数字用户 ID。

首次创建 GitHub App 时，可以暂时填写有效的占位 callback 和 webhook URL；Terraform 部署完成后，再替换为模块输出的正式地址。

GitHub App 至少需要订阅 `Workflow jobs` 事件。实际所需的 Repository 和 Organization 权限取决于使用仓库级还是组织级 runner，请以上游项目的 [GitHub App permissions](https://github.com/qiniu/ci-runner#github-app-permissions) 为准。

## 2. 配置部署参数

进入本目录：

```bash
cd apps/ci-runner/single
```

创建 `terraform.tfvars`：

```hcl
runnerd_version = "v0.2.3"

github_app_id          = 123456
github_app_slug        = "your-github-app-slug"
github_oauth_client_id = "Iv1.your-client-id"

bootstrap_admin_github_user_id = 12345678

# 可选
instance_type             = "ecs.t1s.c1m2"
system_disk_size          = 20
internet_max_bandwidth    = 100
enable_ssh_port_forward   = false
```

`runnerd_version` 必须是 [`qiniu/ci-runner` Releases](https://github.com/qiniu/ci-runner/releases) 中存在的明确版本标签，不能使用 `latest`。示例版本仅用于展示，请按需选择版本。

将敏感值通过 Terraform 环境变量传入：

```bash
export TF_VAR_github_oauth_client_secret="<github-oauth-client-secret>"
export TF_VAR_github_app_private_key_base64="$(base64 < /path/to/github-app.pem | tr -d '\n')"
```

本目录的 `.gitignore` 已忽略 `*.tfvars`、`env.sh` 和 Terraform state；仍需确认这些文件不会被复制、上传或提交到其他位置。

## 3. 部署

```bash
terraform init
terraform plan
terraform apply
```

部署成功后，查看输出：

```bash
terraform output
```

## 4. 完成 GitHub App 配置

读取 Terraform 生成的地址和 webhook secret：

```bash
terraform output -raw dashboard_url
terraform output -raw github_oauth_callback_url
terraform output -raw github_webhook_url
terraform output -raw github_webhook_secret
```

回到 GitHub App 设置页并更新：

| GitHub App 配置 | Terraform 输出 |
| --- | --- |
| Callback URL | `github_oauth_callback_url` |
| Webhook URL | `github_webhook_url` |
| Webhook secret | `github_webhook_secret` |

确认 webhook 已启用并订阅 `Workflow jobs`；如需将 `workflow_run` 作为补偿信号，可同时订阅 `Workflow runs`。然后将 GitHub App 安装到需要使用 runner 的仓库或组织。

## 5. 完成 runnerd 初始化

打开 `dashboard_url`，使用 `bootstrap_admin_github_user_id` 对应的 GitHub 账号登录。之后至少还需要：

1. 为账号或组织配置 Sandbox service API URL 和 API key，或者启用管理员级 fallback；
2. 创建 runner spec，并关联一个包含 GitHub Actions runner 的七牛 Sandbox 模板；
3. 按需配置 runner group 和 repository policy；
4. 用 `runs-on: [self-hosted, e2b]` 的测试工作流验证任务调度。

这些属于 `runnerd` 的运行配置，不由本 Terraform 模块创建。详细步骤参见上游 [`ci-runner` README](https://github.com/qiniu/ci-runner/blob/main/README.zh.md) 和[部署检查清单](https://github.com/qiniu/ci-runner/blob/main/docs/deployment-smoke.zh.md)。

## 升级或重新安装 runnerd

修改 `runnerd_version` 后执行：

```bash
terraform plan
terraform apply
```

如果需要在版本和配置均未变化时强制重新执行安装：

```bash
terraform apply -replace=qiniu_compute_instance_exec.install_runnerd
```

修改 GitHub App 配置、私钥或初始管理员也会触发重新安装。基础设施参数变化时，Terraform 会按 Qiniu Provider 的资源行为更新或替换实例，请在执行前检查 plan。

## SSH 调试

SSH 端口转发默认关闭。设置以下变量并重新执行 `terraform apply` 可启用：

```hcl
enable_ssh_port_forward = true
```

查看公网 SSH 端点：

```bash
terraform output -json ssh_endpoints
```

将私钥保存到仅当前用户可读的临时文件：

```bash
umask 077
terraform output -raw ssh_private_key > ci-runner-ssh.pem
```

调试结束后，建议关闭 `enable_ssh_port_forward`，重新执行 `terraform apply`，并安全删除导出的私钥文件。

## 销毁

```bash
terraform plan -destroy
terraform destroy
```

销毁会删除本模块创建的 ECS、密钥对和公网访问资源。SQLite 数据保存在实例系统盘的 `/var/lib/runnerd/runnerd.db`，销毁实例前请自行备份需要保留的数据。

## 输入变量

| 名称 | 必填 | 默认值 | 说明 |
| --- | --- | --- | --- |
| `runnerd_version` | 是 | - | `runnerd` GitHub Release 标签，不能为 `latest` |
| `github_app_id` | 是 | - | GitHub App 数字 ID |
| `github_app_slug` | 是 | - | GitHub App slug |
| `github_oauth_client_id` | 是 | - | GitHub App OAuth Client ID |
| `github_oauth_client_secret` | 是 | - | GitHub App OAuth Client secret，敏感 |
| `github_app_private_key_base64` | 是 | - | Base64 编码的 GitHub App PEM 私钥，敏感 |
| `bootstrap_admin_github_user_id` | 是 | - | 初始管理员的 GitHub 数字用户 ID |
| `instance_type` | 否 | `ecs.t1s.c1m2` | 以 `ecs.` 开头的 ECS 实例规格 |
| `system_disk_size` | 否 | `20` | 系统盘大小，20–500 GiB 且必须是 10 的倍数 |
| `internet_max_bandwidth` | 否 | `100` | PeakBandwidth 公网带宽，可选 50、100 或 200 Mbps |
| `enable_ssh_port_forward` | 否 | `false` | 是否通过 PortForward 暴露 SSH 22 端口 |

## 输出

| 名称 | 敏感 | 说明 |
| --- | --- | --- |
| `dashboard_url` | 否 | `runnerd` 控制台 HTTPS 地址 |
| `github_oauth_callback_url` | 否 | GitHub App OAuth callback URL |
| `github_webhook_url` | 否 | GitHub App webhook URL |
| `github_webhook_secret` | 是 | GitHub webhook 签名密钥 |
| `ssh_endpoints` | 否 | 启用 SSH 转发后的公网 `IP:Port` 列表 |
| `ssh_private_key` | 是 | 启用 SSH 转发后使用的部署私钥 |

## 安全注意事项

- Terraform state 包含 GitHub OAuth secret、GitHub App 私钥、webhook secret、session secret、加密密钥和 ECS 部署私钥，必须加密存储并严格限制访问；
- 不要把 `terraform.tfvars`、state、PEM 私钥或导出的 SSH 私钥提交到版本库；
- SSH 转发仅在调试时启用；
- 本模块固定从 GitHub Release 下载指定版本，请在升级前确认版本来源和变更内容；
- 该部署会产生 ECS 和公网带宽费用，请在不用时及时销毁。
