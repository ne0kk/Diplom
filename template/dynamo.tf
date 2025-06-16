resource "yandex_ydb_database_serverless" "db" {
  name                = var.ydb_database_name
  deletion_protection = var.deletion_protection_db
  folder_id           = var.folder_id
  location_id         = var.default_region

  serverless_database {
    enable_throttling_rcu_limit = var.enable_throttling_rcu_limit
    provisioned_rcu_limit       = var.provisioned_rcu_limit
    storage_size_limit          = var.storage_size_limit
    throttling_rcu_limit        = var.throttling_rcu_limit
  }
}

provider "aws" {
  region = var.default_region
  endpoints {
    dynamodb = yandex_ydb_database_serverless.db.document_api_endpoint
  }
  profile = var.profile
  skip_credentials_validation   = var.skip_credentials_validation
  skip_metadata_api_check       = var.skip_metadata_api_check
  skip_region_validation        = var.skip_region_validation
  skip_requesting_account_id    = var.skip_requesting_account_id
}

resource "aws_dynamodb_table" "lock" {
  name          = var.dynamodb_table_name
  billing_mode  = var.billing_mode
  hash_key      = var.hash_key
  attribute {
    name        = var.att_name
    type        = var.att_type
  }
}

