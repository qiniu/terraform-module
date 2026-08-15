data "qiniu_compute_images" "ubuntu" {
  type  = "Official"
  state = "Available"

  lifecycle {
    postcondition {
      condition = length([
        for image in self.items : image.id
        if image.os_distribution == "Ubuntu" && image.os_version == "24.04 LTS"
      ]) == 1
      error_message = "当前区域必须恰好存在一个可用的 Ubuntu 24.04 LTS 官方镜像。"
    }
  }
}

locals {
  ubuntu_image_ids = [
    for image in data.qiniu_compute_images.ubuntu.items : image.id
    if image.os_distribution == "Ubuntu" && image.os_version == "24.04 LTS"
  ]
}
