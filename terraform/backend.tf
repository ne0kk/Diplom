terraform {
  backend "s3" {
    endpoints = {
      s3 =       "https://storage.yandexcloud.net"
      dynamodb = "https://docapi.serverless.yandexcloud.net/ru-central1/b1gv3i9qq3bt8g400fs4/etn1lfmv3onhjvnfmnn9"
    } 
    region                      = "ru-central1"
    bucket                      = "yc-terr-state"
    key                         = "terraform-remote-state"
    dynamodb_table              = "lock"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
