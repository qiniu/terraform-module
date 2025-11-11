
variable "mysql_replica_count" {
  type        = number
  description = "Number of MySQL replica nodes"
  default     = 2

  validation {
    condition     = var.mysql_replica_count >= 1 && var.mysql_replica_count <= 2
    error_message = "mysql_replica_count must be between 1 and 2"
  }
}

variable "mysql_replication_username" {
  type        = string
  description = "MySQL replication username"
  default     = "replication"

  validation {
    condition     = length(var.mysql_replication_username) >= 1 && length(var.mysql_replication_username) <= 32
    error_message = "mysql_replication_username parameter must be between 1 and 32 characters long"
  }
}
