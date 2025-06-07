###cloud vars
variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}


variable "default_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "bucket_name" {
  type        = string
  default     = "yc-terr-state"
  description = "bucket_name"
}


variable "ydb_database_name" {
  type        = string
  default     = "terraform-state-lock"
}

variable "deletion_protection_db" {
  type        = bool
  default     = "true"
}

variable "default_region" {
  type        = string
  default     = "ru-central1"
}

variable "enable_throttling_rcu_limit" {
  type        = bool
  default     = false
}

variable "provisioned_rcu_limit" {
  type        = number
  default     = 10
}

variable "storage_size_limit" {
  type        = number
  default     = 50
}

variable "throttling_rcu_limit" {
  type        = number
  default     = 0
}

variable "profile" {
  type        = string
  default     = "default"
}

variable "skip_credentials_validation" {
  type        = bool
  default     = true
}

variable "skip_metadata_api_check" {
  type        = bool
  default     = true
}

variable "skip_region_validation" {
  type        = bool
  default     = true
}

variable "skip_requesting_account_id" {
  type        = bool
  default     = true
}

variable "dynamodb_table_name" {
  type        = string
  default     = "lock"
}

variable "billing_mode" {
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "hash_key" {
  type        = string
  default     = "LockID"
}

variable "att_name" {
  type        = string
  default     = "LockID"
}

variable "att_type" {
  type        = string
  default     = "S"
}

variable "anonymous_access_flags_read" {
  type        = bool
  default     = false
}

variable "anonymous_access_flags_list" {
  type        = bool
  default     = false
}


variable "account_name" {
  type        = string
  default     = "diplom"
}

variable "role_sa" {
  type        = string
  default     = "editor"
}