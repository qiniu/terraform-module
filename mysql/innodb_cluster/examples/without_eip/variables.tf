variable "vpc_id" {
  type        = string
  description = "Existing VPC ID."
}

variable "subnet_id" {
  type        = string
  description = "Existing subnet ID."
}

variable "security_group_ids" {
  type        = list(string)
  description = "Existing security groups that allow InnoDB Cluster and Router traffic."
}

variable "image_id" {
  type        = string
  description = "Custom image ID with mysql, mysqld, mysqlsh, and mysqlrouter already installed."
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
