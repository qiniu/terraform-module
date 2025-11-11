resource "qiniu_compute_instance" "mysql_primary_node" {
  instance_type    = var.instance_type // 虚拟机实例规格
  name             = format("mysql-standalone-%s", local.standalone_suffix)
  description      = format("Standalone MySQL node %s", local.standalone_suffix)
  image_id         = local.ubuntu_image_id         // 预设的MysSQL系统镜像ID
  system_disk_size = var.instance_system_disk_size // 系统盘大小，单位是GiB
  user_data = base64encode(templatefile("${path.module}/mysql_standalone.sh", {
    mysql_username = var.mysql_username,
    mysql_password = var.mysql_password,
    mysql_db_name  = var.mysql_db_name,
  }))
}
