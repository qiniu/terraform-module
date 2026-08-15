# ============================================================================
# chunked 子模块契约测试（issue #58 Task 1/2）
# ============================================================================
# 覆盖：prepare/chunk/finalize 命令 ≤ 8192 且纯 ASCII、hash 命名 staging 与
# marker、安全边界、完整分片序号/SHA 校验、目标同目录原子 mv、destroy 清理。
# ============================================================================

mock_provider "qiniu" {}

variables {
  instance_id    = "i-test-instance"
  user           = "root"
  port           = "22"
  private_key    = "test-private-key"
  content        = base64encode(join("", [for i in range(256) : "0123456789abcdefghijklmnopqrstuvwxyz"]))
  content_sha256 = sha256(join("", [for i in range(256) : "0123456789abcdefghijklmnopqrstuvwxyz"]))
  target_path    = "/opt/test/hello.txt"
  file_mode      = "0644"
}

run "chunked_publishes_multi_chunk" {
  command = apply

  # prepare / finalize 为单实例资源，其存在性由后续 run 对 .command 的引用隐式验证；
  # 此处只断言并发分片集合规模。
  assert {
    condition     = length(qiniu_compute_instance_exec.chunk) > 1
    error_message = "大文件必须拆成多个分片并发上传"
  }
}

run "prepare_command_hash_staging_and_security" {
  command = plan

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.prepare.command, var.content_sha256)
    error_message = "prepare 必须使用 hash 命名的 staging 目录"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.prepare.command, "marker")
    error_message = "prepare 必须写入受管 marker"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.prepare.command, "stat -c %U")
    error_message = "prepare 必须校验 staging 根/目标父目录所有者为 root"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.prepare.command, "realpath")
    error_message = "prepare 必须校验 realpath"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.prepare.command, "-L \"$D\"")
    error_message = "prepare 必须拒绝 staging 目录为 symlink"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.prepare.command, "rm -f \"$D\"/part.*")
    error_message = "prepare 应安全清空已验证 staging 的分片"
  }
}

run "chunk_commands_concurrent_and_limited" {
  command = plan

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
    condition = alltrue([
      for k, r in qiniu_compute_instance_exec.chunk :
      strcontains(r.command, "part.${k}")
    ])
    error_message = "每个 chunk 必须写入自己的独立 part 文件（可并发、不互相追加）"
  }
}

run "finalize_command_sequence_sha_atomic" {
  command = plan

  assert {
    condition     = length(qiniu_compute_instance_exec.finalize.command) <= 8192
    error_message = "finalize 命令必须 <= 8192 字节"
  }

  assert {
    condition     = can(regex("^[\\x00-\\x7F]*$", qiniu_compute_instance_exec.finalize.command))
    error_message = "finalize 命令必须是纯 ASCII"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.finalize.command, "sha256sum -c")
    error_message = "finalize 必须执行 SHA 校验"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.finalize.command, "part.")
    error_message = "finalize 必须校验完整分片集合"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.finalize.command, "qiniu-finalize")
    error_message = "finalize 必须在目标同目录临时发布后原子 mv"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.finalize.command, "stat -c %U")
    error_message = "finalize 必须校验目标父目录安全"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.finalize.command, "sha256sum -c -")
    error_message = "finalize 必须校验目标已存在文件 SHA"
  }
}

run "destroy_command_constraints" {
  command = plan

  assert {
    condition     = can(regex("^[\\x00-\\x7F]*$", qiniu_compute_instance_exec.finalize.destroy_command))
    error_message = "finalize destroy 命令必须是纯 ASCII"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.finalize.destroy_command) <= 8192
    error_message = "finalize destroy 命令必须 <= 8192 字节"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.finalize.destroy_command, "sha256sum -c -")
    error_message = "destroy 清理命令必须校验目标 SHA 后才删除"
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
    error_message = "completed 应引用完成的 finalize exec"
  }

  assert {
    condition     = output.chunk_count > 1
    error_message = "chunk_count 应反映实际分片数"
  }
}