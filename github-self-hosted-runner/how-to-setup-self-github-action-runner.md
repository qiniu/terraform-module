# how to set up self-hosted github action runner

## 关键认知

### 1. 一个虚机跑一个 runner 还是多个 runner?

**默认行为:**
- 一个 runner 进程默认只能同时运行一个 job
- job 完成后,runner 会继续等待下一个 job

**决策依据:**

| 场景 | 建议配置 | 原因 |
|------|---------|------|
| 高并发 CI/CD | 一虚机一 runner | 资源隔离,避免干扰;易于扩缩容;失败影响范围小 |
| 资源充足的大型虚机 | 一虚机多 runner | 提高资源利用率;需注意端口/磁盘冲突 |
| 特定工具链 | 一虚机一 runner | 环境干净,依赖隔离 |
| 成本敏感 | 一虚机多 runner | 节省虚机成本;需做好资源限制 |

**最佳实践:**
- 生产环境推荐 **一虚机一 runner**,配合自动扩缩容
- 如需一虚机多 runner,每个 runner 需在不同目录下配置,例如:
  ```bash
  /home/runner1/actions-runner
  /home/runner2/actions-runner
  ```

### 2. 虚机配置选择

**最小配置:**
- CPU: 2 核
- 内存: 4 GB
- 磁盘: 20 GB

**推荐配置(根据工作负载):**

| 工作类型 | CPU | 内存 | 磁盘 | 说明 |
|---------|-----|------|------|------|
| 轻量级测试 | 2-4 核 | 4-8 GB | 30 GB | 简单的单元测试、linting |
| 前端构建 | 4-8 核 | 8-16 GB | 50 GB | npm/yarn 构建,node_modules 占用大 |
| 后端编译 | 8-16 核 | 16-32 GB | 100 GB | Java/C++ 编译,缓存依赖多 |
| Docker 构建 | 4-8 核 | 16-32 GB | 100 GB | 镜像层缓存占用空间大 |
| 机器学习训练 | 16+ 核 | 32+ GB | 200+ GB | 需 GPU 支持 |

**注意事项:**
- 预留 20-30% 的资源余量
- 磁盘建议使用 SSD,提升 I/O 性能
- 考虑网络带宽(拉取代码、依赖、上传产物)

### 3. Runner 用户权限设置

**为什么不能用 root?**
- **安全风险**: job 中的恶意代码会以 root 权限执行
- **最小权限原则**: runner 不需要 root 权限
- **官方限制**: GitHub Actions runner 会检测并拒绝以 root 运行

**创建专用账户:**
```bash
# 创建 runner 用户
sudo useradd -m -s /bin/bash runner

# 添加 sudo 权限(仅在必要时)
sudo usermod -aG sudo runner
```

**visudo 配置(允许无密码 sudo):**
```bash
sudo visudo

# 添加以下行(谨慎使用,仅在 CI/CD 必需时)
runner ALL=(ALL) NOPASSWD: ALL

# 更安全的方式:只允许特定命令
runner ALL=(ALL) NOPASSWD: /usr/bin/docker, /usr/bin/systemctl
```

**runner 账户 vs root 的区别:**

| 特性 | runner 账户 | root |
|------|-----------|------|
| UID | 1000+ | 0 |
| 权限范围 | 受限,仅自己的文件 | 所有系统文件 |
| sudo 能力 | 需配置 | 原生拥有 |
| 安全性 | 高(隔离) | 低(全权限) |
| 适用场景 | CI/CD runner | 系统管理 |

### 4. 让 runner 只针对私有仓库运行

**方法 1: 组织级别设置**
1. 进入 GitHub 组织设置: `Settings` → `Actions` → `Runners`
2. 添加 runner 时选择 **Organization** 级别
3. 在 `Runner groups` 中创建分组,设置仓库访问权限:
   - 点击 `New runner group`
   - 勾选 `Private repositories` 或选择特定私有仓库
   - 将 runner 添加到该分组

**方法 2: 仓库级别设置**
- 直接在私有仓库的 `Settings` → `Actions` → `Runners` 中添加 runner
- 该 runner 只会为这个仓库服务

**方法 3: Workflow 文件中限制**
```yaml
# .github/workflows/ci.yml
name: CI
on: [push]

jobs:
  build:
    runs-on: self-hosted
    # 只在私有仓库运行
    if: github.event.repository.private == true
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on private repo"
```

### 5. Runner 标签(Labels)使用

**添加标签:**

配置 runner 时可以添加自定义标签:
```bash
# 配置时添加标签
./config.sh --url https://github.com/your-org/your-repo \
  --token YOUR_TOKEN \
  --labels gpu,cuda-12,ubuntu-22.04

# 默认标签: self-hosted, linux/windows/macOS, x64/ARM64
```

**在 Workflow 中使用:**

```yaml
# .github/workflows/ml-training.yml
name: ML Training

on: [push]

jobs:
  # 使用带 GPU 的 runner
  train-model:
    runs-on: [self-hosted, gpu, cuda-12]
    steps:
      - uses: actions/checkout@v4
      - name: Train model
        run: python train.py --gpu

  # 使用普通 runner
  unit-test:
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test

  # 使用多个标签精确匹配
  build-docker:
    runs-on: [self-hosted, linux, docker, high-memory]
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t myapp .
```

**实际例子 - 不同环境构建:**

```yaml
# .github/workflows/multi-platform.yml
name: Multi-Platform Build

on: [push]

jobs:
  build-linux:
    runs-on: [self-hosted, linux, amd64]
    steps:
      - run: make build-linux

  build-windows:
    runs-on: [self-hosted, windows, x64]
    steps:
      - run: .\build.ps1

  build-arm:
    runs-on: [self-hosted, linux, arm64]
    steps:
      - run: make build-arm
```

**标签管理最佳实践:**
- 使用语义化标签: `os-version-arch-feature`
- 示例: `ubuntu-22.04-x64-docker`, `windows-2022-gpu`
- 避免过于细粒度,保持灵活性

### 6. Runner Token 机制

**Token 特性:**

| 特性 | 说明 |
|------|------|
| 有效期 | **1 小时**(注册 token) |
| 作用域 | 仓库级/组织级/企业级 |
| 是否变化 | 每次生成都不同 |
| 数量限制 | 无限制,但同时有效的 token 有限 |

**获取 Token:**

1. **仓库级 Token:**
   ```
   https://github.com/{owner}/{repo}/settings/actions/runners/new
   ```

2. **组织级 Token:**
   ```
   https://github.com/organizations/{org}/settings/actions/runners/new
   ```

3. **通过 API 获取(推荐自动化):**
   ```bash
   # 使用 GitHub CLI
   gh api \
     --method POST \
     -H "Accept: application/vnd.github+json" \
     /repos/OWNER/REPO/actions/runners/registration-token

   # 返回示例
   {
     "token": "LLBF3JGZDX3P5PMEXLND6TS6FCWO6",
     "expires_at": "2024-01-01T01:22:59.000Z"
   }
   ```

**自动化配置(解决 token 过期问题):**

```bash
#!/bin/bash
# auto-register-runner.sh

ORG="your-org"
REPO="your-repo"
GITHUB_TOKEN="ghp_xxxx"  # Personal Access Token (需要 admin:org 权限)

# 获取注册 token
REG_TOKEN=$(curl -s -X POST \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/${ORG}/${REPO}/actions/runners/registration-token \
  | jq -r '.token')

# 配置 runner
cd /home/runner/actions-runner
./config.sh \
  --url https://github.com/${ORG}/${REPO} \
  --token ${REG_TOKEN} \
  --labels self-hosted,linux,x64 \
  --unattended
```

**重要提示:**
- Token 1 小时后失效,但已配置的 runner 不受影响
- 重新配置 runner 需要新 token
- 使用 PAT(Personal Access Token)可自动化获取 registration token

### 7. svc.sh 文件详解

`svc.sh` 是 runner 作为系统服务运行的管理脚本。

**位置:**
```
/home/runner/actions-runner/svc.sh
```

**主要功能:**

```bash
# 安装为系统服务
sudo ./svc.sh install [username]

# 启动服务
sudo ./svc.sh start

# 停止服务
sudo ./svc.sh stop

# 查看状态
sudo ./svc.sh status

# 卸载服务
sudo ./svc.sh uninstall
```

**内部实现:**

创建 systemd 服务文件(Linux):
```ini
# /etc/systemd/system/actions.runner.{org}-{repo}.{hostname}.service
[Unit]
Description=GitHub Actions Runner ({org}.{repo}.{hostname})
After=network.target

[Service]
ExecStart=/home/runner/actions-runner/runsvc.sh
User=runner
WorkingDirectory=/home/runner/actions-runner
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=5min

[Install]
WantedBy=multi-user.target
```

**vs run.sh 的区别:**
- `svc.sh`: 作为系统服务运行(后台,开机自启)
- `run.sh`: 前台交互式运行(调试用)

### 8. run.sh 文件详解

`run.sh` 是 runner 的启动脚本(前台模式)。

**位置:**
```
/home/runner/actions-runner/run.sh
```

**用途:**

1. **交互式调试:**
   ```bash
   cd /home/runner/actions-runner
   ./run.sh

   # 输出示例:
   # √ Connected to GitHub
   # 2024-01-01 10:00:00Z: Listening for Jobs
   ```

2. **查看实时日志:**
   - 所有输出直接打印到终端
   - 适合排查连接/配置问题

3. **临时测试:**
   - 验证 runner 配置是否正确
   - 测试 workflow 执行

**内部流程:**
```bash
# 简化版流程
#!/bin/bash

# 1. 加载配置
source .env
source .credentials

# 2. 启动 Runner.Listener 进程
./bin/Runner.Listener run

# 3. 监听 GitHub 的 job 队列
# 4. 执行 job
# 5. 清理临时文件
# 6. 继续监听
```

**何时使用:**

| 场景 | 使用脚本 | 原因 |
|------|---------|------|
| 生产环境 | `svc.sh` | 后台运行,自动重启 |
| 调试配置 | `run.sh` | 实时查看日志 |
| 测试 workflow | `run.sh` | 快速验证 |
| 开机自启 | `svc.sh` | systemd 管理 |

**停止运行:**
- `run.sh`: `Ctrl+C`
- `svc.sh`: `sudo ./svc.sh stop`

## 具体构建步骤

### Step 1: 准备虚拟机

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装必要的依赖
sudo apt install -y curl jq git

# 创建 runner 用户
sudo useradd -m -s /bin/bash runner
sudo usermod -aG sudo runner
```

### Step 2: 下载 Runner

```bash
# 切换到 runner 用户
sudo su - runner

# 创建目录
mkdir actions-runner && cd actions-runner

# 下载最新版本 (检查: https://github.com/actions/runner/releases)
curl -o actions-runner-linux-x64-2.311.0.tar.gz \
  -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

# 解压
tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz
```

### Step 3: 配置 Runner

```bash
# 获取 token (从 GitHub UI 或 API)
# 仓库级: https://github.com/{owner}/{repo}/settings/actions/runners/new
# 组织级: https://github.com/organizations/{org}/settings/actions/runners/new

# 配置 runner
./config.sh \
  --url https://github.com/{owner}/{repo} \
  --token YOUR_TOKEN \
  --name my-runner \
  --labels self-hosted,linux,x64,gpu \
  --work _work \
  --unattended

# --unattended: 非交互模式
# --replace: 如果 runner 已存在则替换
```

### Step 4: 安装为服务

```bash
# 安装服务
sudo ./svc.sh install runner

# 启动服务
sudo ./svc.sh start

# 查看状态
sudo ./svc.sh status

# 查看日志
journalctl -u actions.runner.* -f
```

### Step 5: 验证

```bash
# 检查 runner 是否在线
# GitHub UI: Settings → Actions → Runners
# 应该看到 runner 状态为 "Idle"

# 测试 workflow
# 创建 .github/workflows/test.yml:
```

```yaml
name: Test Self-Hosted Runner
on: [push]

jobs:
  test:
    runs-on: [self-hosted, linux]
    steps:
      - uses: actions/checkout@v4
      - name: Print system info
        run: |
          echo "Hostname: $(hostname)"
          echo "OS: $(uname -a)"
          echo "CPU: $(nproc)"
          echo "Memory: $(free -h)"
```

### Step 6: 安全加固(可选但推荐)

```bash
# 限制 sudo 权限
sudo visudo
# 添加: runner ALL=(ALL) NOPASSWD: /usr/bin/docker

# 启用防火墙
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow out 443/tcp  # HTTPS to GitHub

# 定期更新
sudo crontab -e
# 添加: 0 2 * * * apt update && apt upgrade -y
```

### 故障排查

**Runner 无法连接:**
```bash
# 检查网络
ping github.com

# 检查日志
journalctl -u actions.runner.* --no-pager -n 100

# 重新配置
./config.sh remove --token YOUR_TOKEN
./config.sh --url ... --token NEW_TOKEN
```

**磁盘空间不足:**
```bash
# 清理旧的 workflow 文件
cd _work/_temp
rm -rf *

# 清理 Docker (如果使用)
docker system prune -af --volumes
```

**权限问题:**
```bash
# 确保 runner 用户拥有目录权限
sudo chown -R runner:runner /home/runner/actions-runner
```
