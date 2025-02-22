
resource "google_compute_address" "loadbalancer-ip" {
  name = "website-ip-1"
  provider = google-beta 
  region = "us-central1"
  network_tier = "STANDARD"
  # network_tier = "PREMIUM"
}

resource "google_compute_region_target_http_proxy" "proxy-sub01" {
  provider = google-beta

  region  = "us-central1"
  name    = "website-proxy"
  url_map = google_compute_region_url_map.default.id
}

resource "google_compute_subnetwork" "proxy" {
  provider = google-beta
  name          = "website-net-proxy"
  ip_cidr_range = "10.129.0.0/26"
  region        = "us-central1"
  network       = google_compute_network.vpc.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

// Forwarding rule for Regional External Load Balancing
resource "google_compute_forwarding_rule" "load-balancer82" {
  provider = google-beta
  depends_on = [google_compute_subnetwork.us-central1a-subnet]
  name   = "website-forwarding-rule"
  region = "us-central1"

  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.proxy-sub01.id
  network               = google_compute_network.vpc.id
  ip_address            = google_compute_address.loadbalancer-ip.address
  network_tier          = "STANDARD"
}

# resource "google_compute_region_target_http_proxy" "proxy-sub01" {
#   provider = google-beta

#   region  = "us-central1"
#   name    = "website-proxy"
#   url_map = google_compute_region_url_map.default.id
# }

resource "google_compute_region_url_map" "default" {
  provider = google-beta

  region          = "us-central1"
  name            = "website-map"
  default_service = google_compute_region_backend_service.default.id
}

resource "google_compute_region_backend_service" "default" {
  provider = google-beta

  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_instance_group_manager.region-instance-group.instance_group
    balancing_mode = "UTILIZATION"
    capacity_scaler = 1.0
  }

  region      = "us-central1"
  name        = "website-backend"
  protocol    = "HTTP"
  timeout_sec = 10

  health_checks = [google_compute_region_health_check.region-health-check06.id]
}

# data "google_compute_image" "debian_image" {
#   provider = google-beta
#   family   = "debian-cloud/debian-12"
#   project  = "project-armaggaden-may11"
   
  
# }
data "google_compute_image" "debian_image" {
  provider = google-beta
  family   = "debian-12"
  project  = "debian-cloud"
}


# resource "google_compute_region_instance_group_manager" "region-instance-group" {
  # provider = google-beta
#   region   = "us-central1"
#   name     = "website-rigm"
#   version {
#     instance_template = google_compute_instance_template.instance-template.id
#     name              = "primary"
#   }
#   base_instance_name = "internal-glb"
#   target_size        = 1
# }

# resource "google_compute_instance_template" "instance_template" {
#   provider     = google-beta
#   name         = "template-website-backend"
#   machine_type = "e2-medium"

#   network_interface {
#     network = google_compute_network.default.id
#     subnetwork = google_compute_subnetwork.default.id
#   }

#   disk {
#     source_image = data.google_compute_image.debian_image.self_link
#     auto_delete  = true
#     boot         = true
#   }

#   tags = ["allow-ssh", "load-balanced-backend"]
# }

resource "google_compute_region_health_check" "region-health-check06" {
  depends_on = [google_compute_firewall.https]
  provider = google-beta

  region = "us-central1"
  name   = "website-hc"
  http_health_check {
    port_specification = "USE_SERVING_PORT"
  }
}

# resource "google_compute_address" "loadbalancer-ip" {
#   name = "website-ip-1"
#   provider = google-beta 
#   region = "us-central1"
#   # network_tier = "STANDARD"
#   network_tier = "PREMIUM"
# }

resource "google_compute_firewall" "fw1" {
  provider = google-beta
  name = "website-fw-1"
  network = google_compute_network.vpc.id
  source_ranges = ["10.1.2.0/24"]
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  direction = "INGRESS"
}

resource "google_compute_firewall" "fw2" {
  depends_on = [google_compute_firewall.fw1]
  provider = google-beta
  name = "website-fw-2"
  network = google_compute_network.vpc.id
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  target_tags = ["allow-ssh"]
  direction = "INGRESS"
}

resource "google_compute_firewall" "fw3" {
  depends_on = [google_compute_firewall.fw2]
  provider = google-beta
  name = "website-fw-3"
  network = google_compute_network.vpc.id
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  allow {
    protocol = "tcp"
  }
  target_tags = ["load-balanced-backend"]
  direction = "INGRESS"
}

resource "google_compute_firewall" "fw4" {
  depends_on = [google_compute_firewall.fw3]
  provider = google-beta
  name = "website-fw-4"
  network = google_compute_network.vpc.id
  source_ranges = ["10.129.0.0/26"]
  target_tags = ["load-balanced-backend"]
  allow {
    protocol = "tcp"
    ports = ["80"]
  }
  allow {
    protocol = "tcp"
    ports = ["443"]
  }
  allow {
    protocol = "tcp"
    ports = ["8000"]
  }
  direction = "INGRESS"
}

# resource "google_compute_network" "default" {
#   provider = google-beta
#   name                    = "website-net"
#   auto_create_subnetworks = false
#   routing_mode = "REGIONAL"
# }

# resource "google_compute_subnetwork" "default" {
#   provider = google-beta
#   name          = "website-net-default"
#   ip_cidr_range = "10.1.2.0/24"
#   region        = "us-central1"
#   network       = google_compute_network.default.id
# }

# resource "google_compute_subnetwork" "proxy" {
#   provider = google-beta
#   name          = "website-net-proxy"
#   ip_cidr_range = "10.129.0.0/26"
#   region        = "us-central1"
#   network       = google_compute_network.default.id
#   purpose       = "REGIONAL_MANAGED_PROXY"
#   role          = "ACTIVE"
# }