# 1. Сеть
resource "yandex_vpc_network" "develop" {
  name = "develop-network-${var.flow}"
}

# 2. Подсети
resource "yandex_vpc_subnet" "public_a" {
  name           = "public-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_vpc_subnet" "public_b" {
  name           = "public-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.0.2.0/24"]
}

resource "yandex_vpc_subnet" "private_a" {
  name           = "private-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.10.1.0/24"]
  route_table_id = yandex_vpc_route_table.private_rt.id
}

resource "yandex_vpc_subnet" "private_b" {
  name           = "private-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["10.10.2.0/24"]
  route_table_id = yandex_vpc_route_table.private_rt.id
}

# 3. NAT для приватных подсетей
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "private_rt" {
  network_id = yandex_vpc_network.develop.id
  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

# 4. Security Groups

# Группа для Бастиона
resource "yandex_vpc_security_group" "bastion_sg" {
  name       = "bastion-sg"
  network_id = yandex_vpc_network.develop.id
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Группа для ALB
resource "yandex_vpc_security_group" "alb_sg" {
  name       = "alb-sg"
  network_id = yandex_vpc_network.develop.id
  ingress {
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
  }
  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Группа для Веб-серверов
resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-server-sg"
  network_id = yandex_vpc_network.develop.id
  
  ingress {
    protocol          = "TCP"
    port              = 80
    security_group_id = yandex_vpc_security_group.alb_sg.id
  }
  ingress {
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion_sg.id
  }
  # Разрешаем мониторингу забирать метрики Node Exporter
  ingress {
    protocol          = "TCP"
    port              = 9100
    security_group_id = yandex_vpc_security_group.monitoring_sg.id
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Группа для Мониторинга (Prometheus + Grafana)
resource "yandex_vpc_security_group" "monitoring_sg" {
  name       = "monitoring-sg"
  network_id = yandex_vpc_network.develop.id
  
  # Разрешаем входящий трафик на Grafana (3000) от подсетей веб-серверов
  ingress {
    protocol       = "TCP"
    port           = 3000
    v4_cidr_blocks = ["10.10.1.0/24", "10.10.2.0/24"]
  }
  
  ingress {
    protocol       = "TCP"
    port           = 9090
    v4_cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion_sg.id
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Группа для Логов (Elasticsearch + Kibana)
resource "yandex_vpc_security_group" "logging_sg" {
  name       = "logging-sg"
  network_id = yandex_vpc_network.develop.id
  
  # Разрешаем входящий трафик на Kibana (5601) от подсетей веб-серверов
  ingress {
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["10.10.1.0/24", "10.10.2.0/24"]
  }

  ingress {
    protocol       = "TCP"
    port           = 9200
    v4_cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    protocol          = "TCP"
    port              = 22
    security_group_id = yandex_vpc_security_group.bastion_sg.id
  }
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}