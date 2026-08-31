locals {
  bootstrap_content             = file("${path.module}/scripts/bootstrap.sh")
  bootstrap_target_path         = "/opt/las-dsh-installer/bootstrap/bootstrap.sh"
  dsh_qiniu_maas_plugin_package = "@qiniu/dsh-qiniu-maas-plugin"
  dsh_qiniu_maas_version        = "0.1.7"
  dsh_qiniu_maas_plugin_url     = "https://github.com/zhangzqs/dsh-qiniu-maas-plugin/releases/download/v${local.dsh_qiniu_maas_version}/qiniu-dsh-qiniu-maas-plugin-${local.dsh_qiniu_maas_version}.tgz"
  dsh_web_plugins = concat(
    [
      "dshmarket@v1.37.0",
      "dsh-better-sidebar@v0.17.1",
    ],
    var.enable_dsh_qiniu_maas_plugin ? [local.dsh_qiniu_maas_plugin_url] : [],
  )

  install_command = format(
    "exec '%s' '%s'",
    local.bootstrap_target_path,
    base64encode(jsonencode(merge(
      {
        dsh_web_proxy_port              = var.dsh_web_proxy_port
        dsh_web_public_authority        = var.dsh_web_public_authority
        static_preview_proxy_port       = var.static_preview_proxy_port
        static_preview_public_authority = var.static_preview_public_authority
        las_instance_id                 = var.las_instance_id
        las_region_id                   = var.las_region_id
        las_region_name                 = var.las_region_name
        preview_public_authorities      = var.preview_public_authorities
        preview_ports                   = var.preview_ports
        enable_code_server              = var.enable_code_server
        enable_dsh_qiniu_maas_plugin    = var.enable_dsh_qiniu_maas_plugin
        dsh_web_plugins                 = local.dsh_web_plugins
        dsh_web_plugins_to_remove       = var.enable_dsh_qiniu_maas_plugin ? [] : [local.dsh_qiniu_maas_plugin_package]
        enable_filebrowser              = var.enable_filebrowser
        dsh_web_username                = var.dsh_web_username
        dsh_web_password                = var.dsh_web_password
        dsh_environment                 = var.dsh_environment
      },
      var.enable_code_server ? {
        code_server_proxy_port       = var.code_server_proxy_port
        code_server_public_authority = var.code_server_public_authority
        code_server_password         = var.code_server_password
      } : {},
      var.enable_filebrowser ? {
        filebrowser_proxy_port       = tonumber(var.filebrowser_proxy_port)
        filebrowser_public_authority = var.filebrowser_public_authority
        filebrowser_username         = var.filebrowser_username
        filebrowser_password         = var.filebrowser_password
      } : {}
    ))),
  )
}

module "ansible_runtime" {
  source = "./ansible"

  target_dir = "/opt/las-dsh-installer/project"
}
