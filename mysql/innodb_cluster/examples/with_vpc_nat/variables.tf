variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
  default     = "mysql-innodb-demo"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR block."
  default     = "192.168.7.0/24"
}

variable "subnet_cidr_block" {
  type        = string
  description = "Subnet CIDR block."
  default     = "192.168.7.0/24"
}

variable "mysql_node_count" {
  type        = number
  description = "Number of MySQL InnoDB Cluster nodes."
  default     = 4
}

variable "mysql_admin_password" {
  type        = string
  description = "Optional MySQL administrator password. If null, the module generates one."
  default     = null
  nullable    = true
  sensitive   = true
}

variable "enable_validation" {
  type        = bool
  description = "Whether to run end-to-end MySQL HA checks through InstanceConnect."
  default     = false
}
