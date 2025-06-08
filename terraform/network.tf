# VPC create
# Network
resource "yandex_vpc_network" "default" {
  name = var.vpc_name
}

# Подсеть public-a
resource "yandex_vpc_subnet" "public-a" {
  name           = var.subnet-a
  zone           = var.zone-a
  network_id     = "${yandex_vpc_network.default.id}"
  v4_cidr_blocks = var.cidr-a
}

# Подсеть public-b
resource "yandex_vpc_subnet" "public-b" {
  name           = var.subnet-b
  zone           = var.zone-b
  network_id     = "${yandex_vpc_network.default.id}"
  v4_cidr_blocks = var.cidr-b
}

# Подсеть public-d
resource "yandex_vpc_subnet" "public-d" {
  name           = var.subnet-d
  zone           = var.zone-d
  network_id     = "${yandex_vpc_network.default.id}"
  v4_cidr_blocks = var.cidr-d
 
}

# Подсеть public-d2
resource "yandex_vpc_subnet" "public-d2" {
  name           = "New_subnet"
  zone           = var.zone-d
  network_id     = "${yandex_vpc_network.default.id}"
  v4_cidr_blocks = ["192.168.21.0/24"]
 
}