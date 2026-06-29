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

variable "nat_eip_bandwidth" {
  type        = number
  description = "NAT EIP bandwidth in Mbps."
  default     = 100
}

variable "enable_nat" {
  type        = bool
  description = "Whether to create NAT/EIP/SNAT for subnet outbound access."
  default     = true
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
  description = "Whether to create a temporary validator instance and run end-to-end MySQL HA checks."
  default     = false
}
