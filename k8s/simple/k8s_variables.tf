variable "k8s_version" {
  type        = string
  description = "Kubernetes version"
  default     = "1.28.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.k8s_version))
    error_message = "k8s_version must be in format X.Y.Z (e.g., 1.28.0)"
  }
}

variable "worker_count" {
  type        = number
  description = "Number of K8s worker nodes"
  default     = 2

  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 10
    error_message = "worker_count must be between 1 and 10"
  }
}

variable "pod_network_cidr" {
  type        = string
  description = "Pod network CIDR"
  default     = "10.244.0.0/16"

  validation {
    condition     = can(cidrhost(var.pod_network_cidr, 0))
    error_message = "pod_network_cidr must be a valid CIDR block"
  }
}

variable "service_cidr" {
  type        = string
  description = "Service network CIDR"
  default     = "10.96.0.0/12"

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "service_cidr must be a valid CIDR block"
  }
}

variable "cni_plugin" {
  type        = string
  description = "CNI plugin (flannel, calico, or weave)"
  default     = "flannel"

  validation {
    condition     = contains(["flannel", "calico", "weave"], var.cni_plugin)
    error_message = "cni_plugin must be one of: flannel, calico, weave"
  }
}
