# DeepSeek Harness 协作规范
<!-- agents-md-version: 1 -->

本文件适用于 `apps/deepseek-harness/`。同时遵循仓库根目录的 [AGENTS.md](../../AGENTS.md)；本文件只补充该应用的领域约束，冲突时以本文件为准。

## 项目边界

- 本应用在七牛云单台 Ubuntu ECS 上部署 DeepSeek Harness、code-server、Nginx 和公开 Preview 入口；运行方式与用户操作以 [README.md](README.md) 为准。
- 应用根模块只负责组合基础设施、安装器、运行时传输和最终安装执行，不承载具体主机配置实现。
- `modules/infrastructure/` 管理云资源、镜像选择、固定代理端口和公网端点发现。
- `modules/ansible-installer/` 管理 bootstrap、部署期参数编码和安装命令；其 `ansible/` 子目录管理运行时文件白名单及内容元数据。
- `modules/ansible-runtime-transfer/` 负责准备目标目录并传输安装器声明的运行时文件，不定义安装内容。
- Ansible playbook 和 roles 管理软件版本、主机配置、systemd 服务、Nginx、运行用户及用户级 skill。
- `modules/instance-exec-file-transfer` 是指向仓库 `pkg/instance-exec-file-transfer` 的共享模块软链接；不要在软链接目录内维护分叉实现。

## 术语与命名

- `authority` 表示不含 scheme 的 HTTPProxy 公网端点；HTTPS 地址使用 `public_url`。
- `dsh_web` 表示 DeepSeek Harness Web 服务及其 Nginx/HTTPProxy 边界。
- `preview` 表示 HTTPProxy 直接映射到用户 Web 应用的公开端口槽位，不经过 Harness Basic Auth。
- 新增名称必须使用明确的领域前缀，例如 `dsh_web_*`、`code_server_*`、`preview_*`；不要新增泛化的 `web_*`、含糊的 `port` 或未发布模块的兼容别名。
- 不含 scheme 的端点命名为 `*_public_authority`，完整 HTTPS 地址命名为 `*_public_url`。

## 设计约定

- Terraform 只向安装器传递部署期动态值；多个 role 共享的稳定常量放在 `inventory/default/group_vars/all/main.yml`。
- role defaults 只保存该 role 私有的派生值；跨 role 的必需输入不得提供静默默认值。
- playbook 和 role 边界必须对必需输入做防御性 assert，并在缺失时给出明确错误。
- output 只暴露根模块、脚本或用户实际消费的值，不得为了测试内部实现新增 output。
- 只使用一次且内联后仍清晰的 Terraform 派生值直接写在使用处；复杂表达式、校验复用或多处引用才使用 local。
- bootstrap 必须短小、幂等、root-owned 且不包含秘密；优先使用官方安装器和版本匹配的预制镜像内容。
- Ansible 文件逐个传输并校验 SHA-256；没有当前需求时，不恢复归档传输或聚合 runtime manifest。
- 当前模块尚未发布，命名和职责调整优先保持边界干净，不保留推测性的升级兼容层。

## 依赖与本地环境

- Terraform、Provider、Python、uv 和 Ansible 的版本分别以就近 `versions.tf`、`pyproject.toml`、`uv.lock` 和 CI workflow 为准，不在本文件重复固定版本。
- Ansible Python 依赖必须使用 `uv` 和锁定环境；不得使用 pip、poetry，也不得手工修改 `uv.lock`。
- 本地七牛凭据和区域由 `apps/ci-runner/single/env.sh` 注入。不得检查、搜索、显示、复制或持久化该文件内容；仅可在必要时于一次性子 shell 中 source，并立即执行紧随其后的单个命令。
- Provider mirror 遵循仓库 README 或既有 `TF_CLI_CONFIG_FILE`。使用 development override 的环境不要运行 `terraform init`；需要刷新模块依赖时使用 `terraform get`。

## 安全边界

- Terraform state 包含随机密码和部署私钥，禁止读取、输出、复制或提交。
- 可能接触敏感配置的远程执行必须保持 `store_stdout = false` 和 `store_stderr = false`。
- Preview 是绕过 Harness Basic Auth 的公开入口，页面、运行命令和日志中不得出现秘密。
- Golden image 不得包含 DSH 用户状态、Basic Auth 文件、code-server 凭据、部署密钥、临时 exec 文件或含凭据日志。
- SSH PortForward 默认关闭；仅在明确的临时调试中配合强密码开启，结束后恢复关闭。

## 验证策略

所有 Terraform 改动先运行：

```bash
terraform fmt -check -recursive apps/deepseek-harness
git diff --check
```

再按受影响范围选择最小验证：

| 变更范围 | 必须验证 |
| --- | --- |
| 根模块 `*.tf` 或 `deepseek_harness.tftest.hcl` | 根模块 `validate` 和 `test` |
| `modules/infrastructure/` | infrastructure 模块 `validate`、`test`，再运行根模块 `test` |
| installer Terraform 或 `scripts/bootstrap.sh` | installer 模块 `validate`、`test`，再运行根模块 `test` |
| `modules/ansible-runtime-transfer/` | 根模块 `validate` 和 `test` |
| Ansible inventory、playbook、role 或模板 | installer 模块 `test`、Ansible syntax check、环境渲染测试，再运行根模块 `test` |
| 软链接指向的 `pkg/instance-exec-file-transfer/` | 按共享模块 README 运行模块测试与静态契约，再运行 DeepSeek Harness 根模块 `test` |

- 需要项目环境的 Terraform 命令按“依赖与本地环境”中的一次性子 shell 规则执行。
- Ansible 命令必须在 `modules/ansible-installer/ansible/` 中通过 `uv run --locked` 执行。
- 测试面向用户行为、安全边界和模块接线，不绑定仅供内部实现使用的 output。
- 精确 CI 命令以 [.github/workflows/deepseek-harness-test.yml](../../.github/workflows/deepseek-harness-test.yml) 为准；共享传输模块的命令以其 [README.md](../../pkg/instance-exec-file-transfer/README.md) 为准。
- 普通“测试”或“验证”请求不代表允许创建、修改或销毁真实云资源；live apply/destroy 必须另行取得明确授权。
