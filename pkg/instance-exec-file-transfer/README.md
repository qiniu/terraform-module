# instance-exec-file-transfer

通过 `qiniu_compute_instance_exec`（InstanceConnect SSH）在目标实例内发布单个文件。

解决 qiniu provider `command` 字段 8192 字节上限问题：按内容大小自动分流，
所有远端执行命令均在 8192 字节内且为纯 ASCII。

## 使用方式

```hcl
module "file" {
  source = "github.com/qiniu/terraform-module/pkg/instance-exec-file-transfer"

  instance_id    = qiniu_compute_instance.example.id
  user           = "root"
  port           = "22"
  private_key    = var.private_key   # 与 password 二选一（sensitive）

  content        = base64encode(file("${path.module}/uv.lock"))  # 无换行 ASCII base64
  content_sha256 = sha256(file("${path.module}/uv.lock"))        # 解码后字节的 SHA-256
  target_path    = "/opt/app/uv.lock"
  file_mode      = "0644"
}

# 依赖发布完成（例如继续写配置）
resource "qiniu_compute_instance_exec" "next" {
  instance_id = qiniu_compute_instance.example.id
  user        = "root"
  private_key = var.private_key
  command     = "…"
  depends_on  = [module.file.completed]   # completed 为完成信号
}
```

## 自动分流

| 内容大小 | 路径 | 说明 |
| --- | --- | --- |
| base64 payload ≤ 6592 字节 | `modules/direct` | 单条短命令直传（staging/marker + SHA 校验 + 同目录原子 mv） |
| 更大内容 | `modules/chunked` | `prepare`（hash staging/marker + 安全校验）→ 并发 `chunk`（每片独立 part 文件）→ `finalize`（完整序号/SHA 校验 + 目标同目录原子 mv） |

两个子模块均可独立使用（`./modules/direct`、`./modules/chunked`），
常用场景直接使用根模块自动分流即可。

## 变量

| 名称 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `instance_id` | string | — | 目标实例 ID |
| `user` | string | `"root"` | SSH 用户 |
| `port` | string | `"22"` | SSH 端口 |
| `private_key` | string(sensitive) | `null` | SSH 私钥，与 password 二选一 |
| `password` | string(sensitive) | `null` | SSH 密码，与 private_key 二选一 |
| `shell` | string | `"bash"` | 远端 shell |
| `content` | string(sensitive) | — | 文件内容，无换行 ASCII base64 |
| `content_sha256` | string | — | 解码后字节的 64 位小写十六进制 SHA-256 |
| `target_path` | string | — | 目标绝对路径（拒绝相对路径/`..`/单引号） |
| `file_mode` | string | `"0644"` | 4 位八进制权限 |
| `chunk_size` | number | `2048` | 分片 payload 上限（字节，按 4 对齐） |
| `staging_root` | string | `"/var/tmp/qiniu-instance-exec-file-transfer"` | 远端 staging 根目录 |
| `destroy_cleanup` | bool | `true` | 销毁/替换时清理严格匹配的受管文件 |

## 输出

- `published_path`：目标绝对路径
- `completed`：发布完成信号（最后 exec 的 ID），可用于 `depends_on`
- `chunk_count`：实际分片数（直传为 1）

## 安全边界

- 目标父目录与 staging 根必须 root 所有、非 symlink、`realpath` 一致；
- 目标已存在时，仅当受管 marker 与目标 SHA 均严格匹配才允许覆盖，否则拒绝；
- 所有命令 `store_stdout = false` / `store_stderr = false`，不落盘输出；
- 所有 payload 均为无换行 ASCII base64（安全字符集），单引号内嵌，无法注入 shell；
- destroy 仅删除与 marker/hash 严格匹配的受管文件与 staging。

## 测试

```bash
# 契约测试（mock provider，无需凭证）
terraform -chdir=pkg/instance-exec-file-transfer test
terraform -chdir=pkg/instance-exec-file-transfer/modules/direct test
terraform -chdir=pkg/instance-exec-file-transfer/modules/chunked test

# 静态契约
pkg/instance-exec-file-transfer/tests/contract.sh

# 真实环境集成测试（需 source apps/ci-runner/single/env.sh）
cd pkg/instance-exec-file-transfer/tests/live
terraform init && terraform apply && terraform destroy
```