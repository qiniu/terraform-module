variable "instance_type" {
  type        = string
  description = "MySQL instance type"
  default     = "ecs.t1.c1m2"
  validation {
    condition = var.instance_type != "" && contains([
      "ecs.t1.c1m2",
      "ecs.t1.c2m4",
      "ecs.t1.c4m8",
      "ecs.t1.c12m24",
      "ecs.t1.c32m64",
      "ecs.t1.c24m48",
      "ecs.t1.c8m16",
      "ecs.t1.c16m32",
      "ecs.g1.c16m120",
      "ecs.g1.c32m240",
      "ecs.c1.c1m2",
      "ecs.c1.c2m4",
      "ecs.c1.c4m8",
      "ecs.c1.c8m16",
      "ecs.c1.c16m32",
      "ecs.c1.c24m48",
      "ecs.c1.c12m24",
      "ecs.c1.c32m64",
    ], var.instance_type)
    error_message = "instance_type parameter is required but not provided"
  }
}

variable "instance_system_disk_size" {
  type        = number
  description = "System disk size in GiB"
  default     = 20

  validation {
    condition     = var.instance_system_disk_size > 0
    error_message = "instance_system_disk_size parameter must be a positive integer"
  }
}

variable "mysql_username" {
  type        = string
  description = "MySQL username"
  default     = "admin"

  validation {
    condition     = length(var.mysql_username) >= 1 && length(var.mysql_username) <= 32
    error_message = "mysql_username parameter must be between 1 and 32 characters long"
  }
}

variable "mysql_password" {
  type        = string
  description = "MySQL password"
  sensitive   = true

  validation {
    condition     = length(var.mysql_password) >= 8
    error_message = "mysql_password parameter must be at least 8 characters long"
  }

  validation {
    condition     = can(regex("[a-z]", var.mysql_password)) && can(regex("[A-Z]", var.mysql_password)) && can(regex("[0-9]", var.mysql_password)) && can(regex("[!-/:-@\\[-`{-~]", var.mysql_password))
    error_message = "mysql_password parameter must contain at least one lowercase letter, one uppercase letter, one digit, and one special character"
  }
}

variable "mysql_db_name" {
  type        = string
  description = "Initial MySQL database name (optional)"
  default     = ""

  validation {
    condition     = var.mysql_db_name == "" || length(var.mysql_db_name) >= 1 && length(var.mysql_db_name) <= 64 && can(regex("^[a-zA-Z0-9_]*$", var.mysql_db_name)) && !contains(["mysql", "information_schema", "performance_schema", "sys"], var.mysql_db_name)
    error_message = "mysql_db_name must be 1-64 chars, only alphanumeric/underscore, and not a reserved name (mysql, information_schema, performance_schema, sys)"
  }
}

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
