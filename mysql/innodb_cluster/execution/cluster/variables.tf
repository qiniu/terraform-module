variable "mysql_nodes" {
  type = map(object({
    index    = number
    hostname = string
    id       = string
    password = string
  }))
}

variable "mysql_member_hostnames" {
  type = list(string)
}

variable "mysql_private_ips" {
  type      = map(string)
  sensitive = true
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

variable "install_mysql_router_on_nodes" {
  type = bool
}
