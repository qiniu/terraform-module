variable "mysql_nodes" {
  type = map(object({
    index    = number
    hostname = string
  }))
}

variable "mysql_node_ids" {
  type = map(string)
}

variable "mysql_node_passwords" {
  type      = map(string)
  sensitive = true
}

variable "node_network_commands" {
  type      = map(string)
  sensitive = true
}

variable "node_setup_commands" {
  type      = map(string)
  sensitive = true
}

variable "cluster_reconcile_command" {
  type      = string
  sensitive = true
}

variable "router_bootstrap_commands" {
  type      = map(string)
  sensitive = true
}

variable "member_remove_commands" {
  type      = map(string)
  sensitive = true
}

variable "install_mysql_router_on_nodes" {
  type = bool
}
