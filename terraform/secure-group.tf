resource "yandex_vpc_security_group" "k8s-main-sg" {
  name        = var.security_group.main.name_sg
  description = "Правила группы обеспечивают базовую работоспособность кластера"
  network_id  = "${yandex_vpc_network.default.id}"
  ingress {
    protocol          = var.security_group.main.protocol_tcp
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера и сервисов балансировщика."
    predefined_target = "loadbalancer_healthchecks"
    from_port         = var.security_group.main.from_port
    to_port           = var.security_group.main.to_port
  }
  ingress {
    protocol          = var.security_group.main.protocol_any
    description       = "Правило разрешает взаимодействие мастер-узел и узел-узел внутри группы безопасности."
    predefined_target = "self_security_group"
    from_port         = var.security_group.main.from_port
    to_port           = var.security_group.main.to_port
  }
  ingress {
    protocol          = var.security_group.main.protocol_any
    description       = "Правило разрешает взаимодействие под-под и сервис-сервис. Указываем подсети нашего кластера и сервисов."
    v4_cidr_blocks    = concat(yandex_vpc_subnet.public-a.v4_cidr_blocks, yandex_vpc_subnet.public-b.v4_cidr_blocks, yandex_vpc_subnet.public-d.v4_cidr_blocks, )
    from_port         = var.security_group.main.from_port
    to_port           = var.security_group.main.to_port
  }
  ingress {
    protocol          = var.security_group.main.protocol_icmp
    description       = "Правило разрешает отладочные ICMP-пакеты из внутренних подсетей."
    v4_cidr_blocks    = var.security_group.main.v4_cidr_block_local
  }
  ingress {
    protocol          = var.security_group.main.protocol_tcp
    description       = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort. Добавляем или изменяем порты на нужные нам."
    v4_cidr_blocks    = var.security_group.main.v4_cidr_block_inet
    from_port         = var.security_group.main.from_nodeport
    to_port           = var.security_group.main.to_nodeport
  }

  egress {
    protocol          = var.security_group.main.protocol_any
    description       = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Object Storage, Docker Hub и т.д."
    v4_cidr_blocks    = var.security_group.main.v4_cidr_block_inet
    from_port         = var.security_group.main.from_port
    to_port           = var.security_group.main.to_port
  }
}

resource "yandex_vpc_security_group" "k8s-public-services" {
  name        = var.security_group.public.name_sg
  description = "Правила группы разрешают подключение к сервисам из интернета. Применяем правила только для групп узлов."
  network_id  = "${yandex_vpc_network.default.id}"

  ingress {
    protocol       = var.security_group.public.protocol_tcp
    description    = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort. Добавляем или изменяем порты на нужные нам."
    v4_cidr_blocks = var.security_group.public.v4_cidr_block_inet
    from_port         = var.security_group.public.from_nodeport
    to_port           = var.security_group.public.to_nodeport
    
  }
}

resource "yandex_vpc_security_group" "k8s-nodes-ssh-access" {
  name        = var.security_group.ssh.name_sg
  description = "Правила группы разрешают подключение к узлам кластера по SSH. Применяем правила только для групп узлов."
  network_id  = "${yandex_vpc_network.default.id}"

  ingress {
    protocol       = var.security_group.ssh.protocol_tcp
    description    = "Правило разрешает подключение к узлам по SSH с указанных IP-адресов."
    v4_cidr_blocks = var.security_group.ssh.v4_cidr_block_inet
    port           = var.security_group.ssh.from_port
  }
}

resource "yandex_vpc_security_group" "k8s-master-whitelist" {
  name        = var.security_group.whitelist.name_sg
  description = "Правила группы разрешают доступ к API Kubernetes из интернета. Применяем правила только к кластеру."
  network_id  = "${yandex_vpc_network.default.id}"

  ingress {
    protocol       = var.security_group.whitelist.protocol_tcp
    description    = "Правило разрешает подключение к API Kubernetes через порт 6443 из указанной сети."
    v4_cidr_blocks = var.security_group.whitelist.v4_cidr_block_inet
    port           = var.security_group.whitelist.from_port
  }

  ingress {
    protocol       = var.security_group.whitelist.protocol_tcp
    description    = "Правило разрешает подключение к API Kubernetes через порт 443 из указанной сети."
    v4_cidr_blocks = var.security_group.whitelist.v4_cidr_block_inet
    port           = var.security_group.whitelist.to_port
  }
}