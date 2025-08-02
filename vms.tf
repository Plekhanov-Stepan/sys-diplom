
#считываем данные об образе ОС
data "yandex_compute_image" "ubuntu_2204_lts" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "bastion" {
  name        = "bastion" #Имя ВМ в облачной консоли
  hostname    = "bastion" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = false }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id #зона ВМ должна совпадать с зоной subnet!!!
    nat                = true
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.bastion.id]
  }
}


resource "yandex_compute_instance" "web_a" {
  name        = "web-a" #Имя ВМ в облачной консоли
  hostname    = "web-a" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!


  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = false }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]
  }
}

resource "yandex_compute_instance" "web_b" {
  name        = "web-b" #Имя ВМ в облачной консоли
  hostname    = "web-b" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-b" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = false }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_b.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.web_sg.id]

  }
}

resource "yandex_alb_target_group" "web_tg" {
  name      = "web-tg"

  target {
    subnet_id = yandex_vpc_subnet.develop_a.id
    ip_address   = yandex_compute_instance.web_a.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.develop_b.id
    ip_address   = yandex_compute_instance.web_b.network_interface.0.ip_address
  }   
}

resource "yandex_alb_backend_group" "web_alb_bg" {
  name = "web-backend-group"

  http_backend {
    name             = "web-http-backend"
    weight           = 1
    port             = 80
    target_group_ids = ["${yandex_alb_target_group.web_tg.id}"]
    load_balancing_config {
      panic_threshold = 75
    }
    healthcheck {
      timeout  = "1s"
      interval = "1s"
      http_healthcheck {
        path = "/"
      }
      healthcheck_port = 80
    }
    http2 = "false"
  }
}

resource "yandex_alb_http_router" "tf_router" {
  name = "web-http-router"
}

resource "yandex_alb_virtual_host" "web_vhost" {
  name           = "web-virtual-host"
  http_router_id = yandex_alb_http_router.tf_router.id
  route {
    name = "web-route"
    http_route {
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web_alb_bg.id
        timeout          = "3s"
      }
    }
  }
}

resource "yandex_alb_load_balancer" "web_alb" {
  name = "web-load-balancer"

  network_id = yandex_vpc_network.develop.id
  
  security_group_ids = [yandex_vpc_security_group.alb_sg.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.develop_a.id
    }
  }

  listener {
    name = "web-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.tf_router.id
      }
    }
  }

}

resource "yandex_compute_instance" "zabbix" {
  name        = "zabbix" #Имя ВМ в облачной консоли
  hostname    = "zabbix" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = false }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id #зона ВМ должна совпадать с зоной subnet!!!
    nat                = true
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.zabbix.id]
  }
}

resource "yandex_compute_instance" "elastic" {
  name        = "elastic" #Имя ВМ в облачной консоли
  hostname    = "elastic" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 3
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = false }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id #зона ВМ должна совпадать с зоной subnet!!!
    nat                = false
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.elastic.id]
  }
}

resource "yandex_compute_instance" "kibana" {
  name        = "kibana" #Имя ВМ в облачной консоли
  hostname    = "kibana" #формирует FDQN имя хоста, без hostname будет сгенрировано случаное имя.
  platform_id = "standard-v3"
  zone        = "ru-central1-a" #зона ВМ должна совпадать с зоной subnet!!!

  resources {
    cores         = 2
    memory        = 1
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_2204_lts.image_id
      type     = "network-hdd"
      size     = 10
    }
  }

  metadata = {
    user-data          = file("./cloud-init.yml")
    serial-port-enable = 1
  }

  scheduling_policy { preemptible = false }

  network_interface {
    subnet_id          = yandex_vpc_subnet.develop_a.id #зона ВМ должна совпадать с зоной subnet!!!
    nat                = true
    security_group_ids = [yandex_vpc_security_group.LAN.id, yandex_vpc_security_group.kibana.id]
  }
}

resource "local_file" "inventory" {
  content  = <<-XYZ
  [bastion-server]
  ${yandex_compute_instance.bastion.hostname}

  [zabbix-server]
  ${yandex_compute_instance.zabbix.hostname}

  [zabbix-agents]
  ${yandex_compute_instance.bastion.hostname}
  ${yandex_compute_instance.web_a.hostname}
  ${yandex_compute_instance.web_b.hostname}
  ${yandex_compute_instance.elastic.hostname}
  ${yandex_compute_instance.kibana.hostname}

  [elastic-server]
  ${yandex_compute_instance.elastic.hostname}

  [kibana-server]
  ${yandex_compute_instance.kibana.hostname}

  [webservers]
  ${yandex_compute_instance.web_a.hostname}
  ${yandex_compute_instance.web_b.hostname}
  XYZ
  filename = "./hosts.ini"
}

resource "local_file" "hosts-ip" {
  content  = <<-XYZ
  EXTERNAL:
  ${yandex_compute_instance.bastion.hostname}: ${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}
  ${yandex_compute_instance.zabbix.hostname}: ${yandex_compute_instance.zabbix.network_interface.0.nat_ip_address}
  ${yandex_compute_instance.kibana.hostname}: ${yandex_compute_instance.kibana.network_interface.0.nat_ip_address}
  
  INTERNAL:
  ${yandex_compute_instance.bastion.hostname}: ${yandex_compute_instance.bastion.network_interface.0.ip_address}
  ${yandex_compute_instance.zabbix.hostname}: ${yandex_compute_instance.zabbix.network_interface.0.ip_address}
  ${yandex_compute_instance.elastic.hostname}: ${yandex_compute_instance.elastic.network_interface.0.ip_address}
  ${yandex_compute_instance.kibana.hostname}: ${yandex_compute_instance.kibana.network_interface.0.ip_address}
  ${yandex_compute_instance.web_a.hostname}: ${yandex_compute_instance.web_a.network_interface.0.ip_address}
  ${yandex_compute_instance.web_b.hostname}: ${yandex_compute_instance.web_b.network_interface.0.ip_address}
  XYZ
  filename = "./hosts-ip.lst"
}

resource "local_file" "variables" {
  content  = <<-XYZ
  elastic_server: ${yandex_compute_instance.elastic.network_interface.0.ip_address}
  kibana_server: ${yandex_compute_instance.kibana.network_interface.0.ip_address}
  zabbix_server: ${yandex_compute_instance.zabbix.network_interface.0.ip_address}
  ansible_ssh_common_args: '-o ProxyCommand="ssh -p 22 -W %h:%p -q plekhas@${yandex_compute_instance.bastion.network_interface.0.nat_ip_address}"'
  XYZ
  filename = "./variables.yml"
}

