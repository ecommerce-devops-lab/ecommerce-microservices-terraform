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
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [google_container_cluster.primary]
} 