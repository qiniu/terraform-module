variable "mysql_nodes" {
  type = map(object({
    hostname    = string
    id          = string
    private_key = string
  }))
}
