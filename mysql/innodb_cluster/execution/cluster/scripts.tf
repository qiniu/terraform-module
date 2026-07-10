locals {
  mysql_member_hostnames = [
    for node_key in sort(keys(var.mysql_nodes)) : var.mysql_nodes[node_key].hostname
  ]

  hosts_file_entries = join("\n", [
    for node_key in sort(keys(var.mysql_nodes)) :
    format("%s %s", var.mysql_private_ips[node_key], var.mysql_nodes[node_key].hostname)
  ])

  node_network_commands = {
    for node_key, node in var.mysql_nodes :
    node_key => templatefile("${path.module}/templates/mysql_node_network.sh", {
      hosts_file_entries = local.hosts_file_entries
    })
  }

  node_setup_commands = {
    for node_key, node in var.mysql_nodes :
    node_key => templatefile("${path.module}/templates/mysql_innodb_node.sh", {
      server_id                = tonumber(node_key)
      node_hostname            = node.hostname
      bootstrap_hostname       = local.mysql_member_hostnames[0]
      group_replication_uuid   = var.group_replication_uuid
      mysql_admin_username     = var.mysql_admin_username
      mysql_admin_password_b64 = base64encode(var.mysql_admin_password)
      install_mysql_router     = tostring(var.install_mysql_router_on_nodes)
    })
  }

  cluster_reconcile_command = templatefile("${path.module}/templates/mysql_cluster_reconcile.sh", {
    cluster_name_json       = jsonencode(var.cluster_name)
    mysql_admin_username_js = jsonencode(var.mysql_admin_username)
    mysql_admin_password_js = jsonencode(var.mysql_admin_password)
    member_hostnames_json   = jsonencode(local.mysql_member_hostnames)
  })

  router_bootstrap_commands = {
    for node_key, node in var.mysql_nodes :
    node_key => templatefile("${path.module}/templates/mysql_router_bootstrap.sh", {
      bootstrap_hostname       = local.mysql_member_hostnames[0]
      mysql_admin_username     = var.mysql_admin_username
      mysql_admin_password_b64 = base64encode(var.mysql_admin_password)
    })
  }

  member_remove_commands = {
    for node_key, node in var.mysql_nodes :
    node_key => templatefile("${path.module}/templates/mysql_member_remove.sh", {
      bootstrap_hostname_json = jsonencode(local.mysql_member_hostnames[0])
      target_hostname_json    = jsonencode(node.hostname)
      cluster_name_json       = jsonencode(var.cluster_name)
      mysql_admin_username_js = jsonencode(var.mysql_admin_username)
      mysql_admin_password_js = jsonencode(var.mysql_admin_password)
    }) if node_key != "01"
  }
}
