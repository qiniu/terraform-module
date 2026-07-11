data "qiniu_compute_region" "current" {}

data "qiniu_compute_images" "available_official_images" {
  type  = "Official"
  state = "Available"
}

locals {
  ubuntu_images = [
    for item in data.qiniu_compute_images.available_official_images.items : item
    if item.os_distribution == "Ubuntu" && item.os_version == "24.04 LTS"
  ]

  selected_image_id = var.image_id != null ? var.image_id : try(local.ubuntu_images[0].id, null)
}

resource "qiniu_compute_placement_group" "mysql" {
  name        = format("mysql-innodb-%s", var.cluster_suffix)
  description = format("Placement group for MySQL InnoDB Cluster %s", var.cluster_suffix)
  strategy    = "Spread"
}

resource "qiniu_compute_key_pair" "mysql" {
  name        = format("mysql-innodb-%s", var.cluster_suffix)
  description = format("SSH key pair for MySQL InnoDB Cluster %s", var.cluster_suffix)
  mode        = "generate"
}

resource "qiniu_compute_instance" "mysql_nodes" {
  for_each = var.mysql_nodes

  name               = each.value.hostname
  hostname           = each.value.hostname
  description        = format("MySQL InnoDB Cluster node %s (%s)", each.key, var.cluster_name)
  instance_type      = var.instance_type
  placement_group_id = qiniu_compute_placement_group.mysql.id
  image_id           = local.selected_image_id
  system_disk_size   = var.instance_system_disk_size
  system_disk_type   = "cloud.ssd"
  state              = "Running"
  subnet_id          = var.subnet_id
  key_pair_id        = qiniu_compute_key_pair.mysql.id

  security_group_ids = var.security_group_ids

  timeouts {
    create = "30m"
    update = "20m"
    delete = "10m"
  }

  lifecycle {
    precondition {
      condition     = local.selected_image_id != null
      error_message = "未找到 Ubuntu 24.04 LTS 官方镜像，请确认当前区域已上架该镜像。"
    }

    precondition {
      condition     = data.qiniu_compute_region.current.region.features.ebs.supported
      error_message = "当前区域不支持 EBS 云盘，无法部署 MySQL InnoDB Cluster。"
    }
  }
}
