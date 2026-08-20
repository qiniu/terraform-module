# ============================================================================
# direct 子模块契约测试（issue #58 Task 1/2）
# ============================================================================
# 覆盖：单命令直传 ≤ 90000 且纯 ASCII、目标父目录安全边界、marker+SHA 覆盖
# 前置校验、同目录原子发布、destroy 清理命令约束。
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

run "rejects_non_ascii_paths" {
  command = plan

  variables {
    target_path  = "/😀"
    staging_root = "/😀"
  }

  expect_failures = [var.target_path, var.staging_root]
}

run "partial_payload_stays_within_limit" {
  command = apply

  assert {
    condition     = length(qiniu_compute_instance_exec.publish.command) <= 90000
    error_message = "直传命令必须 <= 90000 字节"
  }

  assert {
    condition     = can(regex("^[\\x00-\\x7F]*$", qiniu_compute_instance_exec.publish.command))
    error_message = "直传命令必须是纯 ASCII"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, var.target_path)
    error_message = "直传命令应引用目标绝对路径"
  }
}

run "publish_command_has_security_guards" {
  command = plan

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "stat -c %U")
    error_message = "直传命令必须校验目标父目录所有者为 root"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "realpath")
    error_message = "直传命令必须校验目标父目录 realpath"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "-L \"$TD\"")
    error_message = "直传命令必须拒绝目标父目录为 symlink"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "qiniu-pub")
    error_message = "直传命令应在目标同目录临时发布后原子 mv"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "sha256sum -c -")
    error_message = "直传命令必须校验内容 SHA"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "grep -Fq")
    error_message = "直传命令必须校验受管 marker"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "stat -c %U \"$R\"")
    error_message = "直传命令必须校验 staging root 所有者为 root"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "realpath -m \"$R\"")
    error_message = "直传命令必须校验 staging root realpath"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "-L \"$R\"")
    error_message = "直传命令必须拒绝 staging root 为 symlink"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.command, "for marker in \"$R\"/*/marker")
    error_message = "直传命令必须通过旧 marker 支持受管文件的内容更新"
  }
}

run "destroy_command_constraints" {
  command = plan

  assert {
    condition     = can(regex("^[\\x00-\\x7F]*$", qiniu_compute_instance_exec.publish.destroy_command))
    error_message = "直传 destroy 命令必须是纯 ASCII"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.publish.destroy_command) <= 90000
    error_message = "直传 destroy 命令必须 <= 90000 字节"
  }

  assert {
    condition     = strcontains(qiniu_compute_instance_exec.publish.destroy_command, "sha256sum -c -")
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
    error_message = "completed 应引用完成的 publish exec"
  }
}


run "max_payload_stays_within_90000" {
  command = plan

  variables {
    # 86600 字节 base64 payload（'0' 为合法 base64 字符）+ 最长路径，
    # 模拟最坏直传场景（range 上限 1024，改用 format 宽度填充）
    content      = format("%086600d", 0)
    target_path  = "/${format("%0511d", 0)}"
    staging_root = "/${format("%0511d", 1)}"
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.publish.command) <= 90000
    error_message = "最大直传 payload + 长路径时命令必须仍 <= 90000 字节"
  }

  assert {
    condition     = can(regex("^[\\x00-\\x7F]*$", qiniu_compute_instance_exec.publish.command))
    error_message = "最大直传 payload 时命令必须仍是纯 ASCII"
  }
}
