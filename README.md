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

### 1. Подготовка облачной инфраструктуры на базе облачного провайдера Яндекс.Облако.
### 2. Запустить и сконфигурировать Kubernetes кластер.

Для создания инфрструктуры, буду использовать [Terraform](https://www.terraform.io/) как указано в задании. 

Буду использовать наработки, полученные во время обучения, изменяя и дополняя их. 

Организация хранения файлов стейтов будет построена с помощью s3 хранилища YC по примеру из [документации](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-state-storage?utm_referrer=https%3A%2F%2Fwww.google.com%2F)
https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-state-lock
Для создания кластера был выбран вариант использования сервиса Yandex Managed Service for Kubernetes.

Данный сервис не использовался в обучении, было принято решение его протестировать. 

Для будущей автоматизации и работы pipeline предварительно создадим  сервисный акаунт и статичный ключ доступа в формате JSON.
---
Боок для скринов создания SA и создание файла ключа
---
Для организации инфраструктуры, хранения файлов и кластера kubernetes необходимо создать базовые терраформ манифесты. 

---
Блок для добавления ссылок на манифесты. 
---

### 4. Создание тестового приложения

В качестве тестового приложения будем использовать образ https://hub.docker.com/r/yeasy/simple-web/
Возьмем исходники и соберем образ. 
![image](https://github.com/user-attachments/assets/d83dc4d4-9c72-402b-8d3a-7c5b0ba32853)
![image](https://github.com/user-attachments/assets/d0c9b2b4-05fd-4f23-ade0-068505990742)
![image](https://github.com/user-attachments/assets/726fecc5-496f-42e4-a8d0-92c3dcf3e786)
![image](https://github.com/user-attachments/assets/cc44a5cc-6a2e-447a-a49b-81287ccf0433)
![image](https://github.com/user-attachments/assets/cdffa6db-8862-4729-adf1-ba88c808007a)



### 4. Создание мониторинга

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm search repo prometheus-community
helm search repo prometheus-community/kube-prometheus-stack
helm search repo prometheus-community/kube-prometheus-stack --versions
helm install prometheus prometheus-community/kube-prometheus-stack --version 72.9.1 --namespace monitoring --create-namespace --set grafana.service.type=NodePort
  adminUser: admin
  adminPassword: prom-operator

![image](https://github.com/user-attachments/assets/2ddbbc0c-af4f-46b7-88bd-274af2ca8c3b)
![image](https://github.com/user-attachments/assets/e320714a-5123-45fd-9f74-1843da0ce18b)
![image](https://github.com/user-attachments/assets/0bf1961d-ac14-458c-ab6b-be8bfe9b73cb)


### 3. CI-CD 
https://docs.github.com/ru/actions/sharing-automations/creating-actions/creating-a-docker-container-action

---
Блок для добавления ссылок на манифесты. 
---

