# 2. КРАСИВЫЙ ФИНАЛЬНЫЙ ОТЧЕТ (Для человека)
output "final_project_info" {
  value = <<EOT

=====================================================================
                    ПРОЕКТ РАЗВЕРНУТ УСПЕШНО
=====================================================================

1. ТЕСТИРОВАНИЕ ВЕБ-САЙТА (ALB)
---------------------------------------------------------------------
Ссылка:  http://${yandex_alb_load_balancer.web_alb.listener.0.endpoint.0.address.0.external_ipv4_address.0.address}
Команда: curl -v http://${yandex_alb_load_balancer.web_alb.listener.0.endpoint.0.address.0.external_ipv4_address.0.address}

2. МОНИТОРИНГ (Prometheus & Grafana)
---------------------------------------------------------------------
Grafana Web UI:  http://${yandex_alb_load_balancer.web_alb.listener.0.endpoint.0.address.0.external_ipv4_address.0.address}/grafana/
Логин/Пароль:    admin / admin
Prometheus URL (internal): http://${yandex_compute_instance.prometheus.network_interface.0.ip_address}:9090

3. ЛОГИ (Kibana)
---------------------------------------------------------------------
Kibana Web UI: http://${yandex_alb_load_balancer.web_alb.listener.0.endpoint.0.address.0.external_ipv4_address.0.address}/kibana/

4. ДОСТУП (SSH Bastion)
---------------------------------------------------------------------
Публичный IP: ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}
Команда: ssh pavel@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}

5. ВНУТРЕННЯЯ ИНФРАСТРУКТУРА (ДЛЯ ПРОВЕРКИ)
---------------------------------------------------------------------
web-a:         ${yandex_compute_instance.web_a.network_interface.0.ip_address}
web-b:         ${yandex_compute_instance.web_b.network_interface.0.ip_address}
prometheus:    ${yandex_compute_instance.prometheus.network_interface.0.ip_address}
elasticsearch: ${yandex_compute_instance.elasticsearch.network_interface.0.ip_address}
grafana:       ${yandex_compute_instance.grafana.network_interface.0.ip_address}
kibana:        ${yandex_compute_instance.kibana.network_interface.0.ip_address}

6. ДЕТАЛЬНАЯ ИНФОРМАЦИЯ (Yandex Cloud)
---------------------------------------------------------------------
Cloud ID:      ${var.cloud_id}
Folder ID:     ${var.folder_id}
Network ID:    ${yandex_vpc_network.develop.id}
PostgreSQL:    ${yandex_mdb_postgresql_cluster.prom_db.host.0.fqdn}
Snapshots:     Ежедневно (retention 168h)

=====================================================================
Примечание: Доступ к Grafana и Kibana теперь осуществляется через 
проксирование на Web-серверах. Убедитесь, что Ansible настроил Nginx.
=====================================================================
EOT
}