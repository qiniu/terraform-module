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
