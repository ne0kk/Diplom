# Дипломная работа профессии "DevOps-инженер"
## Даты обучения - 17 октября 2024 — 4 июня 2025
## Группа номер - SHDEVOPS-12
## [Дипломное задание](task.md)
----

## Цели:

1. Подготовить облачную инфраструктуру на базе облачного провайдера Яндекс.Облако.
2. Запустить и сконфигурировать Kubernetes кластер.
3. Установить и настроить систему мониторинга.
4. Настроить и автоматизировать сборку тестового приложения с использованием Docker-контейнеров.
5. Настроить CI для автоматической сборки и тестирования.
6. Настроить CD для автоматического развёртывания приложения.

 
Доступ к YC орагизован с локальной виртуальной машины с CentOS8 на борту. 


## 1. Подготовка облачной инфраструктуры на базе облачного провайдера Яндекс.Облако.
## 2. Запустить и сконфигурировать Kubernetes кластер.

Для создания инфраструктуры, буду использовать [Terraform](https://www.terraform.io/) как указано в задании. 

Буду использовать наработки, полученные во время обучения, изменяя и дополняя их. 

Организация хранения файлов стейтов будет построена с помощью s3 хранилища YC по примеру из [документации](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-state-storage?utm_referrer=https%3A%2F%2Fwww.google.com%2F)

Так же использованы рекомендации по организации хранения state файлов. 
https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-state-lock

Для создания кластера был выбран вариант использования сервиса Yandex Managed Service for Kubernetes.

Данный сервис не использовался в обучении, было принято решение протестировать решение. 

Для будущей автоматизации и работы pipeline предварительно создадим  сервисный акаунт и статичный ключ доступа в формате JSON.
Файл сохраним он понадобиться для организации доступа к нашему бакету. 

---
![image](https://github.com/user-attachments/assets/d989238d-4a2d-4f9b-89eb-5c22996a1cd7)
---
Для организации инфраструктуры, хранения файлов и кластера kubernetes необходимо создать базовые терраформ манифесты. 

Манифесты разделил на два отдельных каталога:

- предварительной подготовки с отдельным стейтом которая будет разворачиваться однократно и не будет участвовать в дальнейшей автоматизации 
- основной конфигурации кластера состояние которой и будем в дальнейшем отслеживать. 

---
## Манифесты предварительной подготовки. 

Для достижения цели нам понадобятся:
- Хранилище файлов типа S3, в которое Terraform будет сохранять состояние инфраструктуры
- Бессерверная БД типа DynamoDB, в которой Terraform будет фиксировать блокировки

К моменту выполнения terraform init основной конфигурации в проекте они уже должны существовать. 

То есть объекты для хранения remote backend создадим в другом проекте Terraform с локальным состоянием.

Они в дальнейшем почти никогда не меняются.

## Создание предварительной инфраструктуры 

Документные таблицы в YDB YandexCli создавать не умеет, поэтому таблицу будем создавать с помощью [AWS CLI](https://yandex.cloud/ru/docs/ydb/terraform/dynamodb-tables)

Предварительно настроим aws профиль 

Нам понадобится для этого данные нашего сервисного аккаунта и даные о регионе YC в котором мы работаем

```
key_id: YCAJEuQtO***
secret: YCOKV**********************
region: "ru-central1"

aws configure
```
### dynamo.tf

Данный манифест создает серверную базу данных в облаке, настраивает AWS провайдер и с его помощью создает документую таблцу lock и в ней колонку LockID.

В этой колонке будут храниться записи о блокировке состояния нашего state. 

```
resource "yandex_ydb_database_serverless" "db" {
  name                = var.ydb_database_name
  deletion_protection = var.deletion_protection_db
  folder_id           = var.folder_id
  location_id         = "${var.default_region}"

  serverless_database {
    enable_throttling_rcu_limit = "${var.enable_throttling_rcu_limit}"
    provisioned_rcu_limit       = "${var.provisioned_rcu_limit}"
    storage_size_limit          = "${var.storage_size_limit}"
    throttling_rcu_limit        = "${var.throttling_rcu_limit}"
  }
}

provider "aws" {
  region = "${var.default_region}"
  endpoints {
    dynamodb = "${yandex_ydb_database_serverless.db.document_api_endpoint}"
  }
  profile = "${var.profile}"
  skip_credentials_validation   = "${var.skip_credentials_validation}"
  skip_metadata_api_check       = "${var.skip_metadata_api_check}"
  skip_region_validation        = "${var.skip_region_validation}"
  skip_requesting_account_id    = "${var.skip_requesting_account_id}"
}

resource "aws_dynamodb_table" "lock" {
  name          = "${var.dynamodb_table_name}"
  billing_mode  = "${var.billing_mode}"
  hash_key      = "${var.hash_key}"
  attribute {
    name        = "${var.att_name}"
    type        = "${var.att_type}"
  }
}

```
### s3.tf

Манифест создает  bucket, в который Terraform будет сохранять состояние инфраструктуры

```
resource "yandex_storage_bucket" "state_storage" {
  bucket      = var.bucket_name
  folder_id   = var.folder_id
  anonymous_access_flags {
    read = var.anonymous_access_flags_read
    list = var.anonymous_access_flags_list
  }
}
```
### providers.tf

Информация о провайдерах

```
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = "~>1.9.8"
} 

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.default_zone
}
```
###  output.tf 

Вывод данных о базе данных dynamodb  в частности document_api_endpoint, нужен для backend подключения. 

```
output "yandex_ydb_database_serverless" {
  value = "${yandex_ydb_database_serverless.db.document_api_endpoint}"
}
```

###  variables.tf

Манифест с переменными

```
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
...
...
...
```
---
Выполним код и проверим создание наших объектов в облаке. 

Все объекты нашей инфраструктуры создались успешно. 

![image](https://github.com/user-attachments/assets/eb8fb0bd-036f-4d90-8f4b-78aeb498904f)

![image](https://github.com/user-attachments/assets/90f8acdc-0974-4ef0-9e3f-bac0ecdc3d92)

![image](https://github.com/user-attachments/assets/44841123-3aaf-4574-a55f-b531eebc8e49)


Из вывода outputs возьмем значение Document API эндпоинт, он пригодиться на следующем шаге. 

---
## Создание кластера Kubernetes

Как говорилось ранее, для создания кластера был выбран вариант использования сервиса Yandex Managed Service for Kubernetes.

Мне показалось интересным кейсом попробовать его в работе, тем более что гранта выданного в начале обучения осталось достаточно и можно так сказать на последок шикануть. 

По условию задания необходимо создать три ноды в разных зонах доступности.

Для этого создаем три подсети в разных зонах и собственно три ноды кластера в этих разных зонах. 

В создание кластера сервиса Yandex Managed Service for Kubernetes нет какой то сложности, информации достаточно много и документации.

Так же в данном блоке происходит создание backend для хранения state файла нашего terraform. 


###  k8s.tf 

Основной манифест создания кластера.

```
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


```
###  backend.tf  

В данном манифесте описано создание  backend для хранения state файла terraform.

Для выполнения локального подключения используется уже настроенный предварительно aws профиль. 

В данном блоке нет возможности использовать переменные.

Так же в данном блоке необходимо заменить аргумент dynamodb, но тот что мы получили в результате предыдущего шага. 

Из вывода outputs возьмем значение Document API эндпоинт. 

```
terraform {
  backend "s3" {
    endpoints = {
      s3 =       "https://storage.yandexcloud.net"
      dynamodb = "https://docapi.serverless.yandexcloud.net/ru-central1/b1gv3i9qq3bt8g400fs4/etn5imut4aqpig6ssvac"
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

```
###  network.tf  

Создание сети и подсетей в каждой зоне

```
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
```
###  providers.tf  

Указание провайдеров 
```
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = "~>1.9.8"
} 

provider "yandex" {
  token     = var.token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.default_zone
}
```
###  secure-group.tf  

Создание групп безопасности.


```
resource "yandex_vpc_security_group" "k8s-main-sg" {
  name        = "${var.security_group.main.name_sg}"
  description = "Правила группы обеспечивают базовую работоспособность кластера"
  network_id  = "${yandex_vpc_network.default.id}"
  ingress {
    protocol          = "${var.security_group.main.protocol_tcp}"
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера и сервисов балансировщика."
    predefined_target = "loadbalancer_healthchecks"
    from_port         = "${var.security_group.main.from_port}"
    to_port           = "${var.security_group.main.to_port}"
  }
  ingress {
    protocol          = "${var.security_group.main.protocol_any}"
    description       = "Правило разрешает взаимодействие мастер-узел и узел-узел внутри группы безопасности."
    predefined_target = "self_security_group"
    from_port         = "${var.security_group.main.from_port}"
    to_port           = "${var.security_group.main.to_port}"
  }
  ingress {
    protocol          = "${var.security_group.main.protocol_any}"
    description       = "Правило разрешает взаимодействие под-под и сервис-сервис. Указываем подсети нашего кластера и сервисов."
    v4_cidr_blocks    = concat("${yandex_vpc_subnet.public-a.v4_cidr_blocks}", "${yandex_vpc_subnet.public-b.v4_cidr_blocks}", "${yandex_vpc_subnet.public-d.v4_cidr_blocks}", )
    from_port         = "${var.security_group.main.from_port}"
    to_port           = "${var.security_group.main.to_port}"
  }
...
...
...
```
###  variables.tf

Манифест с переменными

```

#Переменные для создания групп безопасности
variable "security_group" {
  type = map(object({  
    name_sg=string,
    protocol_tcp=string,
    protocol_any=string,
    protocol_icmp=string,
    from_port=number,
    to_port=number,
    from_nodeport=number,
    to_nodeport=number,
    v4_cidr_block_local = list(string),
    v4_cidr_block_inet = list(string)
    
    }))
  default = { 
    "main" = {
      name_sg="k8s-main-sg", 
      protocol_tcp = "TCP",
      protocol_any = "ANY",
      protocol_icmp = "ICMP",
      from_port = 0,
      to_port= 65535,
      from_nodeport = 30000,
      to_nodeport = 32767,
      v4_cidr_block_local = ["172.16.0.0/12", "10.0.0.0/8", "192.168.0.0/16"],
      v4_cidr_block_inet = ["0.0.0.0/0"]


    } ,

    "public"= {
      name_sg="k8s-public-services", 
      protocol_tcp = "TCP",
      protocol_any = "ANY",
      protocol_icmp = "ICMP",
      from_port = 0,
      to_port= 0,
      from_nodeport = 30000,
      to_nodeport = 32767,
      v4_cidr_block_local = [""],
      v4_cidr_block_inet = ["0.0.0.0/0"]


    } ,

    "ssh"= {
      name_sg="k8s-nodes-ssh-access", 
      protocol_tcp = "TCP",
      protocol_any = "ANY",
      protocol_icmp = "ICMP",
      from_port = 22,
      to_port= 0,
      from_nodeport = 0,
      to_nodeport = 0,
      v4_cidr_block_local = [""],
      v4_cidr_block_inet = ["0.0.0.0/0"]


    } ,

    "whitelist"= {
      name_sg="k8s-master-whitelist", 
      protocol_tcp = "TCP",

...
...
...
```
---

Запускаем процесс создания нашего кластера.

Ппроцесс выполняется примерно минут 10.

![image](https://github.com/user-attachments/assets/c7cdc205-cfc0-4944-8102-ecd1a715604f)

Все наши ресурсы созданы. 

Выплним команду настраивающую kubectl

```
yc managed-kubernetes cluster    get-credentials k8s-cluster    --external --force
```
![image](https://github.com/user-attachments/assets/68773798-b475-4126-a270-d0e012016106)

Проверим статус объектов  нашего кластера

![image](https://github.com/user-attachments/assets/370015a4-d21e-41da-be06-44f95a6d344d)

## Наш кластер развернут и готов к работе!!!

---
### 3. Создание тестового приложения

В качестве тестового приложения будем использовать образ https://hub.docker.com/r/yeasy/simple-web/

Возьмем исходники и соберем образ. 

### Dockerfile  

```
FROM python:2.7
EXPOSE 80
WORKDIR /code
ADD . /code
RUN touch index.html
CMD python app/index.py
```
### index.py

```
#!/usr/bin/python
#authors: yeasy.github.com
#date: 2013-07-05
 
import sys
import BaseHTTPServer
from SimpleHTTPServer import SimpleHTTPRequestHandler
import socket
import fcntl
import struct
import pickle
from datetime import datetime
from collections import OrderedDict

class HandlerClass(SimpleHTTPRequestHandler):
    def get_ip_address(self,ifname):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        return socket.inet_ntoa(fcntl.ioctl(
            s.fileno(),
            0x8915,  # SIOCGIFADDR
            struct.pack('256s', ifname[:15])
        )[20:24])
    def log_message(self, format, *args):
        if len(args) < 3 or "200" not in args[1]:
            return
        try:
            request = pickle.load(open("pickle_data.txt","r"))
        except:
            request=OrderedDict()
        time_now = datetime.now()
        ts = time_now.strftime('%Y-%m-%d %H:%M:%S')
        server = self.get_ip_address('eth0')
        host=self.address_string()
        addr_pair = (host,server)
        if addr_pair not in request:
            request[addr_pair]=[1,ts]
        else:
            num = request[addr_pair][0]+1
            del request[addr_pair]
            request[addr_pair]=[num,ts]
        file=open("index.html", "w")
        file.write("<!DOCTYPE html> <html> <body><center><h1><font color=\"blue\" face=\"Georgia, Arial\" size=8><em>Real</em></font> Visit Results</h1></center>");
        for pair in request:
            if pair[0] == host:
                guest = "LOCAL: "+pair[0]
            else:
                guest = pair[0]
            if (time_now-datetime.strptime(request[pair][1],'%Y-%m-%d %H:%M:%S')).seconds < 3:
                file.write("<p style=\"font-size:150%\" >#"+ str(request[pair][1]) +": <font color=\"red\">"+str(request[pair][0])+ "</font> requests " + "from &lt<font color=\"blue\">"+guest+"</font>&gt to WebServer &lt<font color=\"blue\">"+pair[1]+"</font>&gt</p>")
            else:
                file.write("<p style=\"font-size:150%\" >#"+ str(request[pair][1]) +": <font color=\"maroon\">"+str(request[pair][0])+ "</font> requests " + "from &lt<font color=\"navy\">"+guest+"</font>&gt to WebServer &lt<font color=\"navy\">"+pair[1]+"</font>&gt</p>")
        file.write("</body> </html>");
        file.close()
        pickle.dump(request,open("pickle_data.txt","w"))

if __name__ == '__main__':
    try:
        ServerClass  = BaseHTTPServer.HTTPServer
        Protocol     = "HTTP/1.0"
        addr = len(sys.argv) < 2 and "0.0.0.0" or sys.argv[1]
        port = len(sys.argv) < 3 and 80 or int(sys.argv[2])
        HandlerClass.protocol_version = Protocol
        httpd = ServerClass((addr, port), HandlerClass)
        sa = httpd.socket.getsockname()
        print "Serving HTTP on", sa[0], "port", sa[1], "..."
        httpd.serve_forever()
    except:
        exit()

```

![image](https://github.com/user-attachments/assets/d83dc4d4-9c72-402b-8d3a-7c5b0ba32853)
![image](https://github.com/user-attachments/assets/d0c9b2b4-05fd-4f23-ade0-068505990742)
![image](https://github.com/user-attachments/assets/726fecc5-496f-42e4-a8d0-92c3dcf3e786)
![image](https://github.com/user-attachments/assets/cc44a5cc-6a2e-447a-a49b-81287ccf0433)

Наш образ собран запушен в DockerHUB и готов к работе. 

Теперь создадим необходимые манифесты для деплоя в кубер

### APP-DaemonSet.yml

```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: simple-deamonset
  namespace: app
spec:
  selector:
    matchLabels:
      app: daemonset
  template:
    metadata:
      labels:
        app: daemonset
    spec:
      containers:
      - name: simple-web
        image: ne0kk/simple-web:latest
```
### APP-service.yml
Для простоты выбрал вариант с NodePort.
В целом вариант с ингресс контроллером и балансировщиком нагрузки разбирали на обучении, но время поджимает. 

```
apiVersion: v1
kind: Service
metadata:
  name: simple-service
  namespace: app
spec:
  ports:
    - name: simple
      port: 80
      protocol: TCP
      targetPort: 80
      nodePort: 30080
  selector:
    app: daemonset
  type: NodePort
```

Выполним наши манифесты и проверим работоспособность приложения. 

![image](https://github.com/user-attachments/assets/1c9287d3-4c92-41f5-8c62-a157ae5e71bb)

![image](https://github.com/user-attachments/assets/49c03e13-ff4c-446e-b9db-04f550a387b5)

![image](https://github.com/user-attachments/assets/33db0573-7953-4e41-8aba-2a0831c22d4a)

## Наше приложение в кубере и оно работает. 
---
### 4. Создание мониторинга

Для создания мониторинга выбал установку с помощью helm чарта. 

Для Grafana так же будем использовать NodePort

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm search repo prometheus-community
helm search repo prometheus-community/kube-prometheus-stack
helm search repo prometheus-community/kube-prometheus-stack --versions
helm install prometheus prometheus-community/kube-prometheus-stack --version 72.9.1 --namespace monitoring --create-namespace --set grafana.service.type=NodePort
```

![image](https://github.com/user-attachments/assets/1d09aebc-ddf1-4434-a82d-536cb3e95c05)

![image](https://github.com/user-attachments/assets/3ae9885b-61dc-43ec-8a4b-cc4f6c2229ee)

![image](https://github.com/user-attachments/assets/1dfb6332-57e0-45d2-8a26-24f4d8448d4f)

## Наш мониторинг в кубере и он работает. 
---
### 5. CI-CD 

Вишенкой на торте нашего проекта, является задания настройки автоматизации CI и CD наших инфраструктуры и приложения. 

В качестве сервиса CI-CD я выбрал [Github-actions](https://docs.github.com/ru/actions/about-github-actions/understanding-github-actions).

Абсолютно все задачи CI-CD я решил выполнить с его помощью, мне показалось, что это будет более лаконично. 

Хранение репозиториев, контроль версий, CI и CD, все в одном месте. 

Для организации подобных задач в первую очередь не обходимо настроить secret-action для доступа ко всем используемым нами сервисам. 

Создадим в нашем репозитории каталог .github/workflows

В нем хранятся все workflows манифесты, описанные на языке yaml.

Создадим наш первый workflows, который будет нам собирать наше приложение и пушить его в docker hub.


### action-build.ym

Данный workflows сработает при puch в ветку dev в каталог app/
```
name: Build Docker Image CI
on:
  push:
    branches:
      - dev
    paths:
      - 'app/**'
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Check
        uses: actions/checkout@v4

      - name: Docker Hub enter
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.USER_DOCKER_HUB }}
          password: ${{ secrets.TOKEN_DOCKER_HUB }}
      - name: Build Docker Hub Registry
        env:
           IMAGE_TAG: ${{ github.ref_type == 'tag' && github.ref_name || 'latest' }}
        run: |
          docker build . --file app/Dockerfile --tag simple-web:$IMAGE_TAG
          docker tag simple-web:$IMAGE_TAG ${{ secrets.USER_DOCKER_HUB }}/simple-web:$IMAGE_TAG
          docker push ${{ secrets.USER_DOCKER_HUB }}/simple-web:$IMAGE_TAG
```

В данном манифесте мы видем переменные которые необходимы для подключения к docker hub:
- USER_DOCKER_HUB - имя пользователя
- TOKEN_DOCKER_HUB - [токен доступа](https://app.docker.com/settings/personal-access-tokens)

Перейдем на вкладку с secret в нашем репозитории в создадим ненужные secret-action.

![image](https://github.com/user-attachments/assets/f7731395-b9c0-46ea-ba81-3b1ccfc1d49a)

Secret-action созданы.

Попробуем запушить наш workflows и выполнить условия для сработки тригерра. 

Создадим ветку dev и запушем наш workflows
```
git push --set-upstream origin dev
git add action-build.yml
git commit -m "add action build"
git push
```
![image](https://github.com/user-attachments/assets/fc7e8c06-5925-4395-9e6a-7ff12c7ee559)

Выполним изменения в нашей папке app/ и проверим работы сборки и отправки нашего приложения. 

В файле index.py изменим название шапки сайта с  REAL на NEREAL.

![image](https://github.com/user-attachments/assets/275d9345-9a3b-4b0d-8699-c6fee06a3c70)

![image](https://github.com/user-attachments/assets/3942bf63-cafe-4adf-9daf-e01abca27724)

Проверим наш workflows.
![image](https://github.com/user-attachments/assets/3cd9a9ae-4994-4982-a6e5-1aa942e94e9c)

![image](https://github.com/user-attachments/assets/9ce2e77b-3e97-4e4e-89f5-13726d53234d)

![image](https://github.com/user-attachments/assets/b201d4dc-84a2-435c-8d5e-91b2bf67adee)

Все выполнилось успешно.

Проверим новый образ, выполним и проверим наше приложение в кластере. 
```
kubectl delete -f APP-DaemonSet.yml -f APP-service.yml
kubectl apply -f APP-DaemonSet.yml -f APP-service.yml

```
![image](https://github.com/user-attachments/assets/0da03f0c-be14-4611-ac88-1a3e916f8885)

Наше приложение обновилось

## Доставка приложения до регистри выполнена успешно
---

Теперь настроим workflow который будет пересоздавать наше приложение в кластере.

Данный манифест выполнит пересоздание подов когда запушат изменения в main ветку в каталог app

### action-deploy.ym
```
name: Deploy to YC Kubernetes
on:
  push:
    branches:
      - main
    paths:
      - 'app/**'
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      #1: Clone repo
      - name: Checkout code
        uses: actions/checkout@v4
      #2: Install Yandex CLI
      - name: Install Yandex Cloud CLI
        run: |
          curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
          echo "${HOME}/yandex-cloud/bin" >> $GITHUB_PATH

      #3: Enter в Yandex Cloud
      - name: Authenticate in Yandex Cloud
        env:
          YC_SERVICE_ACCOUNT_KEY: ${{ secrets.YC_SERVICE_ACCOUNT_KEY }}
          YC_CLOUD_ID: ${{ secrets.YC_CLOUD_ID }}
          YC_FOLDER_ID: ${{ secrets.YC_FOLDER_ID }}
        run: |
          echo "${YC_SERVICE_ACCOUNT_KEY}" > yc-sa-key.json
          yc config set service-account-key yc-sa-key.json
          yc config set cloud-id "${YC_CLOUD_ID}"
          yc config set folder-id "${YC_FOLDER_ID}"

      #4: Install kubectl
      - name: Install kubectl
        run: |
          sudo apt-get update
          sudo apt-get install -y kubectl

      #5:  Connect Kubernetes
      - name: Configure kubectl
        env:
          YC_SERVICE_ACCOUNT_KEY: ${{ secrets.YC_SERVICE_ACCOUNT_KEY }}
          YC_CLUSTER_NAME: ${{ secrets.YC_CLUSTER_NAME }}
        run: |
          yc managed-kubernetes cluster get-credentials --name "${YC_CLUSTER_NAME}" --external
          kubectl get nodes

      # Шаг 6: Deploy APP
      - name: Deploy to Kubernetes
        env:
           IMAGE_TAG: ${{ github.ref_type == 'tag' && github.ref_name || 'latest' }}
        run: |
          kubectl config view
          kubectl get nodes
          kubectl get pods --all-namespaces
          kubectl delete -f app/kube_deploy/APP-DaemonSet.yml -f app/kube_deploy/APP-service.yml
          kubectl apply -f app/kube_deploy/APP-DaemonSet.yml -f app/kube_deploy/APP-service.yml
        # kubectl create deployment nginx --image=${{ secrets.USER_DOCKER_HUB }}/nginx:$IMAGE_TAG

```
В данном манифесте мы видем переменные которые необходимы для deploy:
- YC_CLUSTER_NAME - имя кластера
- YC_CLOUD_ID - ID Облака YC
- YC_FOLDER_ID - ID рабочего каталога YC
- YC_SERVICE_ACCOUNT_KEY -данные из файла с авторизованным ключем который мы сохраняли в самом начале при создании сервисного аккаунта. 

Заполним secret-action в Git
![image](https://github.com/user-attachments/assets/29ed7719-205c-40d3-a4e2-d3a566529e3d)

Добавим наш workflow к проекту и запушим изменение в main ветку. 

Для наглядности изменим в шапке нашего сайта NEREAL на DEPLOY_V_KUBER

Мы внесли изменения в файлах приложения и за пушили их в dev ветку, у нас выполнился workflow сборки и доставки в репозиторий.

![image](https://github.com/user-attachments/assets/0869ddde-e53b-4051-a5ae-f2f2fa2a9a55)

Теперь накатим изменения в main ветку и проверим как отработает наш новый workflow.

![image](https://github.com/user-attachments/assets/2ce85e01-c941-4b57-bc54-4699cc5aee7d)

![image](https://github.com/user-attachments/assets/14637750-5620-42c2-b56b-45add1c9ca36)

Поды обновились

![image](https://github.com/user-attachments/assets/2ec5958d-7ae5-4e37-aced-8776710ccb08)

В шапке изменения видим.

![image](https://github.com/user-attachments/assets/c670ab4f-8dda-42f2-abfc-f2b5ea0e2497)

## Доставка приложения в кубер выполнена успешно

---

И последняя задача, это отслеживание изменения инфраструктуры и автоматический aplly при изменении.
Так же создадим workflow.

### action-terraform.yaml 

Данный workflow выполняет terraform plan при пуше в ветку dev и terraform apply при пуше в main ветку. 


```
name: "Terraform CI/CD Backend"
on:
  push:
    branches:
      - main
      - dev
    paths:
      - 'terraform/**'
jobs:
  terraform:
    name: "Terraform"
    runs-on: ubuntu-latest
    env:
      working-directory: terraform
      backend-access-key-id: ${{ secrets.BACKEND_ACCESS_KEY_ID }}
      backend-secret-access-key: ${{ secrets.BACKEND_SECRET_ACCESS_KEY }}
      backend-region: ${{ secrets.BACKEND_REGION }}
      backend-BUCKET: ${{ secrets.BACKEND_BUCKET }}
      backend-KEY: ${{ secrets.BACKEND_KEY }}
      backend-DYNAMODB-TABLE: ${{ secrets.BACKEND_DYNAMODB_TABLE }}
    defaults:
      run:
        working-directory: ${{ env.working-directory }}
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v1
        with:
          terraform_version: 1.9.8
      - name: Terraform Init
        id: init
        run: terraform init -backend-config=bucket=${{ env.backend-BUCKET }} -backend-config=key=${{ env.backend-KEY }} -backend-config=access_key=${{ env.backend-access-key-id }} -backend-config=secret_key=${{ env.backend-secret-access-key }} -backend-config=dynamodb_table=${{ env.backend-DYNAMODB-TABLE }} 
      - name: Terraform Validate
        id: validate
        run: terraform validate -no-color
      - name: Terraform Plan
        id: plan
        if: github.ref == 'refs/heads/dev' && github.event_name == 'push'
        run: terraform plan -no-color -var="folder_id="${{ secrets.YC_FOLDER_ID }}"" -var="cloud_id="${{ secrets.YC_CLOUD_ID }}"" -var="token="${{ secrets.YC_TOKEN }}""
        continue-on-error: true
      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve -var="folder_id="${{ secrets.YC_FOLDER_ID }}"" -var="cloud_id="${{ secrets.YC_CLOUD_ID }}"" -var="token="${{ secrets.YC_TOKEN }}""
```
Для корректного выполнения подключения к нашему backend state файлу, буду использовать опять же secret-action и ключи при выполнении команд. 

Напомню что в блоке backend переменные использовать нельзя. 

Дополним наши secret-action:
- BACKEND_ACCESS_KEY_ID - KEY ID статического ключа нашего сервисного аккаунта
- BACKEND_SECRET_ACCESS_KEY - секретный ключ нашего сервисного аккаунта
- BACKEND_REGION - регион 
- BACKEND_BUCKET - имя бакета
- BACKEND_KEY - ключ файла хранения state файла
- BACKEND_DYNAMODB_TABLE - имя блокировочной таблицы

![image](https://github.com/user-attachments/assets/3d762a5e-906e-41a8-a653-cd5323750590)

Теперь добавим наш workflow в проект и выполним пуш изменения в инфраструктуру, например добавим подсеть. 

![image](https://github.com/user-attachments/assets/540cc67d-87eb-4218-9592-8aa9c03631c6)


![image](https://github.com/user-attachments/assets/91ed8370-f344-4de4-8b34-8244152badeb)

Видим, что отработал наш workflow при добавлении в dev ветку, отработал именно plan. Проверим что там запланировано. 

![image](https://github.com/user-attachments/assets/d6fa62eb-2cb3-4238-8b29-28a563506c86)

![image](https://github.com/user-attachments/assets/f79dde18-7216-40a2-8e28-b75ab7ea096c)

Видим что действительно планируется создание подсети. 

Выполним пуш в ветку main из dev

Видим наши изменения, и отправляем их  в main

![image](https://github.com/user-attachments/assets/2930ac45-d694-4e02-9630-48976ec4da95)

Наш workflow выполнился. 
![image](https://github.com/user-attachments/assets/6f15c882-8002-4e40-8396-37b08cff3fc0)
![image](https://github.com/user-attachments/assets/7a1a614e-2efe-4284-87cf-9f10d1f8e573)
![image](https://github.com/user-attachments/assets/db47b4ee-7e81-4a9e-b8cc-f12d603a28ae)

## Код выполняется, требования контролю изменения и хранения стейт файла выполнены.

---
## Заключение
Пройдемся по chek листу готовности проекта
1. Репозиторий с конфигурационными файлами Terraform и готовность продемонстрировать создание всех ресурсов с нуля.
 - https://github.com/ne0kk/Diplom
2. Пример pull request с комментариями созданными atlantis'ом или снимки экрана из Terraform Cloud или вашего CI-CD-terraform pipeline.
 - https://github.com/ne0kk/Diplom/blob/main/README.md
3. Репозиторий с конфигурацией ansible, если был выбран способ создания Kubernetes кластера при помощи ansible.
 - Выбран способ без участия ansible
4. Репозиторий с Dockerfile тестового приложения и ссылка на собранный docker image.
 - https://hub.docker.com/repository/docker/ne0kk/simple-web/general
5. Репозиторий с конфигурацией Kubernetes кластера.
 - https://github.com/ne0kk/Diplom/tree/main/terraform
6. Ссылка на тестовое приложение и веб интерфейс Grafana с данными доступа.
 - В связи с дороговизной моего решения, все ресурсы уничтожу.
 - Готов для проверки все запустить заново по требованию и предоставить ссылки. 
8. Все репозитории рекомендуется хранить на одном ресурсе (github, gitlab)
 - Все файлы хранятся в одном репозитории.  

---
# Дополнения
Получил замечаний от своего проверяющего преподователя. 

### Основные замечания 
```
В целом, у вас получилась хорошая работа. Для доработки я бы отметил только два момента:

используйте Deployment вместо Daemonset, так как это будет правильное использование правильного инструмента
настройте пайплан на запуск по событию создания git-тега, сборку образа с тегом, равным этому git-тегу, push с этим тегом и деплой именно с ним, а не с latest (для простоты можно просто поправить YAML-файл sedом или envsubst)

```

Внесем изменеия в наши манифесты. 
Создадим Deployment вместо ранее используемого DemonSet

### APP-Deployment.yml
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-deploynent
  namespace: app
spec: 
 selector:
  matchLabels:
   app: front
 replicas: 3
 strategy:
  type: RollingUpdate
  rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
 template :
  metadata:
   labels:
    app: front
  spec:
   containers:
    - name: simple-web
      image: ne0kk/simple-web:v1.9.10
      ports:
      - containerPort: 80
        name: simple-port

---

apiVersion: v1
kind: Service
metadata:
  name: simple-service
  namespace: app
spec:
  ports:
    - name: simple-port
      port: 80
      protocol: TCP
      targetPort: 80
      nodePort: 30080
  selector:
    app: front
  type: NodePort
```
Уберем из кода terraform излишнюю интерполяцию

```
список манифестов
```

Внесем изменения в сборку нашегго образа, вынесем наше приложение в отдельную папку, для исключения при сборки не нужных нам файлов. 
Добавим папку source и перенесем в нее наш Dockerfile и index.py
```
FROM python:2.7
EXPOSE 80
WORKDIR /code
ADD app/source/. /code
RUN touch index.html
CMD python index.py

```

Изменим наши workflow action для корректного выполнения задания, в котором указано сбора и деплой при пуше тега.
Объеденим два наших workflow action в один. 
Логика сработки простая но в целом удовлетворяет заданию:
при пуше тега в любую ветку, сначала произойдет сборка приложения и пуш его в DockerHub, если сборка прошщла корректно, то седуюший шаг задеплоит его в наш кубер. 

### action-build_and_deploy.yml

```
name: Build Docker Image CI

on:
  push:
    # branches:
    #   - dev
    # paths:
    #   - 'app/source/**'
    tags:
      - v*

jobs:
  build:

    runs-on: ubuntu-latest

    steps:
      - name: Check
        uses: actions/checkout@v4

      - name: Docker Hub enter
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.USER_DOCKER_HUB }}
          password: ${{ secrets.TOKEN_DOCKER_HUB }}
      - name: Build Docker Hub Registry
        env:
           IMAGE_TAG: ${{ github.ref_type == 'tag' && github.ref_name || 'latest' }}
        run: |
          echo ${{ secrets.USER_DOCKER_HUB }}/simple-web:$IMAGE_TAG
          docker build . --file ./app/source/Dockerfile --tag simple-web:$IMAGE_TAG
          docker tag simple-web:$IMAGE_TAG ${{ secrets.USER_DOCKER_HUB }}/simple-web:$IMAGE_TAG
          docker push ${{ secrets.USER_DOCKER_HUB }}/simple-web:$IMAGE_TAG


  deploy:
    needs: [build]
    runs-on: ubuntu-latest

    steps:
      #1: Clone repo
      - name: Checkout code
        uses: actions/checkout@v4

      #2: Install Yandex CLI
      - name: Install Yandex Cloud CLI
        run: |
          curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
          echo "${HOME}/yandex-cloud/bin" >> $GITHUB_PATH

      #3: Enter в Yandex Cloud
      - name: Authenticate in Yandex Cloud
        env:
          YC_SERVICE_ACCOUNT_KEY: ${{ secrets.YC_SERVICE_ACCOUNT_KEY }}
          YC_CLOUD_ID: ${{ secrets.YC_CLOUD_ID }}
          YC_FOLDER_ID: ${{ secrets.YC_FOLDER_ID }}
        run: |
          echo "${YC_SERVICE_ACCOUNT_KEY}" > yc-sa-key.json
          yc config set service-account-key yc-sa-key.json
          yc config set cloud-id "${YC_CLOUD_ID}"
          yc config set folder-id "${YC_FOLDER_ID}"

      #4: Install kubectl
      - name: Install kubectl
        run: |
          sudo apt-get update
          sudo apt-get install -y kubectl

      #5:  Connect Kubernetes
      - name: Configure kubectl
        env:
          YC_SERVICE_ACCOUNT_KEY: ${{ secrets.YC_SERVICE_ACCOUNT_KEY }}
          YC_CLUSTER_NAME: ${{ secrets.YC_CLUSTER_NAME }}
        run: |
          yc managed-kubernetes cluster get-credentials --name "${YC_CLUSTER_NAME}" --external
          kubectl get nodes

      # Шаг 6: Deploy APP
      - name: Deploy to Kubernetes
        env:
           IMAGE_TAG: ${{ github.ref_type == 'tag' && github.ref_name || 'latest' }}
        run: |
          echo ${{ env.IMAGE_TAG }}
          echo env.IMAGE_TAG
          echo $IMAGE_TAG

          kubectl config view
          kubectl get nodes
          kubectl get pods --all-namespaces
          kubectl set image deployment/simple-deploynent simple-web=${{ secrets.USER_DOCKER_HUB }}/simple-web:$IMAGE_TAG -n app
          kubectl rollout status deployment/simple-deploynent -n app
          kubectl get pods --all-namespaces
        #  kubectl delete -f app/kube_deploy/APP-DaemonSet.yml -f app/kube_deploy/APP-service.yml
        #  kubectl apply -f app/kube_deploy/APP-DaemonSet.yml -f app/kube_deploy/APP-service.yml
        # kubectl create deployment nginx --image=${{ secrets.USER_DOCKER_HUB }}/simple-web:$IMAGE_TAG
        # kubectl set image deployment/simple-deploynent simple-web=ne0kk/simple-web:latest -n app
        # kubectl rollout status deployment/simple-deploynent -n app


```

Попробуем все запустить и проверить работу всех компонентов нашего проекта. 

Наша инфраструктура стартовала без ошибок. 

![image](https://github.com/user-attachments/assets/af711f80-7f67-4359-8cd4-67919289a763)

Стартанем приложение и мониторинг. 

![image](https://github.com/user-attachments/assets/1666d700-2902-47b2-890b-670c592aba41)

Наше приложение 

![image](https://github.com/user-attachments/assets/fb74347e-9caa-4abc-9910-4e12794756b5)

Наш мониторинг

![image](https://github.com/user-attachments/assets/7450bae2-a9f8-4516-907d-715bb51150c0)


Проверим работу нашего workflow, добавив в название нашего приложения - TAG и запушим тег 'v2.2' в репозиторий.

![image](https://github.com/user-attachments/assets/e6a8dc4e-2f8b-4eff-b0fd-dc9647b65bdf)

![image](https://github.com/user-attachments/assets/16bdb5b9-b57b-4dba-83a5-fe9f1e586a1a)

![image](https://github.com/user-attachments/assets/837f6294-781a-43e8-bd2b-000b0fb46a15)

![image](https://github.com/user-attachments/assets/fefbb609-73da-4539-a9d7-34b3bffffe9f)

![image](https://github.com/user-attachments/assets/cff687d6-9791-491d-940b-c56ee200257c)

Получили ожидаемый результат:
- Наше приложение билдится и деплоится по push тега.
- сам проект исползует деплойменты для обновления образа.







