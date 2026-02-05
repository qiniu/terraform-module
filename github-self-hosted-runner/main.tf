# ==========================================
# GitHub Actions Self-hosted Runner
# ==========================================

# 生成虚拟机的随机密码
resource "random_password" "runner_instance_password" {
  length  = 16
  special = true
  lower   = true
  upper   = true
  numeric = true
}

# 创建 Runner 虚拟机实例
resource "qiniu_compute_instance" "github_runner" {
  instance_type    = var.instance_type
  name             = format("github-runner-%s", local.runner_suffix)
  description      = format("GitHub Actions Runner for %s/%s", local.github_owner, local.github_repo)
  image_id         = local.ubuntu_image_id
  system_disk_size = var.instance_system_disk_size

  # 使用 templatefile 渲染初始化脚本，传递变量
  user_data = base64encode(templatefile("${path.module}/runner_setup.sh", {
    github_token       = var.github_token,
    github_repo_url    = var.github_repo_url,
    runner_name        = local.runner_name,
    runner_labels      = join(",", local.runner_labels),
    runner_username    = var.runner_username,
    enable_docker      = var.enable_docker,
    additional_packages = join(" ", var.additional_packages),
  }))

  # 虚拟机的 root 密码
  password = random_password.runner_instance_password.result
}
