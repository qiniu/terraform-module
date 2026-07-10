variable "vpc_id" {
  type        = string
  description = "Existing VPC ID."
}

variable "subnet_id" {
  type        = string
  description = "Existing subnet ID."
}

variable "mysql_node_count" {
  type        = number
  description = "Number of MySQL InnoDB Cluster nodes."
  default     = 4
}

variable "security_group_ids" {
  type        = list(string)
  description = "Existing security groups in the demo VPC that allow InnoDB Cluster and Router traffic."
}

variable "image_id" {
  type        = string
  description = "Optional preinstalled image ID for subnets without package repository egress."
  default     = null
  nullable    = true
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
