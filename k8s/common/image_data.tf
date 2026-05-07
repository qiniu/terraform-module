data "qiniu_compute_image" "ubuntu" {
  name = "Ubuntu"
}

locals {
  ubuntu_image_id = data.qiniu_compute_image.ubuntu.id
}
