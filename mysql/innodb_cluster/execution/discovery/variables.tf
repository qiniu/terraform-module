variable "mysql_nodes" {
  type = map(object({
    index    = number
    hostname = string
    id       = string
    password = string
  }))
}
