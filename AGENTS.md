# 仓库协作规范

本文件适用于整个仓库。开始工作前检查目标路径下是否有更具体的 `AGENTS.md`；子目录规则在其范围内补充本文件，发生冲突时以更具体的规则为准。

## 工作原则

- 始终使用中文回复。
- 遵循 KISS 和 YAGNI，只实现当前明确需要的行为，不引入推测性的兼容层或抽象。
- 保持职责清晰；只有在确实消除重复或降低复杂度时才抽象复用。
- 修改前阅读受影响模块、相邻测试、就近 README 以及必要的相关提交，先确认职责和影响边界。
- 有会显著改变实现或结果的歧义时先确认；其余情况采用与现有代码一致的最小方案。
- 每次变更保持小而聚焦，可独立审阅和验证；不要顺手重构无关代码。

## 工作区与编辑

- 开始和结束时检查 Git 状态，保留与任务无关的用户改动，不覆盖或回退它们。
- 搜索优先使用 `rg`、`rg --files`；人工局部编辑使用 `apply_patch`，格式化或生成工具产生的机械变更除外。
- 不手工修改 `.terraform/`、`*.tfstate*`、`*.tfplan`、`.terraform.lock.hcl`、`uv.lock` 等缓存、状态、计划或锁文件；需要更新时使用对应工具并审阅结果。
- shell 变量使用具体名称，不覆盖 `PATH`、`HOME`、`path` 等系统或 shell 特殊变量。
- 命令失败后先完整阅读错误，确认工作目录、依赖和环境，再重跑最小失败范围；不得用扩大重试范围掩盖原因。

## 安全与外部操作

- 禁止检查、搜索、显示、复制或提交 `env.sh`、`.env`、非示例 `*.tfvars*`、`*.tfstate*`、私钥、密码、令牌及其他凭据的内容。模块规则明确允许时，只能在必要的一次性子 shell 中 source 既有环境文件，不得暴露其内容。
- 需要凭据时，只能按模块既有方式注入单次命令；不得把凭据加载到长期 shell、写入源码或通过日志、Terraform output、远程命令 stdout/stderr 泄露。
- 未经用户明确授权，不运行会修改或删除真实资源的 `terraform apply`、`terraform destroy`、live/integration 测试、部署或发布操作。
- 未经用户明确要求，不删除文件，不执行强制推送、跳过 Git hooks 或其他难以恢复的操作。

## Terraform 变更与验证

- 本仓库包含多个独立 Terraform 根模块和共享模块；先确定受影响模块，不假设存在统一的全仓测试命令。
- 以受影响模块就近的 `AGENTS.md`、README、`versions.tf`、测试文件和 CI workflow 为事实源；Provider 安装遵循仓库 README 与既有 `TF_CLI_CONFIG_FILE` 配置。
- 在模块文档和现有开发环境允许的前提下，Terraform 改动至少执行受影响范围的格式检查、模块验证、已有的相关测试和空白检查。常用命令模板如下：

```bash
terraform fmt -check -recursive <受影响目录>
terraform -chdir=<模块目录> validate
terraform -chdir=<模块目录> test -no-color  # 该模块存在 *.tftest.hcl 时
git diff --check
```

- 初始化、下载 Provider 或刷新模块依赖前，先遵循模块文档和现有开发环境配置，避免无关的缓存或锁文件变化。
- 受 Provider、mirror、凭据或网络限制而无法运行某项验证时，继续运行不依赖该条件的检查，并在结果中明确说明未运行项和原因。
- `terraform test` 中的 mock `apply` 不等同于真实云资源部署；任何需要真实账号或会产生费用的测试仍须用户明确授权。
- 修改共享模块时，除模块自身测试外，还要验证本次变更实际影响到的直接使用方。

## Git

- 未经用户明确要求，不执行 `git commit` 或 `git push`。
- 不擅自执行 `reset`、`revert`、`amend`、`squash`，也不改写用户已有提交。
- 用户要求提交时，先检查 diff、相关测试和工作区范围；提交保持单一目的，并遵循仓库现有提交风格。

## 目录专属规则

- 修改 `apps/deepseek-harness/` 前，必须阅读并遵循 [apps/deepseek-harness/AGENTS.md](apps/deepseek-harness/AGENTS.md)。
- 其他目录没有专属 `AGENTS.md` 时，先阅读就近 README、测试和 CI 配置，再确定验证范围。
