mock_provider "qiniu" {}

variables {
  instance_id      = "test-instance"
  private_key      = "test-private-key"
  content_base64   = "aGVsbG8gd29ybGQ="
  content_sha256   = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
  destination_path = "/opt/las-dsh-installer/runtime/test.tar.gz"
  chunk_size       = 4
}

run "plans_parallel_guarded_transfer" {
  command = plan

  assert {
    condition = (
      qiniu_compute_instance_exec.prepare.instance_id == "test-instance" &&
      qiniu_compute_instance_exec.prepare.user == "root" &&
      qiniu_compute_instance_exec.prepare.port == "22" &&
      qiniu_compute_instance_exec.prepare.shell == "bash" &&
      qiniu_compute_instance_exec.prepare.private_key == "test-private-key" &&
      qiniu_compute_instance_exec.prepare.store_stdout == false &&
      qiniu_compute_instance_exec.prepare.store_stderr == false &&
      qiniu_compute_instance_exec.chunks["000000"].store_stdout == false &&
      qiniu_compute_instance_exec.chunks["000000"].store_stderr == false &&
      qiniu_compute_instance_exec.finalize.store_stdout == false &&
      qiniu_compute_instance_exec.finalize.store_stderr == false
    )
    error_message = "所有 instance_exec 必须使用目标连接信息，且不得将输出保存到 state。"
  }

  assert {
    condition = (
      length(qiniu_compute_instance_exec.prepare.command) <= 8192 &&
      length(qiniu_compute_instance_exec.chunks["000000"].command) <= 8192 &&
      length(qiniu_compute_instance_exec.finalize.command) <= 8192 &&
      output.destination_path == "/opt/las-dsh-installer/runtime/test.tar.gz"
    )
    error_message = "prepare、chunk、finalize 命令必须受限，并且输出必须引用 finalize 完成状态。"
  }
}

run "rejects_invalid_base64" {
  command = plan
  variables { content_base64 = "bad\nbase64" }
  expect_failures = [var.content_base64]
}

run "rejects_invalid_hash" {
  command = plan
  variables { content_sha256 = "ABC" }
  expect_failures = [var.content_sha256]
}

run "rejects_unsafe_destination" {
  command = plan
  variables { destination_path = "/opt/../etc/passwd" }
  expect_failures = [var.destination_path]
}

run "keeps_maximum_rendered_chunk_below_limit" {
  command = plan
  variables {
    content_base64 = join("", [for batch in range(4) : join("", [for index in range(1024) : "A"])])
    content_sha256 = "e80232b4d18d0bb7e794be263ba937626f383f9917d4b8a737ba893a8f752293"
    chunk_size     = 4096
  }

  assert {
    condition     = length(qiniu_compute_instance_exec.chunks["000000"].command) <= 8192
    error_message = "最大分片的完整渲染命令必须小于等于 8192 字符。"
  }
}

run "rejects_mismatched_content_hash" {
  command = plan
  variables { content_sha256 = "0000000000000000000000000000000000000000000000000000000000000000" }
  expect_failures = [terraform_data.input_validation]
}
