# 七牛云 Terraform 应用与模块

这个仓库提供基于七牛云 Qiniu Provider 的 Terraform 应用模板和可复用模块，包含：

- `apps/`：可以直接初始化和部署的应用级 Terraform 根模块；
- `pkg/`：供多个应用复用的 Terraform 模块；
- `docs/qiniu-provider/`：Qiniu Provider 的资源和数据源参考文档。

仓库不是一个单一的 Terraform 根模块。使用前请先选择具体的 `apps/...` 或 `pkg/...` 目录，再执行 Terraform 命令。

## 目录导航

### 可部署应用

| 入口 | 用途 | 文档与示例 | Terraform 要求 |
| --- | --- | --- | --- |
| [`apps/ci-runner/single`](apps/ci-runner/single) | 单 ECS 部署 Qiniu CI Runner，包含 GitHub App 配置、runnerd 安装和可选 SSH 调试 | [`README.md`](apps/ci-runner/single/README.md) | `>= 1.6.0` |
| [`apps/codeagent/standard`](apps/codeagent/standard) | 单 ECS 部署 CodeAgent Standard Edition | [`README.md`](apps/codeagent/standard/README.md)、[`terraform.tfvars.example`](apps/codeagent/standard/terraform.tfvars.example) | `>= 0.13.0` |
| [`apps/codeagent/codeagent_and_gitlab`](apps/codeagent/codeagent_and_gitlab) | 创建 GitLab 和 CodeAgent 两台 ECS，并配置 webhook | [`terraform.tfvars.example`](apps/codeagent/codeagent_and_gitlab/terraform.tfvars.example) | `>= 0.13.0` |
| [`apps/deepseek-harness`](apps/deepseek-harness) | 单机部署 DeepSeek Harness、Nginx、code-server 和预览环境 | [`README.md`](apps/deepseek-harness/README.md) | `>= 1.6` |
| [`apps/mysql/standalone`](apps/mysql/standalone) | 创建 Ubuntu 24.04 单实例 MySQL | [查看目录](apps/mysql/standalone) | `> 0.12.0` |
| [`apps/mysql/replication`](apps/mysql/replication) | 创建 MySQL 主从复制集群 | [查看目录](apps/mysql/replication) | `> 0.12.0` |
| [`apps/openclaw`](apps/openclaw) | 在七牛云部署 OpenClaw 个人 AI 助手 | [`terraform.tfvars.example`](apps/openclaw/terraform.tfvars.example) | `>= 0.13.0` |

`codeagent_and_gitlab`、MySQL 和 OpenClaw 目录目前没有独立的完整部署 README。使用这些入口前请直接阅读入口目录中的 Terraform 文件和示例；MySQL 的共享变量与版本约束位于 [`apps/mysql/common`](apps/mysql/common)，复制集群还有独立的 [`repl_variables.tf`](apps/mysql/replication/repl_variables.tf)。`codeagent_and_gitlab` 还会执行远程配置脚本，使用前必须审阅脚本和敏感配置处理方式。

### 可复用模块

| 入口 | 用途 | 文档 |
| --- | --- | --- |
| [`pkg/instance-exec-file-transfer`](pkg/instance-exec-file-transfer) | 通过 `qiniu_compute_instance_exec` 向实例发布文件；根据内容大小自动选择直传或分片传输 | [`README.md`](pkg/instance-exec-file-transfer/README.md) |

`apps/*/modules`、`apps/mysql/common` 和 `pkg/*/modules` 是内部组合模块或实现细节，不是独立的应用入口。`pkg/instance-exec-file-transfer/tests/live` 是需要真实云资源的集成测试目录。

## 快速开始

### 前置条件

1. 安装 Terraform。不同入口的最低版本不同，最终以目标目录的 `versions.tf` 为准；当前 CI 使用 Terraform `1.14` 验证主要模块。
2. 按下文安装 Qiniu Provider `1.0.0`。该 Provider 当前未发布到 `registry.terraform.io`，不能依赖 Terraform 自动下载。
3. 准备七牛云账号凭证和目标区域。建议只通过环境变量注入，不要写入源码或普通配置文件：

```bash
export QINIU_ACCESS_KEY="<qiniu-access-key>"
export QINIU_SECRET_KEY="<qiniu-secret-key>"
export QINIU_REGION_ID="<qiniu-region-id>"
```

### 运行一个应用

下面以单实例 MySQL 为例。它会创建真实云资源，执行前请先检查 plan：

```bash
cd apps/mysql/standalone
terraform init
terraform plan -out=terraform.tfplan
terraform apply terraform.tfplan
```

`mysql_password` 可以不设置，模块会生成随机密码；敏感输出只应在确认终端和状态文件访问权限后读取。使用其他应用时，进入对应目录并按照其 README 或 `terraform.tfvars.example` 配置变量。

常用操作：

```bash
# 重新查看变更
terraform plan

# 预览销毁操作
terraform plan -destroy

# 销毁当前目录创建的资源
terraform destroy
```

Terraform 只会自动加载 `terraform.tfvars`、`terraform.tfvars.json`、`*.auto.tfvars` 和 `*.auto.tfvars.json`。其他文件需要显式传入，例如 `terraform plan -var-file=dev.tfvars`。

## 安装 Qiniu Provider

### 下载 Provider

当前可用的 Provider `1.0.0` 二进制下载地址如下：

| 平台 | 下载地址 |
| --- | --- |
| `darwin_arm64` | [terraform-provider-qiniu](http://srz5669lx.hn-bkt.clouddn.com/terraformprovider/registry.terraform.io/qiniu/qiniu/1.0.0/darwin_arm64/terraform-provider-qiniu) |
| `darwin_amd64` | [terraform-provider-qiniu](http://srz5669lx.hn-bkt.clouddn.com/terraformprovider/registry.terraform.io/qiniu/qiniu/1.0.0/darwin_amd64/terraform-provider-qiniu) |
| `linux_arm64` | [terraform-provider-qiniu](http://srz5669lx.hn-bkt.clouddn.com/terraformprovider/registry.terraform.io/qiniu/qiniu/1.0.0/linux_arm64/terraform-provider-qiniu) |
| `linux_amd64` | [terraform-provider-qiniu](http://srz5669lx.hn-bkt.clouddn.com/terraformprovider/registry.terraform.io/qiniu/qiniu/1.0.0/linux_amd64/terraform-provider-qiniu) |

CI 当前对 `linux_amd64` 使用以下 SHA-256 校验值：

```text
e2d367648b559829632767ab372a1eb6693bbf2bef92af63c25722759b65c6eb
```

以 Linux amd64 为例，下载后校验并设置可执行权限：

```bash
provider_url="http://srz5669lx.hn-bkt.clouddn.com/terraformprovider/registry.terraform.io/qiniu/qiniu/1.0.0/linux_amd64/terraform-provider-qiniu"
mirror_dir="${HOME}/.terraform.d/plugin-mirror/registry.terraform.io/qiniu/qiniu/1.0.0/linux_amd64"
curl -fL "$provider_url" -o terraform-provider-qiniu
echo "e2d367648b559829632767ab372a1eb6693bbf2bef92af63c25722759b65c6eb  terraform-provider-qiniu" | sha256sum -c -
chmod +x terraform-provider-qiniu
mkdir -p "${HOME}/.terraform.d/plugin-cache" "$mirror_dir"
install -m 0755 terraform-provider-qiniu "$mirror_dir/terraform-provider-qiniu"
```

其他平台应使用对应的目录名；仓库 CI 目前只固定校验 `linux_amd64`，不要把该校验值套用到其他平台。

### 配置 filesystem mirror

Terraform CLI 配置文件默认为 `$HOME/.terraformrc`，也可以通过 `TF_CLI_CONFIG_FILE` 指定其他路径。将下面的 `<ABSOLUTE_HOME>` 替换为当前用户的绝对 home 路径；Terraform CLI 配置中的 mirror 路径应使用绝对路径：

```hcl
plugin_cache_dir = "<ABSOLUTE_HOME>/.terraform.d/plugin-cache"

provider_installation {
  filesystem_mirror {
    path    = "<ABSOLUTE_HOME>/.terraform.d/plugin-mirror"
    include = ["registry.terraform.io/qiniu/qiniu"]
  }

  # 其他官方 Provider 仍从 registry.terraform.io 下载
  direct {
    exclude = ["registry.terraform.io/qiniu/qiniu"]
  }
}
```

将二进制放入与平台匹配的目录，例如：

```text
<ABSOLUTE_HOME>/.terraform.d/plugin-mirror/
└── registry.terraform.io/
    └── qiniu/
        └── qiniu/
            └── 1.0.0/
                └── linux_amd64/
                    └── terraform-provider-qiniu
```

## 凭证、状态与费用

- 不要提交 `terraform.tfvars`、`*.tfstate*`、PEM 私钥、访问密钥、API token 或其他敏感文件；仓库的 `.gitignore` 已覆盖常见 Terraform 状态和变量文件，但仍需检查实际提交内容。
- Terraform state 可能包含实例密码、私钥、Webhook secret 和其他敏感输出，应使用受控且加密的存储，并限制读取权限。
- `terraform apply`、`terraform destroy` 以及 `tests/live` 集成测试可能创建或删除真实资源并产生费用；它们不属于无凭证的默认验证流程。
- 执行 apply 前先保存并审阅 plan，确认区域、实例规格、带宽和计费类型符合预期。

## Provider 参考文档

- [Provider 配置与 Schema](docs/qiniu-provider/index.md)
- [Resources](docs/qiniu-provider/resources)
- [Data Sources](docs/qiniu-provider/data-sources)

这些文档由 Terraform Provider 文档工具生成；具体行为和版本约束以目标模块代码及 Provider 版本为准。

## 验证与贡献

仓库包含多个独立根模块，不要将仓库根目录当作全仓 Terraform 验证入口。修改某个模块后，进入受影响目录执行最小范围验证：

```bash
# 格式检查
terraform fmt -check -recursive <受影响目录>

# 模块验证（先按模块文档完成 init）
terraform -chdir=<模块目录> init
terraform -chdir=<模块目录> validate

# 目录存在 *.tftest.hcl 时再运行
terraform -chdir=<模块目录> test -no-color

# 空白和补丁检查
git diff --check
```

当前 CI 验证 `apps/openclaw`、`apps/ci-runner/single`、`apps/deepseek-harness` 和 `pkg/instance-exec-file-transfer` 根模块，并额外覆盖 file-transfer 的 `direct`、`chunked` 子模块以及 DeepSeek Harness 的 `infrastructure`、`ansible-installer` 子模块。MySQL、CodeAgent 等入口需要结合目标环境自行验证。`terraform test` 中的 mock apply 不等同于真实云部署，真实集成测试必须单独确认凭证、资源和费用范围。

## 七牛资源栈 Provider 白名单

> 这是七牛资源栈的强约束：在资源栈中运行 Terraform 时，只能使用下表列出的 Provider、Source 和版本。禁止在资源栈模板中引入白名单之外的 Provider；如确有需要，先提交工单申请支持。该表是资源栈运行限制，不代表每个本地 Terraform 模块都会使用表中的全部 Provider。

详细说明请参考：[资源栈常见问题排查](https://developer.qiniu.com/las/kb/13334/faq-rsf-troubleshooting?category=kb)

| Provider | Source | Version | 用途 |
| --- | --- | --- | --- |
| qiniu | qiniu/qiniu | 1.0.0 | 管理七牛云资源 |
| random | hashicorp/random | 3.8.0 | 生成随机数 |
| time | hashicorp/time | 0.13.1 | 处理时间相关操作 |
| archive | hashicorp/archive | 2.7.1 | 处理压缩文件 |
| cloudinit | hashicorp/cloudinit | 2.3.7 | 生成 cloud-init 配置 |
| external | hashicorp/external | 2.3.5 | 执行外部程序 |
| null | hashicorp/null | 3.2.4 | 提供空资源 |
| http | hashicorp/http | 3.5.0 | 发起 HTTP 请求 |
| tls | hashicorp/tls | 4.1.0 | 生成 RSA 密钥和证书 |
| local | hashicorp/local | 2.5.3 | 操作本地文件 |
| docker | kreuzwerker/docker | 3.6.2 | 管理 Docker 容器 |
