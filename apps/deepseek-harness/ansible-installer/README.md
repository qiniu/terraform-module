# DeepSeek Harness Ansible Installer

这是现有 Terraform installer 之外的独立部署入口。它通过 SSH 配置一台已创建的 Ubuntu 24.04 ECS；不会读取、修改或替换 `apps/deepseek-harness/main.tf` 的安装资源。

## 内容

- `env.sh`：幂等安装项目内的 `uv` 到 `.tools/uv`；可从 Bash 或 zsh source。
- `deploy.sh`：唯一的一键部署入口，使用锁定的 `ansible-core` 依赖执行 `playbooks/site.yml`。
- `roles/base`：基础包、受限 `dsh` 用户和数据目录。
- `roles/nodejs`、`roles/code_server`、`roles/deepseek_harness`：固定版本运行时、服务单元及 DSH 离线 npm 缓存。
- `roles/nginx`：Harness Basic Auth 与 code-server 反代入口；Preview 由 HTTPProxy 直连应用。
- `roles/las_dsh_environment`：`dsh` 用户级 LAS 开发环境 skill。

## 部署已有主机

复制 inventory 示例，并将 SSH 私钥路径替换为本地受限权限文件：

```bash
cd apps/deepseek-harness/ansible-installer
cp inventory/hosts.yml.example inventory/hosts.yml
chmod 600 inventory/hosts.yml /absolute/path/to/id_ed25519
```

设置公网 authority 和密码。它们只从环境变量读取，不能写入 inventory 或 Git：

```bash
export DSH_PUBLIC_AUTHORITY='harness.example.com'
export DSH_PREVIEW_COUNT='1'
export DSH_PREVIEW_PUBLIC_AUTHORITIES='["preview.example.com"]'
export DSH_CODE_SERVER_PUBLIC_AUTHORITY='code.example.com'
export DSH_WEB_PASSWORD='replace-with-a-secret'
export DSH_CODE_SERVER_PASSWORD='replace-with-a-different-secret'
./deploy.sh
```

`deploy.sh` 会自动安装受项目管理的 `uv`，并以 `uv run --locked ansible-playbook` 执行单个 playbook。`DSH_PREVIEW_COUNT` 支持 `0..4`，`DSH_PREVIEW_PUBLIC_AUTHORITIES` 必须是长度相同的 JSON 字符串列表；Preview 对应固定回环端口 `30080..30083`，由 HTTPProxy 直连。Node.js、code-server 与 DeepSeek Harness 的版本和端口默认与现有 Terraform 部署一致（Harness Nginx 端口变量为 `nginx_proxy_port`）；通过 `ansible-playbook -e key=value` 覆盖时须同时审阅对应下载校验值。

## 本地检查

```bash
bash tests/test-project.sh
./tests/test-ansible-parity-contract.sh
./tests/test-preview-count-validation.sh
./tests/test-port-validation.sh
./tests/test-nodejs-version-check.sh
./.tools/uv/uv run --locked ansible-playbook --syntax-check -i tests/inventory.yml playbooks/site.yml
```

## 七牛真实验证

下列脚本只使用 `apps/ci-runner/single/env.sh` 中已经配置的七牛环境变量，创建独立的按量付费临时 VM 和 HTTPProxy；生成的 state、inventory、私钥及密码都位于被忽略的 `tests/` 子目录。

```bash
./tests/provision-qiniu.sh
./tests/test-idempotence.sh
./tests/destroy-qiniu.sh
```

即使中间步骤失败，也应执行 `./tests/destroy-qiniu.sh` 清理该测试目录中的精确 Terraform state。
