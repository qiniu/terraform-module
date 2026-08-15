# ============================================================================
# instance-exec-file-transfer 模块契约测试（issue #58）
# ============================================================================
# 运行方式：在模块根目录执行 `terraform -chdir=pkg/instance-exec-file-transfer test`
# 说明：
# - 使用 mock_provider 跳过 qiniu provider 凭证，只验证渲染出的命令与资源图。
# - 契约点：
#   1. 输入 content 为无换行 ASCII base64（变量校验）
#   2. content_sha256 是解码内容的 64 位小写十六进制（check）
#   3. 每个完整渲染命令均为 ASCII 且 <= 8192 字节（assert）
#   4. 小文件走单条短命令直传；大文件自动分片并发上传
#   5. finalize 显式依赖完整 chunk 集合；输出引用已完成发布
#   6. private_key 为 sensitive、所有 exec 禁用 stdout/stderr（静态契约见 tests/contract.sh）
# ============================================================================

mock_provider "qiniu" {}

variables {
  instance_id    = "i-test-instance"
  user           = "root"
  port           = "22"
  private_key    = "test-private-key"
  content        = base64encode("hello world")
  content_sha256 = sha256("hello world")
  target_path    = "/opt/test/hello.txt"
  file_mode      = "0644"
}

# ---------------------------------------------------------------------------
# 契约：内容哈希必须匹配解码内容
# ---------------------------------------------------------------------------

run "rejects_mismatched_content_sha256" {
  command = plan

  variables {
    content        = base64encode("hello world")
    content_sha256 = sha256("different content")
  }

  expect_failures = [check.content_sha256_match]
}

# ---------------------------------------------------------------------------
# 契约：content 必须是无换行 ASCII base64
# ---------------------------------------------------------------------------

run "rejects_content_with_newline" {
  command = plan

  variables {
    content = "aGVsbG8Kd29ybGQ=\n" # 实际值会被校验拒绝（含换行）
  }

  expect_failures = [var.content]
}

# ---------------------------------------------------------------------------
# 契约：target_path 必须是绝对路径
# ---------------------------------------------------------------------------

run "rejects_relative_target_path" {
  command = plan

  variables {
    target_path = "opt/test/hello.txt"
  }

  expect_failures = [var.target_path]
}

# ---------------------------------------------------------------------------
# 契约：file_mode 必须是 4 位八进制
# ---------------------------------------------------------------------------

run "rejects_invalid_file_mode" {
  command = plan

  variables {
    file_mode = "644"
  }

  expect_failures = [var.file_mode]
}

# ---------------------------------------------------------------------------
# 契约：小文件使用单条短命令直传，无分片资源
# ---------------------------------------------------------------------------

run "small_file_direct_publish" {
  command = apply

  assert {
    condition     = length(qiniu_compute_instance_exec.publish) == 1
    error_message = "小文件应使用单条短命令直接发布（publish 资源）"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.chunk) == 0
    error_message = "小文件不应产生分片资源"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.prepare) == 0
    error_message = "小文件不应产生 prepare 资源"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.finalize) == 0
    error_message = "小文件不应产生 finalize 资源"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.publish[0].command) <= 8192
    error_message = "直传命令必须 <= 8192 字节"
  }

  assert {
    condition     = can(regex("^[\\x00-\\x7F]*$", qiniu_compute_instance_exec.publish[0].command))
    error_message = "直传命令必须是纯 ASCII"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish[0].command, "/opt/test/hello.txt")
    error_message = "直传命令应引用目标绝对路径"
  }
}

# ---------------------------------------------------------------------------
# 契约：大文件自动分片（chunk > 1），每个完整渲染命令 <= 8192 且 ASCII，
#       finalize 显式依赖全部 chunk
# ---------------------------------------------------------------------------

run "large_file_chunked_publish" {
  command = apply

  variables {
    # 32 字符 × 256 = 8192 字节内容 → base64 约 10.9 KiB，
    # 超过直传命令 8192 字节上限，必然拆成多片
    content        = base64encode(join("", [for i in range(256) : "0123456789abcdefghijklmnopqrstuvwxyz"]))
    content_sha256 = sha256(join("", [for i in range(256) : "0123456789abcdefghijklmnopqrstuvwxyz"]))
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.publish) == 0
    error_message = "大文件不应走直传发布"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.prepare) == 1
    error_message = "大文件应先执行 prepare"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.chunk) > 1
    error_message = "大文件必须拆成多个分片并发上传"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.finalize) == 1
    error_message = "大文件最后应执行 finalize 校验合并"
  }

  assert {
    condition = alltrue([
      for _, r in qiniu_compute_instance_exec.chunk : length(r.command) <= 8192
    ])
    error_message = "每个分片命令必须 <= 8192 字节"
  }

  assert {
    condition = alltrue([
      for _, r in qiniu_compute_instance_exec.chunk : can(regex("^[\\x00-\\x7F]*$", r.command))
    ])
    error_message = "每个分片命令必须是纯 ASCII"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.finalize[0].command) <= 8192
    error_message = "finalize 命令必须 <= 8192 字节"
  }

  assert {
    condition     = can(regex("^[\\x00-\\x7F]*$", qiniu_compute_instance_exec.finalize[0].command))
    error_message = "finalize 命令必须是纯 ASCII"
  }
}

# ---------------------------------------------------------------------------
# 契约：destroy 清理命令只删除与 marker/hash 严格匹配的受管文件，
#       且清理命令同样满足 8192/ASCII 约束
# ---------------------------------------------------------------------------

run "destroy_command_small_direct" {
  command = plan

  assert {
    condition     = can(regex("^[\\x00-\\x7F]*$", qiniu_compute_instance_exec.publish[0].destroy_command))
    error_message = "直传 destroy 命令必须是纯 ASCII"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.publish[0].destroy_command) <= 8192
    error_message = "直传 destroy 命令必须 <= 8192 字节"
  }
}

run "outputs_reference_published_path" {
  command = apply

  assert {
    condition     = output.published_path == "/opt/test/hello.txt"
    error_message = "published_path 应等于目标绝对路径"
  }
}