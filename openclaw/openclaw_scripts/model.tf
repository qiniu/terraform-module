variable "qiniu_maas_api_key" {
  type        = string
  description = "Qiniu MAAS API Key"
}

# apply 时自动精简 models.json，只保留 model.tf 实际使用的字段。
# 脚本自检：若 models.json 已是精简形态则跳过，避免反复重写导致 trigger hash 漂移。
# models.json 来源于 https://portal.qiniu.com/ai-inference/model 模型广场的接口返回 JSON
resource "terraform_data" "minify_models_json" {
  triggers_replace = {
    source_hash = filesha256("${path.module}/models.json")
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/minify_models.py ${path.module}/models.json"
  }

  input = jsondecode(file("${path.module}/models.json"))
}


locals {
  # 构造 openclaw 兼容的 models 数组
  # 字段映射：id/name <-> models.json 原值；
  #   input      <- architecture.input_modalities
  #   reasoning  <- architecture.reasoning.supported
  #   contextWindow <- model_constraints.context_length（>0 时输出）
  #   maxTokens     <- model_constraints.max_tokens（>0 时输出）
  openclaw_models = [
    for m in terraform_data.minify_models_json.input.data : merge(
      {
        id        = m.id
        name      = m.name
        input     = m.architecture.input_modalities
        reasoning = m.architecture.reasoning.supported
        cost      = { input = 0, output = 0, cacheRead = 0, cacheWrite = 0 }
      },
      m.model_constraints.context_length > 0 ? { contextWindow = m.model_constraints.context_length } : {},
      m.model_constraints.max_tokens > 0 ? { maxTokens = m.model_constraints.max_tokens } : {},
    )
  ]

  provider_json = jsonencode({
    baseUrl = "https://api.qnaigc.com/v1"
    apiKey  = var.qiniu_maas_api_key
    api     = "openai-completions"
    models  = slice(local.openclaw_models, 0, 10)
  })
}

output "model_config_script" {
  value = templatefile("${path.module}/templates/model.sh.tmpl", {
    provider_json = local.provider_json
  })
}
