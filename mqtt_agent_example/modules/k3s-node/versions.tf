terraform {
  required_version = "> 0.12.0"

  required_providers {
    qiniu = {
      source  = "qiniu/qiniu"
      version = "~> 1.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}