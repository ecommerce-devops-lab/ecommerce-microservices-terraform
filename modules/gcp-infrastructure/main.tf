# Habilitar APIs necesarias
resource "google_project_service" "container" {
  service = "container.googleapis.com"
  project = var.project_id

  disable_dependent_services = true
}

resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
  project = var.project_id

  disable_dependent_services = true
}

resource "google_project_service" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy = false
}

# Crear VPC para el clúster
resource "google_compute_network" "vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# Crear subred para el clúster
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = "192.168.1.0/24"
  }

  secondary_ip_range {
    range_name    = "pod-range"
    ip_cidr_range = "192.168.64.0/22"
  }
}

# Crear clúster GKE
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone
  project  = var.project_id

  # Deshabilitar la creación de un node pool por defecto
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false
  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnet.self_link

  # Configuración de IP aliasing
  ip_allocation_policy {
    cluster_secondary_range_name  = "pod-range"
    services_secondary_range_name = "services-range"
  }

  # Configuración de red privada
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Configuración de master autorizada networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All"
    }
  }

  # Configuración de workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  depends_on = [
    google_project_service.container,
    google_project_service.compute,
  ]
}

# Crear node pool separado
resource "google_container_node_pool" "primary_nodes" {
  name       = "ecommerce-nodes"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    preemptible  = false
    machine_type = "e2-standard-2" # 2 vCPUs, 8 GB RAM

    # Configuración de disco
    disk_size_gb = 50
    disk_type    = "pd-standard"

    # Configuración de OAuth
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    # Labels para el node pool
    labels = {
      env = var.cluster_name
    }

    # Configuración de workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Taints opcionales
    tags = ["gke-node", "${var.cluster_name}-gke"]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [google_container_cluster.primary]
}

# Circuit Breaker Pattern Implementation
resource "google_endpoints_service" "api_service" {
  service_name = "api.endpoints.${var.project_id}.cloud.goog"
  openapi_config = jsonencode({
    swagger = "2.0"
    info = {
      title = "Ecommerce API Service"
      version = "1.0.0"
    }
    host = "api.endpoints.${var.project_id}.cloud.goog"
    schemes = ["https"]
    securityDefinitions = {
      api_key = {
        type = "apiKey"
        name = "key"
        in = "query"
      }
    }
    security = [
      {
        api_key = []
      }
    ]
    paths = {
      "/api/v1/products" = {
        get = {
          summary = "Get products"
          operationId = "getProducts"
          security = [
            {
              api_key = []
            }
          ]
          responses = {
            "200" = {
              description = "Successful response"
            }
          }
        }
      }
    }
    x-google-endpoints = [
      {
        name = "api.endpoints.${var.project_id}.cloud.goog"
        allowCors = true
      }
    ]
    x-google-backend = {
      address = "https://199.36.158.100"
      path_translation = "APPEND_PATH_TO_ADDRESS"
      protocol = "h2"
      jwt_audience = "https://api.endpoints.${var.project_id}.cloud.goog"
    }
  })
}

# External Configuration Pattern Implementation
resource "google_secret_manager_secret" "app_config" {
  depends_on = [google_project_service.secretmanager]
  secret_id = "app-config"
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "app_config_version" {
  secret = google_secret_manager_secret.app_config.id
  secret_data = jsonencode({
    database_url = "jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1"
    api_key = var.api_key
    service_config = {
      payment_service = {
        timeout = 5000
        retry_attempts = 3
      }
      order_service = {
        timeout = 3000
        retry_attempts = 2
      }
    }
  })
}

# Health check for the backend service
resource "google_compute_health_check" "service_health" {
  name               = "service-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 3

  http_health_check {
    port = 8080
    request_path = "/health"
  }
}

# Instance group manager for the service
resource "google_compute_instance_group_manager" "service_group" {
  name = "service-group"
  zone = "${var.region}-a"

  base_instance_name = "service-instance"
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.service_template.id
  }
}

# Instance template for the service
resource "google_compute_instance_template" "service_template" {
  name        = "service-template"
  description = "Template for service instances"

  machine_type = "e2-medium"

  network_interface {
    network = "default"
    access_config {
      // Ephemeral public IP
    }
  }

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }
}

# Bulkhead Pattern Implementation
resource "google_compute_autoscaler" "service_autoscaler" {
  name   = "service-autoscaler"
  target = google_compute_instance_group_manager.service_group.id

  autoscaling_policy {
    max_replicas    = 4
    min_replicas    = 1
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }

    load_balancing_utilization {
      target = 0.7
    }
  }
}

resource "google_compute_backend_service" "service_backend" {
  name        = "service-backend"
  protocol    = "HTTP"
  timeout_sec = 10

  health_checks = [google_compute_health_check.service_health.id]

  backend {
    group = google_compute_instance_group_manager.service_group.instance_group
  }
}

# DNS Record for the Endpoints service
resource "google_dns_managed_zone" "endpoints_zone" {
  name        = "endpoints-zone"
  dns_name    = "api.endpoints.${var.project_id}.cloud.goog."
  description = "DNS zone for Cloud Endpoints"
}

resource "google_dns_record_set" "endpoints_record" {
  name         = google_dns_managed_zone.endpoints_zone.dns_name
  managed_zone = google_dns_managed_zone.endpoints_zone.name
  type         = "A"
  ttl          = 300

  rrdatas = ["199.36.158.100"] # IP de Cloud Endpoints
} 