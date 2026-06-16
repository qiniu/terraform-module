variable "openclaw_password" {
  type = string
}

output "init_script" {
  value = templatefile("${path.module}/templates/init.sh.tmpl", {
    openclaw_password = var.openclaw_password
  })
}
