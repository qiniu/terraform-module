data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

locals {
  ubuntu_image_id = one([
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ]).id
}

# 生成资源后缀，避免命名冲突
resource "random_string" "resource_suffix" {
  length  = 6
  upper   = false
  lower   = true
  special = false
}

locals {
  standalone_suffix = random_string.resource_suffix.result
}
