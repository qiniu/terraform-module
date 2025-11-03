data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

locals {
  ubuntu_image_id = [
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ][0].id
}
