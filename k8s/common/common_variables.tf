variable "instance_type" {
  type        = string
  description = "K8s instance type"
  default     = "ecs.t1.c2m4"
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
    error_message = "instance_type parameter must be one of the allowed instance types"
  }
}

variable "instance_system_disk_size" {
  type        = number
  description = "System disk size in GiB"
  default     = 40

  validation {
    condition     = var.instance_system_disk_size >= 20
    error_message = "instance_system_disk_size parameter must be at least 20 GiB for K8s"
  }
}
