# DeepSeek Harness 单机部署

本目录在七牛云创建一台 Ubuntu 24.04 ECS，并安装固定版本的 DeepSeek Harness。公网访问经 HTTPS HTTPProxy 转发到 Nginx，Web 界面使用 Basic Auth 保护。

这是单机方案，不包含高可用、自动备份、自定义域名或外部数据库。

## 前置条件

- Terraform `>= 1.6.0`；
- Qiniu Provider `1.0.0`，按仓库根目录的[本地安装说明](../../README.md#基于本地-terraform-运行)安装；
- 支持 `public_access_http_proxy` 的七牛云区域，并且该区域须恰好存在一个 Ubuntu 24.04 LTS 官方镜像；
- ECS 能访问 Ubuntu 软件源、nodejs.org 和 npm registry。

设置七牛云凭证和区域（不要把真实值写入源码）：

```bash
export QINIU_ACCESS_KEY="<qiniu-access-key>"
export QINIU_SECRET_KEY="<qiniu-secret-key>"
export QINIU_REGION_ID="<qiniu-region-id>"
```

## 部署

```bash
cd apps/deepseek-harness
terraform init
terraform plan -out=deepseek-harness.tfplan
terraform apply deepseek-harness.tfplan
```

默认创建 `ecs.t1s.c2m4`、40 GiB 系统盘和 100 Mbps 峰值带宽，采用 `PostPaid` 按量计费。也可在本地 `terraform.tfvars` 中设置实例规格、磁盘、带宽及预付费参数；部署和保留资源都会产生费用。

部署成功后查看 Harness 地址、用户名和网页预览地址：

```bash
terraform output -raw dsh_web_public_url
terraform output -raw dsh_web_username
```

密码是 sensitive output，仅在需要时安全读取，不要粘贴到日志、聊天或脚本中：

```bash
terraform output -raw dsh_web_password
```

打开 `dsh_web_public_url`，使用 `dsh_web_username`（默认 `admin`）和上述随机密码通过 HTTP Basic Auth 登录。模型 API Key 仅在登录后的 Web 设置中配置，保存在服务器上，不作为 Terraform 输入，也不会进入 Terraform state。

也可以在 Terraform 中通过环境变量提供七牛 MaaS API Key。`qiniu_maas_api_key` 会渲染为 systemd 的 `QINIU_MAAS_API_KEY`；其他需要传给 Harness 的变量可通过 `dsh_environment` 设置：

```hcl
qiniu_maas_api_key = "<qiniu-api-key>"

# 默认启用；设为 false 可跳过七牛 MaaS Web 插件安装
enable_dsh_qiniu_maas_plugin = true

dsh_environment = [
  {
    name  = "NODE_OPTIONS"
    value = "--max-old-space-size=4096"
  },
]
```

这些变量写入 root-owned、权限为 `0600` 的 systemd 环境文件，不会写入 Ansible 日志或 Terraform output。

启用 code-server 时，可运行 `terraform output -raw code_server_public_url` 获取地址，并使用与 Harness Web Basic Auth 相同的密码通过 code-server 自带密码认证登录。密码是 sensitive output，不要粘贴到日志、聊天或网页内容中。code-server 默认关闭，可通过 `enable_code_server = true` 开启；它仅监听实例内的 `127.0.0.1:3083`，公网入口由独立 HTTPProxy 转发至 Nginx 的 `3084`。

可通过 `enable_code_server = false` 跳过 code-server 的安装和公网入口创建；此时 `code_server_public_url` 为 `null`。已安装实例切换为关闭时会停止并禁用该服务，但保留已下载的文件和配置。

默认还会安装 FileBrowser Quantum。运行 `terraform output -raw filebrowser_public_url` 获取地址，并使用与 Harness Web 相同的用户名和密码通过 FileBrowser 自带认证登录；它不使用 Nginx Basic Auth。FileBrowser 只监听实例内的 `127.0.0.1:3085`，公网 HTTPProxy 经 Nginx `3086` 转发。其根目录是 `/home/dsh`，普通用户默认看不到点号目录，但管理员可在 UI 中主动显示。

可通过 `enable_filebrowser = false` 停止并禁用 FileBrowser，同时移除公网入口；`filebrowser_public_url` 变为 `null`。已下载二进制、配置、数据库和长期 agent token 会保留，以便重新启用后继续使用。

服务以无 sudo 权限的 `dsh` 用户运行，`HOME=/home/dsh`；Harness 数据目录为 `/home/dsh/.dsh`（即 `DSH_HOME`），systemd 工作目录为 `/home/dsh/workspace`。

## 网页预览与运行环境 skill

网页预览入口是独立的公开 HTTPS 地址：任何知道地址的人都可以访问，且不需要 Harness 的 Basic Auth。请只在确认可以公开的页面上使用它们；不要在页面或日志中写入密码、令牌、私钥或其他敏感信息。

Preview 数量通过 `preview_count` 配置，支持 `0..4` 个。用户网页开发服务应按槽位监听 `0.0.0.0:30080` 到 `0.0.0.0:30083`，不要自行暴露其他端口。Preview 地址由 HTTPProxy 直接转发到对应应用，不经过 Nginx；尚未启动开发服务时返回 5xx（通常为 `502`，HTTPProxy 也可能返回 `503`）属于正常状态。

安装器会管理用户级运行环境 skill：

```text
/home/dsh/.agents/skills/las-dsh-environment/SKILL.md
```

它会告知 Harness 网页开发时应使用的工作目录、监听地址和预览地址。`las-dsh-environment` 是用户级 skill，项目级同名 skill 的优先级更高，会遮蔽它；如需覆盖，请明确使用项目级同名名称。skill 正文更新后，需在新会话中使用，或再次加载该 skill 才能看到新内容；已加载旧正文的会话不会被主动改写。

启用 FileBrowser 时同时安装 `las-filebrowser-share` skill，用于创建临时下载链接、分享文件或目录、查询或撤销分享、打包目录、创建上传收件箱、安全检索以及计算 SHA-256。它通过 `/home/dsh/.filebrowser/agent-api-token` 中权限为 `0600` 的 10 年 token 调用本机 API；token 不会进入 Terraform output、日志或 skill 正文。禁用 FileBrowser 时不会安装该 Skill，并会清理已存在的 Skill 目录。

## 网络与 SSH

实例无需公网 IP；Web 服务只通过 HTTPS HTTPProxy 暴露。SSH 公网转发默认关闭，仅在调试时开启：

```hcl
enable_ssh_port_forward = true
```

应用变更后可运行：

```bash
./scripts/ssh.sh
./scripts/ssh.sh "cat /var/log/las-dsh-installer.log"
./scripts/ssh.sh "journalctl -u deepseek-harness --since '10 min ago' --no-pager"
```

脚本会从本地 Terraform state 提取部署密钥写入权限为 `0600` 的临时文件，并在 SSH 结束后清理；调试结束后应关闭 SSH 转发并再次应用配置。state 同时包含 Basic Auth 密码和部署私钥，必须加密保存并严格限制访问。

## 升级与离线缓存验证

Harness 固定为 `@deepseek-ai/dsh@0.1.0-rc.7`，Node.js 固定为 `24.19.0`。升级时修改 `modules/ansible-installer/ansible/roles/deepseek_harness/defaults/main.yml` 中的固定版本，审阅 plan 后应用：

```bash
terraform plan
terraform apply
```

### Ansible 安装器迁移状态

实际 `qiniu_compute_instance_exec` 对 131072 个 ASCII 字符的无敏感 no-op 命令返回 `/bin/bash: Argument list too long`。根模块因此使用 `modules/ansible-installer` 的显式 Ansible 文件清单：每个运行时文件和无敏感 bootstrap 脚本都由上游 `instance-exec-file-transfer` 模块逐个传输并校验 SHA-256。最终短命令在传输完成后运行 bootstrap；不会传输或解压 Ansible 归档。

`modules/ansible-installer` 需要访问 GitHub 的 uv release，以及供 `uv sync --locked` 使用的 PyPI（`pypi.org/simple`）或已配置的 Python package index。CI 同时覆盖 Ansible bootstrap、根模块接线和公共文件传输模块。一次性七牛云主机已完成真实双次安装验收：第二次运行结果为 `changed=0 failed=0`，Harness 与 code-server 认证边界、未启动 Preview 的 `503` 响应，以及 `dsh` 用户的 Node.js、uv、uvx 和部署技能均已验证。

若版本和配置没有变化，但需要强制重新执行安装：

```bash
terraform apply -replace=qiniu_compute_instance_exec.install_dsh
```

安装器会先预热 npm 缓存，再以离线模式启动固定版本。首次部署需要真实访问 npm registry；后续重复执行会复用服务用户 `dsh` 的生产缓存。

## 备份与持久化

Harness 配置和运行数据位于 `/home/dsh/.dsh`，工作文件位于 `/home/dsh/workspace`。重复执行安装或使用上述 `-replace` 不会主动清空这两个目录，但它们都在 ECS 系统盘上；升级、替换或销毁实例前，请自行备份到实例外的持久存储并验证可恢复性。

## 销毁

先确认销毁计划，再删除资源：

```bash
terraform plan -destroy
terraform destroy
```

销毁会删除 ECS、部署密钥对及公网访问资源，并使系统盘上的 Harness 数据不可用。确认备份完成后再执行。
