# environments.tf
locals {
  # Only 'local' environment uses LocalStack
  is_local = var.environment == "local"

  provider_config = {
    local = {
      skip_credentials_validation = true
      skip_metadata_api_check     = true
      skip_requesting_account_id  = true
      s3_use_path_style           = true
      access_key                  = "test"
      secret_key                  = "test"
      endpoints = {
        s3         = "http://localhost:4566"
        sns        = "http://localhost:4566"
        sts        = "http://localhost:4566"
        iam        = "http://localhost:4566"
        lambda     = "http://localhost:4566"
        opensearch = "http://localhost:4566"
        es         = "http://localhost:4566"
        events     = "http://localhost:4566"
        cloudwatch = "http://localhost:4566"
        logs       = "http://localhost:4566"
        sfn        = "http://localhost:4566"
      }
    }
  }
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = local.is_local ? local.provider_config.local.access_key : null
  secret_key                  = local.is_local ? local.provider_config.local.secret_key : null
  skip_credentials_validation = local.is_local
  skip_metadata_api_check     = local.is_local
  skip_requesting_account_id  = local.is_local
  s3_use_path_style           = local.is_local

  dynamic "endpoints" {
    for_each = local.is_local ? [local.provider_config.local.endpoints] : []
    content {
      s3         = endpoints.value.s3
      sns        = endpoints.value.sns
      sts        = endpoints.value.sts
      iam        = endpoints.value.iam
      lambda     = endpoints.value.lambda
      opensearch = endpoints.value.opensearch
      es         = endpoints.value.es
      events     = endpoints.value.events
      cloudwatch = endpoints.value.cloudwatch
      logs       = endpoints.value.logs
      sfn        = endpoints.value.sfn
    }
  }

  default_tags {
    tags = var.tags
  }
}
