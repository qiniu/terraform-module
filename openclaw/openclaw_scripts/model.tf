variable "default_model" {
  type        = string
  description = "默认模型 ID"
}

variable "qiniu_maas_api_key" {
  type        = string
  description = "Qiniu MAAS API Key"
}

locals {
  # 各模型的参数覆盖表
  model_params = {
    "minimax/minimax-m2.5"   = { reasoning = false, ctx_window = 200000, max_tokens = 128000 }
    "deepseek/deepseek-chat" = { reasoning = false, ctx_window = 64000, max_tokens = 8192 }
    "deepseek/deepseek-r1"   = { reasoning = true, ctx_window = 64000, max_tokens = 8192 }
    "qwen/qwen-max"          = { reasoning = false, ctx_window = 32000, max_tokens = 8192 }
    "kimi/kimi-k2"           = { reasoning = false, ctx_window = 128000, max_tokens = 8192 }
  }

  # 未匹配模型时使用的默认参数
  default_model_params = {
    reasoning  = false
    ctx_window = 128000
    max_tokens = 8192
  }

  # 根据 default_model 选取参数（未匹配则用默认值）
  selected_model_params = merge(
    local.default_model_params,
    lookup(local.model_params, var.default_model, {})
  )

  # 拼出 provider JSON
  provider_json = jsonencode({
    baseUrl = "https://api.qnaigc.com/v1"
    apiKey  = var.qiniu_maas_api_key
    api     = "openai-completions"
    models = [
      {
        id            = var.default_model
        name          = var.default_model
        reasoning     = local.selected_model_params.reasoning
        input         = ["text"]
        cost          = { input = 0, output = 0, cacheRead = 0, cacheWrite = 0 }
        contextWindow = local.selected_model_params.ctx_window
        maxTokens     = local.selected_model_params.max_tokens
      }
    ]
  })
}

output "model_config_script" {
  value = <<-EOT
#!/bin/bash
set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Configuring OpenClaw model..."

PROVIDER_JSON=$(cat <<ENDJSON
${local.provider_json}
ENDJSON
)

openclaw config set models.mode merge
openclaw config set "models.providers.qiniu" --strict-json "$PROVIDER_JSON"
openclaw models set "qiniu/${var.default_model}"

log "OpenClaw model configuration."
EOT
}
