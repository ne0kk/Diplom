
resource "yandex_storage_bucket" "state_storage" {
  bucket      = var.bucket_name
  folder_id   = var.folder_id
  anonymous_access_flags {
    read = var.anonymous_access_flags_read
    list = var.anonymous_access_flags_list
  }
}
