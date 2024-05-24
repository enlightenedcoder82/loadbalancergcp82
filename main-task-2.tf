terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.27.0"
    }
  }
}

provider "google" {
  # Configuration options
  project     = "project-armaggaden-may11"
  region      = "us-central1"
  zone        = "us-central1-a"
  credentials = "project-armaggaden-may11-2cff6047c441.json"
}

# provider = google-beta
provider "google-beta" {
  # Configuration options
  project     = "project-armaggaden-may11"
  region      = "us-central1"
  zone        = "us-central1-a"
  credentials = "project-armaggaden-may11-2cff6047c441.json"
}


resource "google_compute_network" "vpc" {
  name                  = "vpc"
  auto_create_subnetworks = false
  # depends_on = [google_compute_subnetwork.proxy, google_compute_network.vpc]
}

resource "google_compute_subnetwork" "us-central1a-subnet" {
  name          = "us-central1a-subnet"
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = "10.121.2.0/24"
  region        = "us-central1"
  private_ip_google_access = true
}

resource "google_compute_firewall" "allow-icmp" {
  name    = "icmp-test-firewall"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
  priority      = 600
}

resource "google_compute_firewall" "http" {
  name    = "allow-http"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  priority      = 100
}

resource "google_compute_firewall" "https" {
  name    = "allow-https"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
  source_ranges = ["0.0.0.0/0"]
  priority      = 100
}



resource "google_compute_instance_template" "instance-template" {
  name = "romulus-server"
  description = "romulus-server"
  labels = {
    environment = "production"
    name = "romulus-server"

  }
  instance_description = "this is an instance that has been autochaled"
  machine_type = "e2-medium"
  can_ip_forward = "false"

  scheduling {
    automatic_restart = "true"
    on_host_maintenance = "MIGRATE"
  }
  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete = "true"
    boot = "true"
  }
  disk {
    
    auto_delete = "false"
    # boot = "true"
  disk_size_gb = "10"
  mode = "READ_WRITE"
  type = "PERSISTENT"
  
  }
    network_interface {
    network    = google_compute_network.vpc.self_link
    subnetwork = google_compute_subnetwork.us-central1a-subnet.self_link

    access_config {
      // Ephemeral IP
    }
  }

  tags = ["http-server"]

  
  metadata_startup_script = file("startup.sh")

 
 depends_on = [google_compute_network.vpc,
  google_compute_subnetwork.us-central1a-subnet, google_compute_firewall.http]
}



resource "google_compute_health_check" "health-check05" {
  count = 1
  name               = "http-basic-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 10
  
  http_health_check {
    request_path = "/"
    port = "80"
  }
}

#Group Manager

resource "google_compute_region_instance_group_manager" "region-instance-group" {
  name = "instance-group82"

  base_instance_name         = "app"
  region                     = "us-central1"
  distribution_policy_zones  = ["us-central1-a", "us-central1-f"]

  version {
    instance_template = google_compute_instance_template.instance-template.id
  }



  named_port {
    name = "custom"
    port = 80
  }

  
}


resource "google_compute_region_autoscaler" "autoscaler" {
    count = 1 
    name = "autoscaler"
    project = "project-armaggaden-may11"
    region = "us-central1"
    target = "${google_compute_region_instance_group_manager.region-instance-group.self_link}"

    autoscaling_policy  {
        max_replicas = 6
        min_replicas = 3
        cooldown_period = 60
        cpu_utilization {
            target = "0.6"
        }
    } 
}


