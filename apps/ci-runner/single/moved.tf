moved {
  from = random_string.suffix
  to   = module.infrastructure.random_string.suffix
}

moved {
  from = data.qiniu_compute_images.ubuntu
  to   = module.infrastructure.data.qiniu_compute_images.ubuntu
}

moved {
  from = data.qiniu_compute_region.current
  to   = module.infrastructure.data.qiniu_compute_region.current
}

moved {
  from = qiniu_compute_key_pair.deployment
  to   = module.infrastructure.qiniu_compute_key_pair.deployment
}

moved {
  from = qiniu_compute_instance.ci_runner
  to   = module.infrastructure.qiniu_compute_instance.ci_runner
}

moved {
  from = qiniu_compute_instance_public_access.endpoint
  to   = module.infrastructure.qiniu_compute_instance_public_access.runnerd
}

moved {
  from = qiniu_compute_instance_public_access.ssh
  to   = module.infrastructure.qiniu_compute_instance_public_access.ssh
}
