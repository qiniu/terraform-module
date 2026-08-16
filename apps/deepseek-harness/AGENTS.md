# AGENTS.md
<!-- agents-md-version: 1 -->

## 关键规则

- 必须始终使用中文回复。
- 必须遵循 KISS、YAGNI、DRY、SOLID，只实现当前明确需要的行为。
- 修改前必须阅读相关模块、测试和近期提交，先确认职责边界。
- 提交前必须运行 `terraform fmt -check -recursive apps/deepseek-harness` 和相关测试。
- Ansible Python 依赖必须使用 `uv`，不得使用 pip、poetry 或手工修改 `uv.lock`。
- 每次变更和提交必须小而独立、可单独验证；只有用户明确要求时才能 commit 或 push。
- 禁止读取、搜索、打印或粘贴 `env.sh`、`.env`、非示例 `*.tfvars*`、`*.tfstate*`、私钥、密码、令牌和凭据。除 `terraform fmt` 外，需要项目环境的 Terraform 命令只能在一次性子 shell 中 source `apps/ci-runner/single/env.sh` 后立即执行，不得把它加载到长期 shell。
- 禁止硬编码秘密，或通过日志、测试输出、非敏感 Terraform output、远程命令 stdout/stderr 泄露敏感值。
- 未经用户明确要求，禁止运行 `terraform apply`、`terraform destroy`、部署、发布、强制推送或跳过 Git hooks。
- 禁止手工修改 `.terraform/`、`*.tfstate*`、`.terraform.lock.hcl` 和 `uv.lock` 等生成内容。
- zsh 脚本变量必须使用具体名称，禁止使用 `path`、`PATH`、`HOME` 等会覆盖环境的系统变量名。
- 搜索优先使用 `rg`、`rg --files`，手工编辑必须使用 `apply_patch`。
- 命令失败时，先完整阅读错误，确认工作目录和环境，再重跑最小失败范围。

## 领域与上下文

- 目标：在七牛云单台 Ubuntu ECS 上部署 DeepSeek Harness、code-server、Nginx 和公开 Preview 入口。
- 类型：可部署应用，使用 Terraform 编排基础设施与安装流程，使用 Ansible 配置主机。
- `authority`：不包含 scheme 的 HTTPProxy 公网端点。
- `public_url`：包含 `https://` scheme 的公网 URL。
- `dsh_web`：DeepSeek Harness Web 服务及其 Nginx/HTTPProxy 边界。
- `preview`：HTTPProxy 直接映射到用户 Web 应用的公开端口槽位，不经过 Harness Basic Auth。

## 运行环境

- Terraform 模块要求 `>= 1.6`，CI 使用 Terraform `1.14`。
- Qiniu Provider 固定为 `qiniu/qiniu` `1.0.0`。
- Ansible 项目要求 Python `>= 3.12`，使用 uv `0.12.5` 和 ansible-core `2.20.2`。
- 本地七牛凭据与区域使用 `source apps/ci-runner/single/env.sh` 注入，不得读取或打印该文件；Provider mirror 按仓库 README 或既有 `TF_CLI_CONFIG_FILE` 配置。
- `modules/instance-exec-file-transfer` 是指向仓库 `pkg/instance-exec-file-transfer` 的软链接。

## 常用命令

以下命令均从仓库根目录执行：

```bash
# 格式与空白
terraform fmt -check -recursive apps/deepseek-harness  # 失败：运行 terraform fmt -recursive apps/deepseek-harness，审阅 diff 后重跑
git diff --check  # 失败：修复尾随空格或空白错误后重跑

# 根模块
(source apps/ci-runner/single/env.sh && terraform -chdir=apps/deepseek-harness get)  # 失败：检查本地模块路径；development override 环境不要运行 init
(source apps/ci-runner/single/env.sh && terraform -chdir=apps/deepseek-harness validate)  # 失败：修复报告的模块或 Provider 契约
(source apps/ci-runner/single/env.sh && terraform -chdir=apps/deepseek-harness test)  # 失败：定位 deepseek_harness.tftest.hcl 中失败的 run

# infrastructure 子模块
(source apps/ci-runner/single/env.sh && terraform -chdir=apps/deepseek-harness/modules/infrastructure get)  # 失败：检查本地模块路径；development override 环境不要运行 init
(source apps/ci-runner/single/env.sh && terraform -chdir=apps/deepseek-harness/modules/infrastructure validate)  # 失败：修复报告的资源或变量契约

# Ansible installer 子模块
(source apps/ci-runner/single/env.sh && terraform -chdir=apps/deepseek-harness/modules/ansible-installer get)  # 失败：检查 Terraform 与文件访问权限
(source apps/ci-runner/single/env.sh && terraform -chdir=apps/deepseek-harness/modules/ansible-installer validate)  # 失败：修复报告的 installer 契约
(source apps/ci-runner/single/env.sh && terraform -chdir=apps/deepseek-harness/modules/ansible-installer test)  # 失败：检查 install.tftest.hcl 和渲染后的 bootstrap

# Ansible 语法
(cd apps/deepseek-harness/modules/ansible-installer/ansible && uv run --locked ansible-playbook --syntax-check -i inventory/default playbooks/site.yml)  # 失败：修复报告的 role/task 后在同目录重跑
```

## 目录结构

```text
main.tf                              # 顶层模块编排
variables.tf                         # 对外输入契约
outputs.tf                           # 对外输出契约
versions.tf                          # Terraform 与 Provider 版本
deepseek_harness.tftest.hcl          # 根模块契约测试
modules/infrastructure/              # 七牛云资源与端点
modules/ansible-installer/           # 安装内容与命令
modules/ansible-installer/install.tftest.hcl # Installer 契约测试
modules/ansible-installer/ansible/   # Inventory、playbook、roles
modules/ansible-installer/ansible/main.tf # Ansible runtime 输出模块
modules/ansible-installer/ansible/ansible.cfg # Ansible 执行配置
modules/ansible-installer/ansible/playbooks/site.yml # 主安装 playbook
modules/ansible-installer/ansible/pyproject.toml # Ansible 依赖清单
modules/ansible-installer/ansible/uv.lock # 生成的依赖锁，禁止手工编辑
modules/ansible-installer/scripts/bootstrap.sh # Bootstrap 脚本
modules/ansible-runtime-transfer/    # 安装文件传输编排
modules/instance-exec-file-transfer  # 共享传输模块软链接
scripts/ssh.sh                       # 可选 SSH 调试入口
**/.terraform/                       # 生成的 Provider 缓存，禁止编辑
```

## 设计约定

- Terraform 应用根模块只组合 infrastructure、installer、transfer 和最终执行资源，不承载具体安装实现。
- infrastructure 管理云资源、固定代理端口、镜像选择和公网端点发现。
- installer 管理 bootstrap、extra vars 编码和安装命令，不管理云资源。
- `ansible/main.tf` 管理 Ansible 运行时文件白名单、内容和 SHA-256 元数据。
- Ansible playbook/roles 管理软件版本、主机配置、systemd 服务、Nginx 和运行用户。
- 多个 role 共享的常量统一放在 `inventory/default/group_vars/all/main.yml`。
- Terraform 只传递部署期动态值，例如公网 authority、端口数组、用户名和密码。
- role defaults 只保存该 role 私有的派生值；跨 role 必需变量不得提供静默默认值。
- playbook 和 role 边界必须对必需输入做防御性 assert，缺失时给出明确错误。
- 命名必须带领域前缀：`dsh_web_*`、`code_server_*`、`preview_*`；禁止新增泛化的 `web_*`、含糊的 `port` 或未发布模块的兼容别名。
- 不含 scheme 的端点使用 `*_public_authority`，HTTPS 地址使用 `*_public_url`。
- output 只暴露根模块、脚本或用户确实消费的值；不得为了测试内部实现而新增 output。
- 只使用一次且内联后仍清晰的 Terraform 派生值直接写入 output、resource 或 module 参数；复杂表达式、校验复用或多处引用才使用 local。
- bootstrap 必须短小、幂等、root-owned 且不包含秘密；优先使用官方安装器，并复用版本匹配的预制镜像内容。
- Ansible 文件逐个传输并校验 SHA-256；没有实际需求时不得恢复归档传输或聚合 runtime manifest。
- 删除空文件、noop handler、旧 installer 和已由其他测试覆盖的开发期契约脚本。
- 当前模块尚未发布，命名和边界调整优先保持干净，不保留升级兼容层。

## 测试策略

- 修改根模块 `*.tf` 或 `deepseek_harness.tftest.hcl`：运行根模块 validate 和 test。
- 修改 `modules/infrastructure/`：运行 infrastructure validate，再运行根模块 test。
- 修改 installer Terraform 或 bootstrap：运行 installer test，再运行根模块 test。
- 修改 `modules/ansible-runtime-transfer/`：运行根模块 validate 和 test。
- 修改软链接指向的 `pkg/instance-exec-file-transfer/`：按该模块 README 运行自身测试，再运行 DeepSeek Harness 根模块 test。
- 修改 Ansible inventory、playbook 或 role：运行 installer test、Ansible syntax check 和根模块 test。
- 测试面向用户行为、安全边界和模块接线，不绑定仅供内部实现使用的 output。
- Terraform 改动后必须运行格式检查和 `git diff --check`。
- Ansible、inventory、role 或 bootstrap 改动后必须运行 installer Terraform tests 和 Ansible syntax check。
- live apply/destroy 必须取得用户明确授权；普通“测试”或“验证”请求不代表允许创建云资源。

## 安全

- Terraform state 含随机密码和部署私钥，禁止输出、粘贴或提交。
- 远程安装命令可能接触敏感配置时，保持 `store_stdout = false`、`store_stderr = false`。
- Golden image 不得包含 DSH 用户状态、Basic Auth 文件、code-server 凭据、部署密钥、临时 exec 文件或含凭据日志。
- Preview URL 是公开入口且绕过 Harness Basic Auth，Preview 内容和日志中不得出现秘密。
- SSH PortForward 默认关闭；只在调试时配合强密码临时开启，结束后恢复关闭。

## Git 与 CI

- 分支使用 `feat/`、`fix/`、`refactor/` 或 `chore/` 前缀。
- 提交使用 Conventional Commits，主题简洁且只描述一个目的，例如 `fix(deepseek-harness): validate preview ports`。
- 保留工作区中与任务无关的用户改动；未经明确要求不得 reset、revert、amend 或 squash。
- `.github/workflows/deepseek-harness-test.yml` 的 job/check 名为 `DeepSeek Harness Tests`，运行根模块、infrastructure、installer 和 Ansible syntax check。
- `pkg/instance-exec-file-transfer/` 由通用 Terraform CI 测试，DeepSeek Harness workflow 不重复监听或执行同一共享模块测试。
- 仓库没有声明该 check 是否为 branch protection required check，也没有 PR template、CODEOWNERS、pre-commit hook 或 CI artifact；不得自行假设。
- 应用专用 CI 与通用 Terraform CI 不重复执行同一测试；path filter 必须覆盖能影响任务的文件。
