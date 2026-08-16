locals {
  dsh_version         = "0.1.0-rc.6"
  node_version        = "24.19.0"
  uv_version          = "0.12.5"
  code_server_version = "4.132.0"
  dsh_port            = 3080
  code_server_port    = 3086
  project_dir         = "/opt/las-dsh-installer/project"

  ansible_runtime_files = {
    "ansible.cfg"                                                  = "${path.module}/ansible/ansible.cfg"
    "inventory/default/hosts.yml"                                  = "${path.module}/ansible/inventory/default/hosts.yml"
    "playbooks/site.yml"                                           = "${path.module}/ansible/playbooks/site.yml"
    "pyproject.toml"                                               = "${path.module}/ansible/pyproject.toml"
    "uv.lock"                                                      = "${path.module}/ansible/uv.lock"
    "inventory/default/group_vars/all/main.yml"                    = "${path.module}/ansible/inventory/default/group_vars/all/main.yml"
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
    nodejs_version                 = local.node_version
    uv_version                     = local.uv_version
    dsh_version                    = local.dsh_version
    dsh_port                       = local.dsh_port
    nginx_proxy_port               = var.dsh_web_port
    dsh_public_authority           = var.dsh_web_public_authority
    dsh_preview_count_raw          = tostring(var.preview_count)
    dsh_preview_public_authorities = var.preview_public_authorities
    dsh_preview_ports              = var.preview_ports
    code_server_version            = local.code_server_version
    code_server_port               = local.code_server_port
    code_server_proxy_port         = var.code_server_web_port
    code_server_public_authority   = var.code_server_public_authority
    dsh_web_username               = var.web_username
    dsh_web_password               = var.web_password
    dsh_code_server_password       = var.code_server_password
  }))

  runtime_file_contents = {
    for relative_path, source_path in local.ansible_runtime_files :
    relative_path => filebase64(source_path)
  }

  runtime_file_metadata = {
    for relative_path, source_path in local.ansible_runtime_files :
    relative_path => {
      file_mode   = "0644"
      sha256      = filesha256(source_path)
      target_path = "${local.project_dir}/${relative_path}"
    }
  }

  runtime_manifest_content = join("", [
    for relative_path in sort(keys(local.runtime_file_metadata)) :
    "${local.runtime_file_metadata[relative_path].sha256}  ${relative_path}\n"
  ])

  runtime_manifest = {
    content     = base64encode(local.runtime_manifest_content)
    file_mode   = "0644"
    sha256      = sha256(local.runtime_manifest_content)
    target_path = "${local.project_dir}/.runtime-sha256"
  }

  bootstrap_content = templatefile("${path.module}/templates/install.sh.tftpl", {})

  bootstrap = {
    content     = base64encode(local.bootstrap_content)
    file_mode   = "0700"
    sha256      = sha256(local.bootstrap_content)
    target_path = "/opt/las-dsh-installer/bootstrap/install.sh"
  }

  install_command = "exec '${local.bootstrap.target_path}' '${local.uv_version}' '${local.runtime_manifest.target_path}' '${local.runtime_manifest.sha256}' '${local.extra_vars_base64}'"
}
