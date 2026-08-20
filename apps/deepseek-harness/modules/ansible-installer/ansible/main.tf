variable "target_dir" {
  description = "Ansible 运行时在目标主机上的目录。"
  type        = string
}

locals {
  runtime_paths = [
    "ansible.cfg",
    "inventory/default/hosts.yml",
    "inventory/default/group_vars/all/main.yml",
    "playbooks/site.yml",
    "pyproject.toml",
    "uv.lock",
    "roles/base/defaults/main.yml",
    "roles/base/tasks/main.yml",
    "roles/code_server/defaults/main.yml",
    "roles/code_server/handlers/main.yml",
    "roles/code_server/tasks/main.yml",
    "roles/code_server/templates/code-server.service.j2",
    "roles/code_server/templates/config.yaml.j2",
    "roles/filebrowser/defaults/main.yml",
    "roles/filebrowser/handlers/main.yml",
    "roles/filebrowser/tasks/main.yml",
    "roles/filebrowser/templates/filebrowser.service.j2",
    "roles/filebrowser/templates/config.yaml.j2",
    "roles/deepseek_harness/defaults/main.yml",
    "roles/deepseek_harness/handlers/main.yml",
    "roles/deepseek_harness/tasks/main.yml",
    "roles/deepseek_harness/templates/deepseek-harness.service.j2",
    "roles/managed_skills/tasks/main.yml",
    "roles/managed_skills/templates/las-dsh-environment/SKILL.md.j2",
    "roles/managed_skills/templates/las-dsh-environment/inspect-session.sh.j2",
    "roles/managed_skills/templates/las-static-preview/SKILL.md.j2",
    "roles/managed_skills/templates/las-static-preview/publish.sh.j2",
    "roles/managed_skills/templates/las-static-preview/unpublish.sh.j2",
    "roles/managed_skills/templates/las-preview-ports/SKILL.md.j2",
    "roles/managed_skills/templates/las-preview-ports/manage-preview-port.sh.j2",
    "roles/managed_skills/templates/las-filebrowser-share/SKILL.md.j2",
    "roles/managed_skills/templates/las-filebrowser-share/filebrowser-share.sh.j2",
    "roles/managed_skills/files/las-filebrowser-share/filebrowser-share.py",
    "roles/nginx/handlers/main.yml",
    "roles/nginx/tasks/main.yml",
    "roles/nginx/templates/deepseek-harness.conf.j2",
    "roles/nodejs/defaults/main.yml",
    "roles/nodejs/tasks/cleanup.yml",
    "roles/nodejs/tasks/main.yml",
    "roles/skill_installer/tasks/main.yml",
  ]
}

output "runtime_file_contents" {
  description = "按目标绝对路径索引的 Ansible 运行时文件 base64 内容。"
  value = {
    for relative_path in local.runtime_paths :
    "${var.target_dir}/${relative_path}" => filebase64("${path.module}/${relative_path}")
  }
  sensitive = true
}

output "runtime_file_metadata" {
  description = "按目标绝对路径索引的 Ansible 运行时文件权限和 SHA-256。"
  value = {
    for relative_path in local.runtime_paths :
    "${var.target_dir}/${relative_path}" => {
      file_mode = "0644"
      sha256    = filesha256("${path.module}/${relative_path}")
    }
  }
}
