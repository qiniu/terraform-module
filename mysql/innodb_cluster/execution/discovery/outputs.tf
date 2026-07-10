output "mysql_private_ips" {
  value = {
    for node_key, execution in qiniu_compute_instance_exec.node_private_ip :
    node_key => trimspace(execution.stdout)
  }
  sensitive = true
}
