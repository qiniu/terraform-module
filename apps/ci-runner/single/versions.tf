terraform {
  required_version = ">= 1.6.0"

  required_providers {
    qiniu = {
      source  = "qiniu/qiniu"
      version = "= 1.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.8.0"
    }
  }
}
