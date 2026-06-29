variable "vpc_id" {
  type        = string
  description = "Existing VPC ID where the MySQL InnoDB Cluster will be deployed."

  validation {
    condition     = trimspace(var.vpc_id) != ""
    error_message = "vpc_id must not be empty."
  }
}

variable "subnet_id" {
  type        = string
  description = "Existing subnet ID where the MySQL InnoDB Cluster instances will be deployed."

  validation {
    condition     = trimspace(var.subnet_id) != ""
    error_message = "subnet_id must not be empty."
  }
}

variable "mysql_node_count" {
  type        = number
  description = "Number of MySQL server nodes in the InnoDB Cluster."
  default     = 4

  validation {
    condition     = var.mysql_node_count >= 3 && var.mysql_node_count <= 7
    error_message = "mysql_node_count must be between 3 and 7."
  }
}

variable "cluster_name" {
  type        = string
  description = "MySQL InnoDB Cluster name."
  default     = "mycluster"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,63}$", var.cluster_name))
    error_message = "cluster_name must start with a letter and contain only letters, numbers, and underscores, up to 64 characters."
  }
}

variable "instance_type" {
  type        = string
  description = "MySQL instance type."
  default     = "ecs.t1.c2m4"

  validation {
    condition = contains([
      "ecs.t1.c1m2",
      "ecs.t1.c2m4",
      "ecs.t1.c4m8",
      "ecs.t1.c8m16",
      "ecs.t1.c12m24",
      "ecs.t1.c16m32",
      "ecs.t1.c24m48",
      "ecs.t1.c32m64",
      "ecs.g1.c16m120",
      "ecs.g1.c32m240",
      "ecs.c1.c1m2",
      "ecs.c1.c2m4",
      "ecs.c1.c4m8",
      "ecs.c1.c8m16",
      "ecs.c1.c12m24",
      "ecs.c1.c16m32",
      "ecs.c1.c24m48",
      "ecs.c1.c32m64",
    ], var.instance_type)
    error_message = "instance_type parameter must be one of the allowed instance types."
  }
}

variable "instance_system_disk_size" {
  type        = number
  description = "System disk size in GiB."
  default     = 50

  validation {
    condition     = var.instance_system_disk_size >= 20
    error_message = "instance_system_disk_size must be at least 20."
  }
}

variable "instance_system_disk_type" {
  type        = string
  description = "System disk type. Set null to let Qiniu choose the default."
  default     = null
  nullable    = true

  validation {
    condition     = var.instance_system_disk_type == null || contains(["local.ssd", "cloud.ssd"], var.instance_system_disk_type)
    error_message = "instance_system_disk_type must be local.ssd, cloud.ssd, or null."
  }
}

variable "internet_max_bandwidth" {
  type        = number
  description = "Public internet bandwidth in Mbps for each MySQL node. Keep 0 by default."
  default     = 0

  validation {
    condition     = var.internet_max_bandwidth >= 0 && var.internet_max_bandwidth <= 300
    error_message = "internet_max_bandwidth must be between 0 and 300."
  }

  validation {
    condition = (
      var.internet_charge_type != "PeakBandwidth" ||
      var.internet_max_bandwidth == 0 ||
      contains([50, 100, 200], var.internet_max_bandwidth)
    )
    error_message = "internet_max_bandwidth must be 50, 100, or 200 when internet_charge_type is PeakBandwidth."
  }
}

variable "internet_charge_type" {
  type        = string
  description = "Internet charge type when internet_max_bandwidth is greater than 0."
  default     = "PeakBandwidth"

  validation {
    condition     = contains(["Bandwidth", "PeakBandwidth", "Traffic"], var.internet_charge_type)
    error_message = "internet_charge_type must be Bandwidth, PeakBandwidth, or Traffic."
  }
}

variable "internet_public_ip_type" {
  type        = string
  description = "Public IP type when internet_max_bandwidth is greater than 0."
  default     = "Dedicated"

  validation {
    condition     = contains(["Dedicated", "Shared", "Elastic"], var.internet_public_ip_type)
    error_message = "internet_public_ip_type must be Dedicated, Shared, or Elastic."
  }
}

variable "mysql_admin_username" {
  type        = string
  description = "MySQL administrator account used by MySQL Shell AdminAPI and applications."
  default     = "inno"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,31}$", var.mysql_admin_username))
    error_message = "mysql_admin_username must start with a letter and contain only letters, numbers, and underscores, up to 32 characters."
  }
}

variable "mysql_admin_password" {
  type        = string
  description = "MySQL administrator password. If null, a random password is generated."
  default     = null
  nullable    = true
  sensitive   = true

  validation {
    condition     = var.mysql_admin_password == null || length(var.mysql_admin_password) >= 8
    error_message = "mysql_admin_password must be at least 8 characters long when provided."
  }

  validation {
    condition = var.mysql_admin_password == null || (
      can(regex("[a-z]", var.mysql_admin_password)) &&
      can(regex("[A-Z]", var.mysql_admin_password)) &&
      can(regex("[0-9]", var.mysql_admin_password)) &&
      can(regex("[!-/:-@\\[-`{-~]", var.mysql_admin_password))
    )
    error_message = "mysql_admin_password must contain at least one lowercase letter, uppercase letter, digit, and special character when provided."
  }
}

variable "install_mysql_router_on_db_nodes" {
  type        = bool
  description = "Whether to install and bootstrap MySQL Router on every database node."
  default     = true
}

variable "additional_security_group_ids" {
  type        = list(string)
  description = "Additional security group IDs to attach to every MySQL node."
  default     = []
}
