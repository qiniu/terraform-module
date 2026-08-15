# ============================================================================
# instance-exec-file-transfer 根模块契约测试（issue #58）
# ============================================================================
# 根模块职责：输入校验 + 大小分流（small → module.direct，large → module.chunked）。
# 子模块内部的命令渲染断言位于 modules/direct/direct.tftest.hcl 与
# modules/chunked/chunked.tftest.hcl。
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
# 契约：小文件走 module.direct 单命令直传，无分片
# ---------------------------------------------------------------------------

run "small_file_routes_to_direct" {
  command = apply

  assert {
    condition     = length(module.direct) == 1
    error_message = "小文件应路由到 module.direct 直传"
  }

  assert {
    condition     = length(module.chunked) == 0
    error_message = "小文件不应路由到 module.chunked"
  }

  assert {
    condition     = output.chunk_count == 1
    error_message = "小文件 chunk_count 应为 1"
  }
}

# ---------------------------------------------------------------------------
# 契约：大文件自动分流到 module.chunked 分片上传
# ---------------------------------------------------------------------------

run "large_file_routes_to_chunked" {
  command = apply

  variables {
    # 32 字符 × 256 = 8192 字节内容 → base64 约 10.9 KiB，超过直传阈值必然分片
    content        = base64encode(join("", [for i in range(256) : "0123456789abcdefghijklmnopqrstuvwxyz"]))
    content_sha256 = sha256(join("", [for i in range(256) : "0123456789abcdefghijklmnopqrstuvwxyz"]))
  }

  assert {
    condition     = length(module.chunked) == 1
    error_message = "大文件应路由到 module.chunked 分片传输"
  }

  assert {
    condition     = length(module.direct) == 0
    error_message = "大文件不应路由到 module.direct"
  }

  assert {
    condition     = module.chunked[0].chunk_count > 1
    error_message = "大文件必须拆成多个分片并发上传"
  }

  assert {
    condition     = output.chunk_count > 1
    error_message = "根模块 chunk_count 输出应大于 1"
  }
}

# ---------------------------------------------------------------------------
# 契约：输出引用已发布路径与完成依赖
# ---------------------------------------------------------------------------

run "outputs_reference_published_path" {
  command = apply

  assert {
    condition     = output.published_path == "/opt/test/hello.txt"
    error_message = "published_path 应等于目标绝对路径"
  }

  assert {
    condition     = output.completed != ""
    error_message = "completed 应引用完成的 exec 资源"
  }
}