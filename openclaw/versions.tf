terraform {
  required_version = ">= 0.13.0"

  required_providers {
    qiniu = {
      source  = "hashicorp/qiniu"
      version = "~> 1.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "qiniu" {}

provider "random" {}
