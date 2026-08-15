output "id" {
  description = "唯一可用的 Ubuntu 24.04 LTS 官方镜像 ID。"
  value       = try(one(local.ubuntu_image_ids), "")
}
