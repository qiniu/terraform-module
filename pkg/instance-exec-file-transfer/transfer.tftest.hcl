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


run "rejects_mismatched_content_sha256" {
  command = plan

  variables {
    content        = base64encode("hello world")
    content_sha256 = sha256("different content")
  }

  expect_failures = [check.content_sha256_match]
}


run "rejects_content_with_newline" {
  command = plan

  variables {
    content = "aGVsbG8Kd29ybGQ=\n" # 实际值会被校验拒绝（含换行）
  }

  expect_failures = [var.content]
}


run "rejects_relative_target_path" {
  command = plan

  variables {
    target_path = "opt/test/hello.txt"
  }

  expect_failures = [var.target_path]
}

run "rejects_target_path_longer_than_512_bytes" {
  command = plan

  variables {
    target_path = "/${format("%0512d", 0)}"
  }

  expect_failures = [var.target_path]
}

run "rejects_non_ascii_target_path" {
  command = plan

  variables {
    target_path = "/😀"
  }

  expect_failures = [var.target_path]
}

run "rejects_staging_root_longer_than_512_bytes" {
  command = plan

  variables {
    staging_root = "/${format("%0512d", 0)}"
  }

  expect_failures = [var.staging_root]
}

run "rejects_non_ascii_staging_root" {
  command = plan

  variables {
    staging_root = "/😀"
  }

  expect_failures = [var.staging_root]
}


run "rejects_invalid_file_mode" {
  command = plan

  variables {
    file_mode = "644"
  }

  expect_failures = [var.file_mode]
}


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

run "expanded_direct_payload_routes_to_direct" {
  command = apply

  variables {
    content        = base64encode(join("", [for i in range(78) : join("", [for j in range(750) : "a"])]))
    content_sha256 = sha256(join("", [for i in range(78) : join("", [for j in range(750) : "a"])]))
  }

  assert {
    condition     = length(module.direct) == 1
    error_message = "78 KiB base64 payload 应直接发布"
  }

  assert {
    condition     = length(module.chunked) == 0
    error_message = "78 KiB base64 payload 不应进入分片路径"
  }
}


run "large_file_routes_to_chunked" {
  command = apply

  variables {
    # 94 × 750 = 70500 字节内容 → 94000 字节 base64，超过直传阈值必然分片。
    content        = base64encode(join("", [for i in range(94) : join("", [for j in range(750) : "a"])]))
    content_sha256 = sha256(join("", [for i in range(94) : join("", [for j in range(750) : "a"])]))
    chunk_size     = 2048
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

run "serializes_direct_to_chunked_migration" {
  command = plan

  assert {
    condition     = strcontains(file("${path.module}/main.tf"), "resource \"terraform_data\" \"transport\"")
    error_message = "传输方式切换必须通过替换屏障先销毁旧发布资源。"
  }
}


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


run "at_threshold_content_routes_to_direct" {
  command = apply

  variables {
    # 86600 字节 base64 payload（64950 字节原始内容），恰好等于直传阈值。
    content        = base64encode("${join("", [for i in range(86) : join("", [for j in range(750) : "a"])])}${join("", [for j in range(450) : "a"])}")
    content_sha256 = sha256("${join("", [for i in range(86) : join("", [for j in range(750) : "a"])])}${join("", [for j in range(450) : "a"])}")
  }

  assert {
    condition     = length(module.direct) == 1
    error_message = "等于直传阈值的内容应路由到 module.direct"
  }

  assert {
    condition     = length(module.chunked) == 0
    error_message = "等于直传阈值的内容不应路由到 module.chunked"
  }
}


run "over_threshold_content_routes_to_chunked" {
  command = apply

  variables {
    # 86604 字节 base64 payload（64953 字节原始 'a' 内容），超过直传阈值 4 字节
    content        = base64encode("${join("", [for i in range(86) : join("", [for j in range(750) : "a"])])}${join("", [for j in range(453) : "a"])}")
    content_sha256 = sha256("${join("", [for i in range(86) : join("", [for j in range(750) : "a"])])}${join("", [for j in range(453) : "a"])}")
    chunk_size     = 2048
  }

  assert {
    condition     = length(module.direct) == 0
    error_message = "超过直传阈值的内容不应路由到 module.direct"
  }

  assert {
    condition     = length(module.chunked) == 1
    error_message = "超过直传阈值的内容应路由到 module.chunked"
  }

  assert {
    condition     = module.chunked[0].chunk_count > 1
    error_message = "超过直传阈值的内容必须分片传输"
  }
}
