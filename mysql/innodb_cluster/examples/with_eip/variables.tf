variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
  default     = "mysql-innodb-with-eip"
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDR block."
  default     = "192.168.77.0/24"
}

variable "subnet_cidr_block" {
  type        = string
  description = "Subnet CIDR block, used as the SNAT source range."
  default     = "192.168.77.0/24"
}

variable "mysql_node_count" {
  type        = number
  description = "Number of MySQL InnoDB Cluster nodes."
  default     = 4
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
