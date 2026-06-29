# ============================================================================
# MySQL InnoDB Cluster Module - Variable Validation Unit Tests
# ============================================================================
# 运行方式：在 mysql/innodb_cluster 目录下执行 terraform test
# 本文件只覆盖变量校验失败场景，不创建真实 qiniu 资源。
# ============================================================================

mock_provider "qiniu" {}

variables {
  vpc_id    = "vpc-test"
  subnet_id = "subnet-test"
}

run "invalid_mysql_node_count_too_small" {
  command = plan

  variables {
    mysql_node_count = 2
  }

  expect_failures = [var.mysql_node_count]
}

run "invalid_mysql_node_count_too_large" {
  command = plan

  variables {
    mysql_node_count = 8
  }

  expect_failures = [var.mysql_node_count]
}

run "invalid_vpc_id_empty" {
  command = plan

  variables {
    vpc_id = ""
  }

  expect_failures = [var.vpc_id]
}

run "invalid_subnet_id_empty" {
  command = plan

  variables {
    subnet_id = ""
  }

  expect_failures = [var.subnet_id]
}

run "invalid_mysql_admin_password_too_short" {
  command = plan

  variables {
    mysql_admin_password = "Ab@123"
  }

  expect_failures = [var.mysql_admin_password]
}

run "invalid_mysql_admin_password_no_special" {
  command = plan

  variables {
    mysql_admin_password = "Abcdef123"
  }

  expect_failures = [var.mysql_admin_password]
}

run "invalid_peak_bandwidth_value" {
  command = plan

  variables {
    internet_charge_type   = "PeakBandwidth"
    internet_max_bandwidth = 10
  }

  expect_failures = [var.internet_max_bandwidth]
}
