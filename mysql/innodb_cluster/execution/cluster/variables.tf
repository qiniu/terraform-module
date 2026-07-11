variable "mysql_nodes" {
  type = map(object({
    hostname    = string
    id          = string
    private_key = string
  }))
}

variable "mysql_private_ips" {
  type      = map(string)
  sensitive = true
}

variable "mysql_data_volumes" {
  type = map(object({
    disk_id       = string
    attachment_id = string
  }))
}

variable "cluster_name" {
  type = string
}

variable "group_replication_uuid" {
  type = string
}

variable "mysql_admin_username" {
  type = string
}

variable "mysql_admin_password" {
  type      = string
  sensitive = true
}
