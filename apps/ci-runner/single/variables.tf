variable "github_app_id" {
  type        = number
  description = <<-EOT
    GitHub App 的数字 ID（不是 App 名称或 slug）。
    获取位置：GitHub App 设置页 https://github.com/settings/apps/<slug> ，"General" 页面顶部展示的 "App ID" 字段即为该数字。
  EOT

  validation {
    condition = (
      var.github_app_id > 0 &&
      floor(var.github_app_id) == var.github_app_id
    )
    error_message = "github_app_id 必须是大于 0 的整数。"
  }
}

variable "github_app_slug" {
  type        = string
  description = <<-EOT
    GitHub App 的 slug，即 App URL 中的 <slug> 部分。
    获取位置：GitHub App 设置页地址 https://github.com/settings/apps/<slug> 的最后一段路径；
    同时也是 App 安装地址 https://github.com/apps/<slug> 中域名后的那一段。
  EOT

  validation {
    condition     = length(trimspace(var.github_app_slug)) > 0
    error_message = "github_app_slug 不能为空。"
  }
}

variable "github_oauth_client_id" {
  type        = string
  description = <<-EOT
    GitHub App 用于 OAuth 用户登录的 Client ID，通常以 "Iv1." 开头。
    获取位置：GitHub App 设置页 https://github.com/settings/apps/<slug> 中展示的 "Client ID" 字段（可点击复制）。
  EOT

  validation {
    condition     = length(trimspace(var.github_oauth_client_id)) > 0
    error_message = "github_oauth_client_id 不能为空。"
  }
}

variable "github_oauth_client_secret" {
  type        = string
  description = <<-EOT
    GitHub App 用于 OAuth 用户登录的 Client secret，敏感值。
    获取位置：GitHub App 设置页 https://github.com/settings/apps/<slug> 的 "Client secrets" 区域，
    点击 "Generate a new client secret" 生成后查看；该值仅在生成时展示一次，请立即保存。
    建议通过环境变量 TF_VAR_github_oauth_client_secret 注入，不要写入 terraform.tfvars 并提交到代码库。
  EOT
  sensitive   = true

  validation {
    condition     = length(trimspace(var.github_oauth_client_secret)) > 0
    error_message = "github_oauth_client_secret 不能为空。"
  }
}

variable "github_app_private_key_base64" {
  type        = string
  description = <<-EOT
    经过 Base64 编码的 GitHub App PEM 私钥，敏感值。
    获取位置：GitHub App 设置页 https://github.com/settings/apps/<slug> 底部 "Private keys" 区域，
    点击 "Generate a private key" 后浏览器会下载形如 <slug>.<date>.private-key.pem 的私钥文件；
    随后执行 `base64 -w0 <file>.pem`（macOS 为 `base64 -i <file>.pem`）编码为单行 Base64 字符串。
    建议通过环境变量 TF_VAR_github_app_private_key_base64 注入，不要将 .pem 文件或其 Base64 值提交到代码库。
  EOT
  sensitive   = true

  validation {
    condition     = can(regex("PRIVATE KEY", base64decode(var.github_app_private_key_base64)))
    error_message = "github_app_private_key_base64 必须是有效的 Base64，且解码内容必须包含 PRIVATE KEY。"
  }
}

variable "bootstrap_admin_github_login" {
  type        = string
  description = <<-EOT
    初始管理员的 GitHub 用户名（login name），例如 "octocat"。
    模块会自动通过 GitHub API 解析为数字用户 ID，无需手动查询。
    部署完成后，使用该账号登录 runnerd 控制台（dashboard_url）完成初始化。
  EOT

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$", var.bootstrap_admin_github_login))
    error_message = "bootstrap_admin_github_login 必须是有效的 GitHub 用户名。"
  }
}

variable "instance_type" {
  type        = string
  description = <<-EOT
    运行 runnerd 的 ECS 实例规格，必须以 "ecs." 开头。
    获取位置：七牛云控制台云服务器 ECS 购买页的可选规格列表。
    示例："ecs.t1s.c1m2"。
  EOT
  default     = "ecs.t1s.c1m2"

  validation {
    condition     = can(regex("^ecs\\.[0-9A-Za-z]+(\\.[0-9A-Za-z]+)+$", var.instance_type))
    error_message = "instance_type 必须是以 ecs. 开头的有效 ECS 实例规格。"
  }
}

variable "system_disk_size" {
  type        = number
  description = <<-EOT
    ECS 系统盘大小，单位 GiB，取值范围 20 到 500 且必须是 10 的倍数。
    磁盘类型无需指定：模块会根据当前区域是否支持 EBS 自动选择 cloud.ssd 或 local.ssd。
  EOT
  default     = 20

  validation {
    condition = (
      var.system_disk_size >= 20 &&
      var.system_disk_size <= 500 &&
      floor(var.system_disk_size) == var.system_disk_size &&
      var.system_disk_size % 10 == 0
    )
    error_message = "system_disk_size 必须是 20 到 500 之间且为 10 的倍数的整数。"
  }
}

variable "internet_max_bandwidth" {
  type        = number
  description = <<-EOT
    PeakBandwidth（按峰值带宽计费）模式下 ECS 的公网最大带宽，单位 Mbps，只能为 50、100 或 200 之一。
    计费说明以七牛云 ECS 公网带宽计费文档为准。
  EOT
  default     = 100

  validation {
    condition     = contains([50, 100, 200], var.internet_max_bandwidth)
    error_message = "internet_max_bandwidth 在 PeakBandwidth 模式下只能为 50、100 或 200 Mbps。"
  }
}

variable "enable_ssh_port_forward" {
  type        = bool
  description = <<-EOT
    是否通过七牛云 PortForward 将实例 SSH 22 端口暴露到公网，默认 false。
    仅建议在 SSH 调试期间开启：开启后可通过输出 ssh_endpoints 获取公网 SSH 端点，
    通过输出 ssh_private_key 获取部署私钥；调试结束后请重新关闭。
  EOT
  default     = false
}

variable "cost_charge_type" {
  type        = string
  description = <<-EOT
    实例计费类型。PostPaid 为按量计费（后付费），PrePaid 为包年包月（预付费）。
    按量计费适合短期测试；包年包月适合长期运行，费用更低。
  EOT
  default     = "PostPaid"

  validation {
    condition     = contains(["PostPaid", "PrePaid"], var.cost_charge_type)
    error_message = "cost_charge_type 必须为 PostPaid 或 PrePaid。"
  }
}

variable "cost_period" {
  type        = number
  description = <<-EOT
    预付费购买时长，仅在 cost_charge_type 为 PrePaid 时生效。
    取值范围：cost_period_unit 为 Month 时 1-36，为 Year 时 1-3。
  EOT
  default     = null

  validation {
    condition     = var.cost_charge_type != "PostPaid" || var.cost_period == null
    error_message = "PostPaid 模式下 cost_period 必须为 null（不设置）。"
  }

  validation {
    condition     = var.cost_charge_type != "PrePaid" || var.cost_period != null
    error_message = "PrePaid 模式下必须设置 cost_period。"
  }

  validation {
    condition = (
      var.cost_period == null ||
      (
        var.cost_period_unit == "Year" ?
        (var.cost_period >= 1 && var.cost_period <= 3) :
        (var.cost_period >= 1 && var.cost_period <= 36)
      )
    )
    error_message = "cost_period 在 Month 单位时取值 1-36，Year 单位时取值 1-3。"
  }
}

variable "cost_period_unit" {
  type        = string
  description = <<-EOT
    预付费购买时长单位，仅在 cost_charge_type 为 PrePaid 时生效。
    支持 Month（月）和 Year（年）。
  EOT
  default     = null

  validation {
    condition     = var.cost_charge_type != "PostPaid" || var.cost_period_unit == null
    error_message = "PostPaid 模式下 cost_period_unit 必须为 null（不设置）。"
  }

  validation {
    condition     = var.cost_charge_type != "PrePaid" || var.cost_period_unit != null
    error_message = "PrePaid 模式下必须设置 cost_period_unit。"
  }

  validation {
    condition     = var.cost_period_unit == null || contains(["Month", "Year"], var.cost_period_unit)
    error_message = "cost_period_unit 必须为 Month 或 Year。"
  }
}

variable "cost_discount_activity_id" {
  type        = string
  description = <<-EOT
    预付费促销活动 ID，仅在 cost_charge_type 为 PrePaid 时可选设置。
    获取位置：七牛云控制台促销活动页面。
  EOT
  default     = null

  validation {
    condition     = var.cost_charge_type != "PostPaid" || var.cost_discount_activity_id == null
    error_message = "PostPaid 模式下 cost_discount_activity_id 必须为 null（不设置）。"
  }
}
