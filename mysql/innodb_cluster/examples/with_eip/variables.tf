variable "vpc_id" {
  type        = string
  description = "Existing VPC ID."
}

variable "subnet_id" {
  type        = string
  description = "Existing subnet ID."
}

variable "subnet_cidr_block" {
  type        = string
  description = "CIDR block of subnet_id, used as the SNAT source range."
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

variable "nat_eip_bandwidth" {
  type        = number
  description = "Bandwidth in Mbps for the NAT gateway EIP."
  default     = 1
}

variable "nat_eip_internet_charge_type" {
  type        = string
  description = "Internet charge type for the NAT gateway EIP."
  default     = "Traffic"
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
