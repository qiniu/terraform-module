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
    tls = {
      source  = "hashicorp/tls"
      version = "= 4.1.0"
    }
  }
}

provider "qiniu" {}

provider "random" {}
