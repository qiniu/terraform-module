variable "qiniu_maas_api_key" {
  type        = string
  description = "Qiniu MAAS API Key"
}

# models.json 来源于 https://portal.qiniu.com/ai-inference/model 模型广场的接口返回 JSON
# apply 时自动精简 models.json（按 created_time 倒序、只保留必要字段）并写回原文件。
# 全程在 Terraform 内完成，不依赖任何外部脚本（如 python）。
# 精简逻辑幂等：已精简的 models.json 再精简结果不变，local_file 不会反复重写。
locals {
  raw_models = jsondecode(file("${path.module}/models.json"))

  # 以 id 建立索引，便于排序后按 id 找回完整对象
  model_by_id = {
    for m in local.raw_models.data : m.id => m
  }

  # 按 created_time 倒序排序（ISO 8601 字典序 = 时间序），
  # created_time 为 null 时 coalesce 兜底为空串，排到末尾。
  sorted_ids = [
    for key in reverse(sort([
      for m in local.raw_models.data : "${coalesce(m.created_time, "")}\t${m.id}"
    ])) : split("\t", key)[1]
  ]

  sorted_models = [for id in local.sorted_ids : local.model_by_id[id]]

  # 构造 openclaw 兼容的 models 数组
  # 字段映射：id/name <-> models.json 原值；
  #   input      <- architecture.input_modalities
  #   reasoning  <- architecture.reasoning.supported
  #   contextWindow <- model_constraints.context_length（>0 时输出）
  #   maxTokens     <- model_constraints.max_tokens（>0 时输出）
  openclaw_models = [
    for m in local.sorted_models : merge(
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
    # 这里只取前20个最新模型，实测模型太多了 openclaw 设置页面会直接崩溃掉
    models = slice(local.openclaw_models, 0, 20)
  })
}

# 将精简后的 JSON 写回 models.json。content 与磁盘内容一致时 local_file 不会重写，
# 因此即便 file() 在 plan 阶段读到的是已精简版本，也不会产生循环写入。
locals {
  minified_models_json = jsonencode({
    data = [
      for m in local.sorted_models : {
        id           = m.id
        name         = m.name
        created_time = m.created_time
        architecture = {
          input_modalities = m.architecture.input_modalities
          reasoning        = { supported = m.architecture.reasoning.supported }
        }
        model_constraints = {
          context_length = m.model_constraints.context_length
          max_tokens     = m.model_constraints.max_tokens
        }
      }
    ]
  })
}

resource "terraform_data" "write_back_minified_models_json" {
  triggers_replace = {
    script = "echo '${local.minified_models_json}' > ${path.module}/models.json"
  }
  provisioner "local-exec" {
    command = self.triggers_replace.script
  }
}

output "model_config_script" {
  value = templatefile("${path.module}/templates/model.sh.tmpl", {
    provider_json = local.provider_json
  })
}
