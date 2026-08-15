mock_provider "qiniu" {
  override_during = plan
}

run "rejects_when_unique_ubuntu_image_is_unavailable" {
  command         = plan
  expect_failures = [data.qiniu_compute_images.ubuntu]
}
