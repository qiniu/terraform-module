# ============================================================================
# OpenClaw Module - Variable Validation Unit Tests
# ============================================================================
# 运行方式：在 openclaw 目录下执行 terraform test
# 要求：Terraform >= 1.6
#
# 策略说明：
# - 使用 mock_provider 跳过 qiniu provider 凭证验证，Provider 配置阶段不再失败。
# - Terraform 执行顺序：变量校验 → data source → precondition，因此变量校验
#   失败后不会走到 precondition，无需真实数据源。
# - 本测试文件仅覆盖变量校验失败（expect_failures）场景。校验通过的合法输入
#   场景会因 mock 空数据源触发 precondition "未找到镜像" 而失败，需在具备
#   真实 qiniu 凭证的集成测试环境中运行。
# - lifecycle precondition 和 data source 相关的校验需集成测试或手动验证。
# ============================================================================

mock_provider "qiniu" {}

# ============================================================================
# 文件级辅助变量：所有 run 块共用的最小合法参数
# ============================================================================

variables {
  root_password      = "Test@12345"
  qiniu_maas_api_key = "test-api-key-0123456789"
}

# ============================================================================
# 1. instance_type 校验
#    当 cost_discount_activity_id 未填写（null 或 ""）时，必须是枚举规格。
#    填写了非空活动 ID 时，放行任意规格。
# ============================================================================

run "invalid_instance_type_default_null" {
  command = plan

  variables {
    instance_type = "invalid.type.x1"
  }

  expect_failures = [
    var.instance_type,
  ]
}

run "invalid_instance_type_empty_string" {
  command = plan

  variables {
    cost_charge_type          = "PrePaid"
    cost_period               = 1
    cost_period_unit          = "Month"
    cost_discount_activity_id = ""
    instance_type             = "invalid.type.x1"
  }

  expect_failures = [
    var.instance_type,
  ]
}

# ============================================================================
# 2. system_disk_size 校验 - 范围 [20, 500] 且为 10 的倍数
# ============================================================================

run "invalid_system_disk_size_too_small" {
  command = plan
  variables { system_disk_size = 10 }
  expect_failures = [var.system_disk_size]
}

run "invalid_system_disk_size_too_large" {
  command = plan
  variables { system_disk_size = 600 }
  expect_failures = [var.system_disk_size]
}

run "invalid_system_disk_size_not_multiple_of_10" {
  command = plan
  variables { system_disk_size = 55 }
  expect_failures = [var.system_disk_size]
}

# ============================================================================
# 3. system_disk_type 校验 - 仅 local.ssd / cloud.ssd
# ============================================================================

run "invalid_system_disk_type" {
  command = plan
  variables { system_disk_type = "cloud.hdd" }
  expect_failures = [var.system_disk_type]
}

# ============================================================================
# 4. internet_max_bandwidth 校验
#    范围 [1, 300]；PeakBandwidth 时仅允许 50/100/200
# ============================================================================

run "invalid_internet_max_bandwidth_too_small" {
  command = plan
  variables { internet_max_bandwidth = 0 }
  expect_failures = [var.internet_max_bandwidth]
}

run "invalid_internet_max_bandwidth_too_large" {
  command = plan
  variables { internet_max_bandwidth = 500 }
  expect_failures = [var.internet_max_bandwidth]
}

run "invalid_internet_max_bandwidth_peak" {
  command = plan
  variables {
    internet_charge_type   = "PeakBandwidth"
    internet_max_bandwidth = 150
  }
  expect_failures = [var.internet_max_bandwidth]
}

# ============================================================================
# 5. internet_charge_type 校验 - Bandwidth / PeakBandwidth / Traffic
# ============================================================================

run "invalid_internet_charge_type" {
  command = plan
  variables { internet_charge_type = "PayByUsage" }
  expect_failures = [var.internet_charge_type]
}

# ============================================================================
# 6. internet_public_ip_type 校验 - Dedicated / Shared
# ============================================================================

run "invalid_internet_public_ip_type" {
  command = plan
  variables { internet_public_ip_type = "Private" }
  expect_failures = [var.internet_public_ip_type]
}

# ============================================================================
# 7. root_password 校验 - >= 8 位，含字母、数字、特殊符号
# ============================================================================

run "invalid_root_password_too_short" {
  command = plan
  variables { root_password = "Ab@123" }
  expect_failures = [var.root_password]
}

run "invalid_root_password_no_letter" {
  command = plan
  variables { root_password = "12345678@" }
  expect_failures = [var.root_password]
}

run "invalid_root_password_no_digit" {
  command = plan
  variables { root_password = "Abcdefgh@" }
  expect_failures = [var.root_password]
}

run "invalid_root_password_no_special" {
  command = plan
  variables { root_password = "Abcdef123" }
  expect_failures = [var.root_password]
}

# ============================================================================
# 8. cost_charge_type 校验 - PostPaid / PrePaid
# ============================================================================

run "invalid_cost_charge_type" {
  command = plan
  variables { cost_charge_type = "AnnualSubscription" }
  expect_failures = [var.cost_charge_type]
}

# ============================================================================
# 9. cost_period 校验
#    PostPaid 时必须为 null；PrePaid 时必填且在 Year: [1,3] / Month: [1,36]
# ============================================================================

run "invalid_cost_period_postpaid_not_null" {
  command = plan
  variables {
    cost_charge_type = "PostPaid"
    cost_period      = 1
  }
  expect_failures = [var.cost_period]
}

run "invalid_cost_period_prepaid_null" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = null
    cost_period_unit = "Month"
  }
  expect_failures = [var.cost_period]
}

run "invalid_cost_period_year_range" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 5
    cost_period_unit = "Year"
  }
  expect_failures = [var.cost_period]
}

run "invalid_cost_period_month_range" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 48
    cost_period_unit = "Month"
  }
  expect_failures = [var.cost_period]
}

# ============================================================================
# 10. cost_period_unit 校验
#     PostPaid 时必须为 null；PrePaid 时必填且为 Month / Year
# ============================================================================

run "invalid_cost_period_unit_postpaid_not_null" {
  command = plan
  variables {
    cost_charge_type = "PostPaid"
    cost_period_unit = "Month"
  }
  expect_failures = [var.cost_period_unit]
}

run "invalid_cost_period_unit_prepaid_null" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 1
    cost_period_unit = null
  }
  expect_failures = [var.cost_period_unit]
}

run "invalid_cost_period_unit_value" {
  command = plan
  variables {
    cost_charge_type = "PrePaid"
    cost_period      = 1
    cost_period_unit = "Day"
  }
  expect_failures = [var.cost_period_unit]
}

# ============================================================================
# 11. cost_discount_activity_id 校验 - 仅 PrePaid 支持
# ============================================================================

run "invalid_cost_discount_activity_id_postpaid" {
  command = plan
  variables {
    cost_charge_type          = "PostPaid"
    cost_discount_activity_id = "activity-123"
  }
  expect_failures = [var.cost_discount_activity_id]
}

# ============================================================================
# 12. extra_port_forwards 校验 - 仅 Shared IP 可配置，端口 [1, 65535]
# ============================================================================

run "invalid_extra_port_forwards_dedicated" {
  command = plan
  variables {
    internet_public_ip_type = "Dedicated"
    extra_port_forwards     = [8080]
  }
  expect_failures = [var.extra_port_forwards]
}

run "invalid_extra_port_forwards_port_zero" {
  command = plan
  variables {
    internet_public_ip_type = "Shared"
    extra_port_forwards     = [0]
  }
  expect_failures = [var.extra_port_forwards]
}

run "invalid_extra_port_forwards_port_exceed" {
  command = plan
  variables {
    internet_public_ip_type = "Shared"
    extra_port_forwards     = [70000]
  }
  expect_failures = [var.extra_port_forwards]
}

# ============================================================================
# 13. qiniu_maas_api_key 校验 - 不可为空
# ============================================================================

run "invalid_qiniu_maas_api_key_empty" {
  command = plan
  variables { qiniu_maas_api_key = "" }
  expect_failures = [var.qiniu_maas_api_key]
}

# ============================================================================
# 14. qq_secret 格式校验 - 空值或 AppID:AppSecret
# ============================================================================

run "invalid_qq_secret_format" {
  command = plan
  variables { qq_secret = "missing-colon-format" }
  expect_failures = [var.qq_secret]
}

run "invalid_qq_secret_extra_colons" {
  command = plan
  variables { qq_secret = "a:b:c" }
  expect_failures = [var.qq_secret]
}

# ============================================================================
# 15. gateway_port 校验 - 范围 [1, 65535]
# ============================================================================

run "invalid_gateway_port_zero" {
  command = plan
  variables { gateway_port = 0 }
  expect_failures = [var.gateway_port]
}

run "invalid_gateway_port_exceed" {
  command = plan
  variables { gateway_port = 99999 }
  expect_failures = [var.gateway_port]
}

# ============================================================================
# 已知局限性
# ============================================================================
# 1. 本文件仅覆盖变量校验失败场景（expect_failures）。校验通过的合法输入场景
#    会因 mock_provider 空数据源触发 precondition "未找到匹配的 OpenClaw 镜像"
#    而失败。合法输入测试需要在有真实 qiniu 凭证的环境中运行。
#
# 2. lifecycle precondition（selected_image_id != null）涉及 data source
#    返回值，mock_provider 对 qiniu 的 list(object) 类型存在兼容性问题，
#    precondition 测试需要集成环境或手动验证。
