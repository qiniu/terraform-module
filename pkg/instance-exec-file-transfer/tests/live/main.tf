# ============================================================================
# instance-exec-file-transfer 真实环境集成测试（Live Acceptance）
# ============================================================================
# 前置：source apps/ci-runner/single/env.sh 并 export
#   TF_VAR_instance_password='<strong-password>'，再 terraform init && apply。
# 流程：创建临时 Ubuntu 实例 → 发布小文件（hello.txt 直传）与大文件
# （uv.lock 真实内容，分片）→ verify 校验 SHA-256/0644，不符则 apply 失败。
# destroy 会清理实例、key pair 与发布文件。
# ============================================================================

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

resource "qiniu_compute_key_pair" "test" {
  name        = "iftest-${random_string.suffix.result}"
  description = "Temporary key for instance-exec-file-transfer live test - Managed by Terraform"
  mode        = "generate"
}

data "qiniu_compute_images" "ubuntu" {
  type  = "Official"
  state = "Available"
}

data "qiniu_compute_region" "current" {}

locals {
  instance_name = "if-transfer-live-${random_string.suffix.result}"

  ubuntu_image_ids = [
    for image in data.qiniu_compute_images.ubuntu.items : image.id
    if image.os_distribution == "Ubuntu" && image.os_version == "24.04 LTS"
  ]
  ubuntu_image_id = try(one(local.ubuntu_image_ids), "")

  # 待发布内容
  hello_content = base64encode("hello from instance-exec-file-transfer\n")

  # 大文件：真实 uv.lock 样例（约 59 KiB，base64 后 ~78 KiB，超过直传阈值将分片）
  big_content = base64encode(file("${path.module}/fixtures/uv.lock"))

  shared = {
    instance_id = qiniu_compute_instance.test.id
    user        = var.user
    port        = "22"
    private_key = qiniu_compute_key_pair.test.private_key
  }
}

resource "qiniu_compute_instance" "test" {
  name          = local.instance_name
  description   = "Instance exec file transfer live test - Managed by Terraform"
  instance_type = var.instance_type
  image_id      = local.ubuntu_image_id

  system_disk_size = var.system_disk_size
  system_disk_type = data.qiniu_compute_region.current.region.features.ebs.supported ? "cloud.ssd" : "local.ssd"

  internet_max_bandwidth = var.internet_max_bandwidth
  internet_charge_type   = "PeakBandwidth"

  cost_charge_type  = "PostPaid"
  disable_public_ip = true
  key_pair_id       = qiniu_compute_key_pair.test.id
  password          = var.instance_password

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }

  lifecycle {
    precondition {
      condition     = length(local.ubuntu_image_ids) == 1
      error_message = "当前区域必须恰好存在一个可用的 Ubuntu 24.04 LTS 官方镜像。"
    }
  }
}

# ---------------------------------------------------------------------------
# 引导：等待 SSH/InstanceConnect 就绪并创建目标父目录（root 所有）
# 模块按安全设计不自动创建目标父目录（避免 TOCTOU/symlink 攻击），
# 因此 live 测试先显式创建 /opt/if-test。
# ---------------------------------------------------------------------------
resource "qiniu_compute_instance_exec" "bootstrap" {
  instance_id = local.shared.instance_id
  user        = local.shared.user
  port        = local.shared.port
  private_key = local.shared.private_key
  shell       = "bash"

  command = <<-EOT
    set -e
    for i in $(seq 1 60); do
      if mkdir -p /opt/if-test && chmod 0755 /opt/if-test; then
        echo "BOOTSTRAP OK"
        exit 0
      fi
      sleep 5
    done
    echo "bootstrap failed: SSH not ready" >&2
    exit 1
  EOT

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }
}

# ---------------------------------------------------------------------------
# 小文件直传（direct 子模块）
# ---------------------------------------------------------------------------
module "small" {
  source = "../../"

  depends_on = [qiniu_compute_instance_exec.bootstrap]

  instance_id    = local.shared.instance_id
  user           = local.shared.user
  port           = local.shared.port
  private_key    = local.shared.private_key
  shell          = "bash"
  content        = local.hello_content
  content_sha256 = sha256(base64decode(local.hello_content))
  target_path    = "/opt/if-test/hello.txt"
  file_mode      = "0644"
}

# ---------------------------------------------------------------------------
# 大文件分片（chunked 子模块）
# ---------------------------------------------------------------------------
module "big" {
  source = "../../"

  depends_on = [qiniu_compute_instance_exec.bootstrap]

  instance_id    = local.shared.instance_id
  user           = local.shared.user
  port           = local.shared.port
  private_key    = local.shared.private_key
  shell          = "bash"
  content        = local.big_content
  content_sha256 = sha256(base64decode(local.big_content))
  target_path    = "/opt/if-test/uv.lock"
  file_mode      = "0644"
}

# ---------------------------------------------------------------------------
# 校验：content/mode 与发布目标一致（失败则 apply 失败）
# ---------------------------------------------------------------------------
resource "qiniu_compute_instance_exec" "verify" {
  depends_on = [
    module.small,
    module.big,
  ]

  instance_id = local.shared.instance_id
  user        = local.shared.user
  port        = local.shared.port
  private_key = local.shared.private_key
  shell       = "bash"

  command = <<-EOT
    set -e
    [ "$(sha256sum /opt/if-test/hello.txt | awk '{print $1}')" = '${sha256(base64decode(local.hello_content))}' ] || { echo "hello.txt hash mismatch" >&2; exit 1; }
    [ "$(stat -c %a /opt/if-test/hello.txt)" = "644" ] || { echo "hello.txt mode mismatch" >&2; exit 1; }
    [ "$(sha256sum /opt/if-test/uv.lock | awk '{print $1}')" = '${sha256(base64decode(local.big_content))}' ] || { echo "uv.lock hash mismatch" >&2; exit 1; }
    [ "$(stat -c %a /opt/if-test/uv.lock)" = "644" ] || { echo "uv.lock mode mismatch" >&2; exit 1; }
    echo "IF-TEST VERIFY OK"
  EOT

  store_stdout = false
  store_stderr = false

  timeouts {
    create = "30m"
    delete = "10m"
  }
}
