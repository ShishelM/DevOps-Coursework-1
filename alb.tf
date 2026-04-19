# 1. Target Group — объединяем ваши ВМ из разных зон (приватные подсети)
resource "yandex_alb_target_group" "web_tg" {
  name = "web-target-group-${var.flow}"

  target {
    subnet_id  = yandex_vpc_subnet.private_a.id
    ip_address = yandex_compute_instance.web_a.network_interface.0.ip_address
  }

  target {
    subnet_id  = yandex_vpc_subnet.private_b.id
    ip_address = yandex_compute_instance.web_b.network_interface.0.ip_address
  }
}

# 2. Backend Group — настройка балансировки и проверки здоровья
resource "yandex_alb_backend_group" "web_bg" {
  name = "web-backend-group-${var.flow}"

  http_backend {
    name             = "web-backend"
    weight           = 1
    port             = 80
    target_group_ids = [yandex_alb_target_group.web_tg.id]
    
    # Настройка healthcheck на корень (/) и порт 80, протокол HTTP
    healthcheck {
      timeout            = "1s"
      interval           = "1s"
      healthy_threshold  = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path = "/"
      }
    }
  }
}

# 3. HTTP Router — маршрутизация запросов
resource "yandex_alb_http_router" "web_router" {
  name = "web-http-router-${var.flow}"
}

resource "yandex_alb_virtual_host" "web_vh" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.web_router.id
  route {
    name = "root-path"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_bg.id
        timeout          = "3s"
      }
    }
  }
}

# 4. Application Load Balancer — точка входа
resource "yandex_alb_load_balancer" "web_alb" {
  name               = "web-alb-${var.flow}"
  network_id         = yandex_vpc_network.develop.id
  
  # Используем только группу alb_sg (в которой прописан loadbalancer_healthchecks)
  security_group_ids = [yandex_vpc_security_group.alb_sg.id]

allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public_a.id
    }
    location {
      zone_id   = "ru-central1-b"
      subnet_id = yandex_vpc_subnet.public_b.id # Теперь подсеть определена
    }
  }

  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id
      }
    }
  }
}

# Вывод публичного IP для финального теста через curl
output "alb_external_ip" {
  description = "Public IP address of the ALB. Use this for: curl -v <IP>:80"
  value       = yandex_alb_load_balancer.web_alb.listener.0.endpoint.0.address.0.external_ipv4_address.0.address
}