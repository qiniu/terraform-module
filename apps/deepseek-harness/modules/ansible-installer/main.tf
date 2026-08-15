locals {
  ansible_runtime_files = {
    "ansible.cfg"                                                  = "${path.module}/ansible/ansible.cfg"
    "inventory/localhost.yml"                                      = "${path.module}/ansible/inventory/localhost.yml"
    "playbooks/site.yml"                                           = "${path.module}/ansible/playbooks/site.yml"
    "pyproject.toml"                                               = "${path.module}/ansible/pyproject.toml"
    "uv.lock"                                                      = "${path.module}/ansible/uv.lock"
    "group_vars/all/main.yml"                                      = "${path.module}/ansible/group_vars/all/main.yml"
    "roles/base/defaults/main.yml"                                 = "${path.module}/ansible/roles/base/defaults/main.yml"
    "roles/base/tasks/main.yml"                                    = "${path.module}/ansible/roles/base/tasks/main.yml"
    "roles/code_server/defaults/main.yml"                          = "${path.module}/ansible/roles/code_server/defaults/main.yml"
    "roles/code_server/handlers/main.yml"                          = "${path.module}/ansible/roles/code_server/handlers/main.yml"
    "roles/code_server/tasks/main.yml"                             = "${path.module}/ansible/roles/code_server/tasks/main.yml"
    "roles/code_server/templates/code-server.service.j2"           = "${path.module}/ansible/roles/code_server/templates/code-server.service.j2"
    "roles/code_server/templates/config.yaml.j2"                   = "${path.module}/ansible/roles/code_server/templates/config.yaml.j2"
    "roles/deepseek_harness/defaults/main.yml"                     = "${path.module}/ansible/roles/deepseek_harness/defaults/main.yml"
    "roles/deepseek_harness/handlers/main.yml"                     = "${path.module}/ansible/roles/deepseek_harness/handlers/main.yml"
    "roles/deepseek_harness/tasks/main.yml"                        = "${path.module}/ansible/roles/deepseek_harness/tasks/main.yml"
    "roles/deepseek_harness/templates/deepseek-harness.service.j2" = "${path.module}/ansible/roles/deepseek_harness/templates/deepseek-harness.service.j2"
    "roles/las_dsh_environment/defaults/main.yml"                  = "${path.module}/ansible/roles/las_dsh_environment/defaults/main.yml"
    "roles/las_dsh_environment/tasks/main.yml"                     = "${path.module}/ansible/roles/las_dsh_environment/tasks/main.yml"
    "roles/las_dsh_environment/templates/SKILL.md.j2"              = "${path.module}/ansible/roles/las_dsh_environment/templates/SKILL.md.j2"
    "roles/nginx/defaults/main.yml"                                = "${path.module}/ansible/roles/nginx/defaults/main.yml"
    "roles/nginx/handlers/main.yml"                                = "${path.module}/ansible/roles/nginx/handlers/main.yml"
    "roles/nginx/tasks/main.yml"                                   = "${path.module}/ansible/roles/nginx/tasks/main.yml"
    "roles/nginx/templates/deepseek-harness.conf.j2"               = "${path.module}/ansible/roles/nginx/templates/deepseek-harness.conf.j2"
    "roles/nodejs/defaults/main.yml"                               = "${path.module}/ansible/roles/nodejs/defaults/main.yml"
    "roles/nodejs/handlers/main.yml"                               = "${path.module}/ansible/roles/nodejs/handlers/main.yml"
    "roles/nodejs/tasks/cleanup.yml"                               = "${path.module}/ansible/roles/nodejs/tasks/cleanup.yml"
    "roles/nodejs/tasks/main.yml"                                  = "${path.module}/ansible/roles/nodejs/tasks/main.yml"
  }

  extra_vars_base64 = base64encode(jsonencode({
    nodejs_version                 = var.node_version
    uv_version                     = var.uv_version
    dsh_version                    = var.dsh_version
    dsh_port                       = var.dsh_port
    nginx_proxy_port               = var.nginx_proxy_port
    dsh_public_authority           = var.public_authority
    dsh_preview_count_raw          = tostring(var.preview_count)
    dsh_preview_public_authorities = var.preview_public_authorities
    dsh_preview_ports              = var.preview_ports
    code_server_version            = var.code_server_version
    code_server_port               = var.code_server_port
    code_server_proxy_port         = var.code_server_proxy_port
    code_server_public_authority   = var.code_server_public_authority
    dsh_web_username               = var.web_username
    dsh_web_password               = var.web_password
    dsh_code_server_password       = var.code_server_password
  }))

  install_command = templatefile("${path.module}/templates/install.sh.tftpl", {
    uv_version             = var.uv_version
    ansible_archive_base64 = filebase64(data.archive_file.ansible_runtime.output_path)
    ansible_archive_sha256 = data.archive_file.ansible_runtime.output_sha256
    extra_vars_base64      = local.extra_vars_base64
  })
}

data "archive_file" "ansible_runtime" {
  type        = "tar.gz"
  output_path = "${path.module}/.terraform/ansible-runtime.tar.gz"

  dynamic "source" {
    for_each = local.ansible_runtime_files

    content {
      content  = file(source.value)
      filename = source.key
    }
  }
}
