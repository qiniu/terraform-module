variable "openclaw_password" {
  type = string
}

variable "openclaw_public_key" {
  type = string
}

output "init_script" {
  value = templatefile("${path.module}/templates/init.sh.tmpl", {
    openclaw_password   = var.openclaw_password
    openclaw_public_key = var.openclaw_public_key
  })
}
