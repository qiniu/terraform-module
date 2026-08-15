terraform {
  required_version = ">= 1.6"

  required_providers {
    qiniu = {
      source  = "qiniu/qiniu"
      version = "= 1.0.0"
    }
  }
}