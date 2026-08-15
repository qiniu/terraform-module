# Live 集成测试（真实 apply）

用真实七牛云资源验证 `instance-exec-file-transfer` 模块的直传与分片路径。

## 前置条件

1. 本机已配置好 qiniu provider 凭证。运行前先 source ci-runner 的环境变量：

   ```bash
   # 从模块测试目录回到仓库根再进入 ci-runner 目录
   source ../../../apps/ci-runner/single/env.sh
   ```

   `env.sh` 导出 `QINIU_ACCESS_KEY` / `QINIU_SECRET_KEY` / `QINIU_REGION_ID`，
   qiniu provider 会自动读取这些环境变量，无需额外配置。

2. 设置临时实例的 root 密码（必填，用于创建临时测试实例）：

   ```bash
   export TF_VAR_instance_password='<strong-password>'
   ```

## 使用

```bash
cd pkg/instance-exec-file-transfer/tests/live

terraform init
terraform apply -auto-approve   # 创建临时实例并发布小文件 + 大文件
```

apply 成功后：

- `hello.txt`（小文件）走 `direct` 单命令直传；
- `uv.lock`（约 59 KB，真实样例，base64 后约 78 KB）走 `chunked` 分片路径，
  输出 `big_chunk_count` 应大于 1；
- `verify` exec 会在目标机上校验两文件的 SHA-256 与权限（0644），校验失败
  apply 即失败。

## 清理

```bash
terraform destroy -auto-approve
```

destroy 会删除临时实例与 key pair，并触发模块的 `destroy_command` 清理目标机上
与 marker/hash 严格匹配的已发布文件与 staging 目录。

## 说明

- 每次执行都会随机命名实例（`if-transfer-live-<suffix>`），互不干扰；
- `fixtures/uv.lock` 是真实 uv 锁文件样例，仅用于模拟大文件内容；
- 若在已有实例上做验收，可参照 `main.tf` 中的 `module.small` / `module.big`
  用法，替换 `instance_id` 与 `private_key` 即可，不需要创建新实例。