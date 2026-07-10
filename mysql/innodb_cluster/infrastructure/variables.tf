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
    index    = number
    hostname = string
  }))
}

variable "instance_type" {
  type = string
}

variable "instance_system_disk_size" {
  type = number
}

variable "instance_system_disk_type" {
  type     = string
  nullable = true
}

variable "additional_security_group_ids" {
  type = list(string)
}
