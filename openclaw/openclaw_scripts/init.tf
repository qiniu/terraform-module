variable "openclaw_password" {
  type = string
}

resource "tls_private_key" "keypair" {
  algorithm = "ED25519"
}

output "init_script" {
  value = templatefile("${path.module}/templates/init.sh.tmpl", {
    openclaw_password   = var.openclaw_password
    openclaw_public_key = tls_private_key.keypair.public_key_openssh
  })
}

output "openclaw_private_key" {
  description = "ED25519 私钥（OpenSSH 格式），用于 SSH 登录 openclaw 用户"
  sensitive   = true
  value       = tls_private_key.keypair.private_key_openssh
}
