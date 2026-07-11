variable "cluster_suffix" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "image_id" {
  type     = string
  nullable = true
}

variable "mysql_nodes" {
  type = map(object({
    hostname = string
  }))
}

variable "instance_type" {
  type = string
}

variable "instance_system_disk_size" {
  type = number
}

variable "ebs_supported" {
  type = bool
}

variable "security_group_ids" {
  type = list(string)
}
