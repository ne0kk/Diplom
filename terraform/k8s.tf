data "yandex_iam_service_account" "sa" {
  name = "${var.cluster.var.sa_name}"
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  name = "${var.cluster.var.name_cluster}"
  network_id = "${yandex_vpc_network.default.id}"

  master {
    regional {
      region = "${var.cluster.var.default_region}"

      location {
        zone      = "${yandex_vpc_subnet.public-a.zone}"
        subnet_id = "${yandex_vpc_subnet.public-a.id}"
      }

      location {
        zone      = "${yandex_vpc_subnet.public-b.zone}"
        subnet_id = "${yandex_vpc_subnet.public-b.id}"
      }

      location {
        zone      = "${yandex_vpc_subnet.public-d.zone}"
        subnet_id = "${yandex_vpc_subnet.public-d.id}"
      }
    }

    security_group_ids = ["${yandex_vpc_security_group.k8s-main-sg.id}",
                          "${yandex_vpc_security_group.k8s-master-whitelist.id}"
    ]

    version   = "${var.cluster.var.version_cluster}"
    public_ip = "${var.cluster.var.public_ip}"

 
  }

  service_account_id      = data.yandex_iam_service_account.sa.id
  node_service_account_id = data.yandex_iam_service_account.sa.id
}



# Create worker-nodes-a

resource "yandex_kubernetes_node_group" "worker-nodes-a" {
  cluster_id = "${yandex_kubernetes_cluster.k8s-cluster.id}"
  name       = "${var.cluster_resource.nodes.name}-a"
  version    = "${var.cluster.var.version_cluster}"
  instance_template {
    platform_id = "${var.cluster.var.platform_id}"

    network_interface {
      nat                = "${var.cluster_resource.nodes.nat}"
      subnet_ids         = ["${yandex_vpc_subnet.public-a.id}"]
      security_group_ids = [
        "${yandex_vpc_security_group.k8s-main-sg.id}",
        "${yandex_vpc_security_group.k8s-nodes-ssh-access.id}",
        "${yandex_vpc_security_group.k8s-public-services.id}"
      ]
    }

    resources {
      memory = "${var.cluster_resource.nodes.ram}"
      cores  = "${var.cluster_resource.nodes.cpu}"
    }

    boot_disk {
      type = "${var.cluster_resource.nodes.disk_type}"
      size = "${var.cluster_resource.nodes.disk_size}"
    }

    container_runtime {
      type = "${var.cluster_resource.nodes.runtime}"
    }
  }

  scale_policy {
    fixed_scale {
      size = "${var.cluster_resource.nodes.scale_policy}"
  }
  }

  allocation_policy {
    location {
      zone = "${yandex_vpc_subnet.public-a.zone}"
    }
  }
}


# Create worker-nodes-b
resource "yandex_kubernetes_node_group" "worker-nodes-b" {
  cluster_id = "${yandex_kubernetes_cluster.k8s-cluster.id}"
  name       = "${var.cluster_resource.nodes.name}-b"
  version    = "${var.cluster.var.version_cluster}"
  instance_template {
    platform_id = "${var.cluster.var.platform_id}"

    network_interface {
      nat                = "${var.cluster_resource.nodes.nat}"
      subnet_ids         = ["${yandex_vpc_subnet.public-b.id}"]
      security_group_ids = [
        "${yandex_vpc_security_group.k8s-main-sg.id}",
        "${yandex_vpc_security_group.k8s-nodes-ssh-access.id}",
        "${yandex_vpc_security_group.k8s-public-services.id}"
      ]
    }

    resources {
      memory = "${var.cluster_resource.nodes.ram}"
      cores  = "${var.cluster_resource.nodes.cpu}"
    }

    boot_disk {
      type = "${var.cluster_resource.nodes.disk_type}"
      size = "${var.cluster_resource.nodes.disk_size}"
    }

    container_runtime {
      type = "${var.cluster_resource.nodes.runtime}"
    }
  }

  scale_policy {
    fixed_scale {
      size = "${var.cluster_resource.nodes.scale_policy}"
  }
  }

  allocation_policy {
    location {
      zone = "${yandex_vpc_subnet.public-b.zone}"
    }
  }
}

# Create worker-nodes-d
resource "yandex_kubernetes_node_group" "worker-nodes-d" {
  cluster_id = "${yandex_kubernetes_cluster.k8s-cluster.id}"
  name       = "${var.cluster_resource.nodes.name}-d"
  version    = "${var.cluster.var.version_cluster}"
  instance_template {
    platform_id = "${var.cluster.var.platform_id}"

    network_interface {
      nat                = "${var.cluster_resource.nodes.nat}"
      subnet_ids         = ["${yandex_vpc_subnet.public-d.id}"]
      security_group_ids = [
        "${yandex_vpc_security_group.k8s-main-sg.id}",
        "${yandex_vpc_security_group.k8s-nodes-ssh-access.id}",
        "${yandex_vpc_security_group.k8s-public-services.id}"
      ]
    }

    resources {
      memory = "${var.cluster_resource.nodes.ram}"
      cores  = "${var.cluster_resource.nodes.cpu}"
    }

    boot_disk {
      type = "${var.cluster_resource.nodes.disk_type}"
      size = "${var.cluster_resource.nodes.disk_size}"
    }

    container_runtime {
      type = "${var.cluster_resource.nodes.runtime}"
    }
  }

  scale_policy {
    fixed_scale {
      size = "${var.cluster_resource.nodes.scale_policy}"
  }
  }

  allocation_policy {
    location {
      zone = "${yandex_vpc_subnet.public-d.zone}"
    }
  }
}

