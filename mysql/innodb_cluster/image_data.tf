data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

locals {
  ubuntu_images = [
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ]

  # 选用的系统镜像ID。mock_provider 下可能为空，由实例 precondition 给出清晰错误。
  ubuntu_image_id = length(local.ubuntu_images) > 0 ? local.ubuntu_images[0].id : null
}
