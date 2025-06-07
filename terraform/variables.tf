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

variable "vpc_name" {
  type        = string
  default     = "vpc0"
  description = "VPC network"
}

variable "subnet-a" {
  type        = string
  default     = "subnet-a"
  description = "subnet name"
}

variable "subnet-b" {
  type        = string
  default     = "subnet-b"
  description = "subnet name"
}

variable "subnet-d" {
  type        = string
  default     = "subnet-d"
  description = "subnet name"
}

variable "zone-a" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "zone-b" {
  type        = string
  default     = "ru-central1-b"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "zone-d" {
  type        = string
  default     = "ru-central1-d"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "cidr-a" {
  type        = list(string)
  default     = ["192.168.1.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "cidr-b" {
  type        = list(string)
  default     = ["192.168.2.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "cidr-d" {
  type        = list(string)
  default     = ["192.168.3.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}


#Переменные для создания кластера 
variable "cluster" {
  type = map(object({  
    sa_name=string, 
    name_cluster = string,
    version_cluster=number, 
    platform_id=string, 
    default_region = string,
    public_ip = bool
    }))
  default = { 
    "var"= {
      sa_name="diplom-sa", 
      name_cluster = "k8s-cluster"
      version_cluster="1.31", 
      platform_id="standard-v2", 
      default_region = "ru-central1", 
      public_ip = true
    } ,
  }
}


#Переменные для создания Нод кластера 
variable "cluster_resource" {
  type = map(object({  
    name=string, 
    platform = string,
    cpu=number, 
    ram=number, 
    scale_policy = number,
    nat = bool,
    disk_type = string,
    disk_size = number,
    runtime = string
    }))
  default = { 
    "nodes"= {
      name="worker-nodes", 
      platform = "standard-v1"
      cpu=2, 
      ram=4, 
      scale_policy = 1, 
      nat = true,
      disk_type = "network-hdd" ,
      disk_size = 64,
      runtime = "containerd"
    } ,
  }
}


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
      protocol_any = "ANY",
      protocol_icmp = "ICMP",
      from_port = 6443,
      to_port= 443,
      from_nodeport = 0,
      to_nodeport = 0,
      v4_cidr_block_local = [""],
      v4_cidr_block_inet = ["0.0.0.0/0"]

    } ,
  }
}