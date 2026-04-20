# 1. Считываем данные об образе ОС (Ubuntu 22.04)
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

# 2. BASTION HOST (Публичная подсеть)
resource "yandex_compute_instance" "bastion" {
  name        = "bastion"
  hostname    = "bastion"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_a.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
  }

  metadata = {
    user-data = file("./cloud-init.yml")
  }
}

# 3. WEB SERVERS (Приватные подсети)
resource "yandex_compute_instance" "web_a" {
  name        = "web-a"
  hostname    = "web-a"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    user-data = file("./cloud-init.yml")
  }
}

resource "yandex_compute_instance" "web_b" {
  name        = "web-b"
  hostname    = "web-b"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      size     = 10
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    user-data = file("./cloud-init.yml")
  }
}

# 4. MONITORING: Prometheus (Приватная) и Grafana (Приватная)
resource "yandex_compute_instance" "prometheus" {
  name        = "prometheus"
  zone        = "ru-central1-a"
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    security_group_ids = [yandex_vpc_security_group.monitoring_sg.id]
  }
  resources {
    cores  = 2
    memory = 4
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      size     = 10
    }
  }
  metadata = { user-data = file("./cloud-init.yml") }
}

resource "yandex_compute_instance" "grafana" {
  name        = "grafana"
  zone        = "ru-central1-a"
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.monitoring_sg.id]
  }
  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      size     = 10
    }
  }
  metadata = { user-data = file("./cloud-init.yml") }
}

# 5. LOGGING: Elasticsearch (Приватная) и Kibana (Приватная)
resource "yandex_compute_instance" "elasticsearch" {
  name        = "elasticsearch"
  zone        = "ru-central1-a"
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    security_group_ids = [yandex_vpc_security_group.logging_sg.id]
  }
    resources {
    cores  = 2
    memory = 8
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      size     = 30
    }
  }
  metadata = { user-data = file("./cloud-init.yml") }
}

resource "yandex_compute_instance" "kibana" {
  name        = "kibana"
  zone        = "ru-central1-a"
  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.logging_sg.id]
  }
    resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      size     = 10
    }
  }
  metadata = { user-data = file("./cloud-init.yml") }
}

# 6. РЕЗЕРВНОЕ КОПИРОВАНИЕ (Snapshot Schedule)
resource "yandex_compute_snapshot_schedule" "daily_backup" {
  name = "daily-backup-schedule"

  schedule_policy {
    expression = "0 0 * * *" # Каждый день в 00:00
  }

  retention_period = "168h" # Хранить 7 дней (неделю)

  snapshot_spec {
    description = "Daily backup for course project"
  }

  disk_ids = [
    yandex_compute_instance.web_a.boot_disk.0.disk_id,
    yandex_compute_instance.web_b.boot_disk.0.disk_id,
    yandex_compute_instance.bastion.boot_disk.0.disk_id,
    yandex_compute_instance.prometheus.boot_disk.0.disk_id,
    yandex_compute_instance.grafana.boot_disk.0.disk_id,
    yandex_compute_instance.elasticsearch.boot_disk.0.disk_id,
    yandex_compute_instance.kibana.boot_disk.0.disk_id
  ]
}

# 7.1 Кластер БД для мониторигна
resource "yandex_mdb_postgresql_cluster" "prom_db" {
  name        = "prometheus-storage"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.develop.id

  config {
    version = 15
    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 20
    }
  }

  host {
    zone      = "ru-central1-a"
    subnet_id = yandex_vpc_subnet.private_a.id
  }

  host {
    zone      = "ru-central1-b"
    subnet_id = yandex_vpc_subnet.private_b.id
  }
}

# 7.2 Отдельный ресурс для базы данных
resource "yandex_mdb_postgresql_database" "prom_database" {
  cluster_id = yandex_mdb_postgresql_cluster.prom_db.id
  name       = "prometheus"
  owner      = yandex_mdb_postgresql_user.prom_user.name
}

# 7.3 Отдельный ресурс для пользователя
resource "yandex_mdb_postgresql_user" "prom_user" {
  cluster_id = yandex_mdb_postgresql_cluster.prom_db.id
  name       = var.db_user
  password   = var.db_pass
}


# 7. ГЕНЕРАЦИЯ INVENTORY ДЛЯ ANSIBLE
resource "local_file" "inventory" {
  content  = <<-XYZ
  [bastion]
  bastion ansible_host=${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}

  [webservers]
  web-a ansible_host=${yandex_compute_instance.web_a.network_interface.0.ip_address}
  web-b ansible_host=${yandex_compute_instance.web_b.network_interface.0.ip_address}

  [monitoring]
  prometheus ansible_host=${yandex_compute_instance.prometheus.network_interface.0.ip_address}
  grafana ansible_host=${yandex_compute_instance.grafana.network_interface.0.ip_address}

  [logging]
  elasticsearch ansible_host=${yandex_compute_instance.elasticsearch.network_interface.0.ip_address}
  kibana ansible_host=${yandex_compute_instance.kibana.network_interface.0.ip_address}

  [all:vars]
  ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p -q pavel@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
  alb_public_ip=${yandex_alb_load_balancer.web_alb.listener.0.endpoint.0.address.0.external_ipv4_address.0.address}
  
  # Используем FQDN облачного кластера PostgreSQL
  db_host=${yandex_mdb_postgresql_cluster.prom_db.host.0.fqdn}
  db_user=${var.db_user}
  db_password=${var.db_pass}
  
  # Внутренние адреса для настройки Nginx Proxy
  grafana_internal_ip=${yandex_compute_instance.grafana.network_interface.0.ip_address}
  kibana_internal_ip=${yandex_compute_instance.kibana.network_interface.0.ip_address}
  XYZ
  filename = "./hosts.ini"
}

