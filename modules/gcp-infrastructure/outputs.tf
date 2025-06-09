output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "Nombre del clúster GKE"
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
  description = "Endpoint del clúster GKE"
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
  description = "Certificado CA del clúster"
}

output "cluster_location" {
  value       = google_container_cluster.primary.location
  description = "Ubicación del clúster GKE"
}

output "vpc_name" {
  value       = google_compute_network.vpc.name
  description = "Nombre de la VPC"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet.name
  description = "Nombre de la subred"
}

output "node_pool_name" {
  value       = google_container_node_pool.primary_nodes.name
  description = "Nombre del node pool"
}

output "cluster_data" {
  value = {
    name       = google_container_cluster.primary.name
    location   = google_container_cluster.primary.location
    endpoint   = google_container_cluster.primary.endpoint
    ca_cert    = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  }
  sensitive   = true
  description = "Datos completos del clúster para otros módulos"
} 