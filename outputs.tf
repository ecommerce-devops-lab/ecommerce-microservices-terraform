output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "Nombre del clúster GKE"
}

output "kubernetes_cluster_host" {
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
  description = "Endpoint del clúster GKE"
}

output "project_id" {
  value       = var.project_id
  description = "ID del proyecto de Google Cloud"
}

output "region" {
  value       = var.region
  description = "Región de Google Cloud"
}

output "cluster_location" {
  value       = google_container_cluster.primary.location
  description = "Ubicación del clúster GKE"
}

output "cluster_ca_certificate" {
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
  description = "Certificado CA del clúster"
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

output "api_gateway_service_type" {
  value       = kubernetes_service.api_gateway.spec[0].type
  description = "Tipo de servicio del API Gateway"
}

output "service_discovery_service_type" {
  value       = kubernetes_service.service_discovery.spec[0].type
  description = "Tipo de servicio del Service Discovery"
}

output "zipkin_service_type" {
  value       = kubernetes_service.zipkin.spec[0].type
  description = "Tipo de servicio de Zipkin"
}

output "namespace" {
  value       = kubernetes_namespace.ecommerce.metadata[0].name
  description = "Namespace de Kubernetes utilizado"
}

output "config_map_name" {
  value       = kubernetes_config_map.ecommerce_config.metadata[0].name
  description = "Nombre del ConfigMap"
}

# Información sobre cómo conectarse al clúster
output "gcloud_connect_command" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${google_container_cluster.primary.location} --project ${var.project_id}"
  description = "Comando para conectarse al clúster usando gcloud"
}

# URLs importantes (una vez desplegado) - Servicios públicos
output "api_gateway_external_ip_command" {
  value = "kubectl get service api-gateway -n ${var.namespace} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
  description = "Comando para obtener la IP externa del API Gateway"
}

output "zipkin_external_ip_command" {
  value = "kubectl get service zipkin -n ${var.namespace} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
  description = "Comando para obtener la IP externa de Zipkin"
}

output "service_discovery_external_ip_command" {
  value = "kubectl get service service-discovery -n ${var.namespace} -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
  description = "Comando para obtener la IP externa del Service Discovery"
}

# URLs de acceso directo
output "api_gateway_url_info" {
  value = "Una vez desplegado, el API Gateway estará disponible en: http://<EXTERNAL_IP>:8080"
  description = "Información de acceso al API Gateway"
}

output "zipkin_url_info" {
  value = "Una vez desplegado, Zipkin UI estará disponible en: http://<EXTERNAL_IP>:9411"
  description = "Información de acceso a Zipkin UI"
}

output "service_discovery_url_info" {
  value = "Una vez desplegado, Eureka UI estará disponible en: http://<EXTERNAL_IP>:8761"
  description = "Información de acceso a Eureka Service Discovery UI"
}

# Orden de despliegue implementado
output "deployment_order" {
  value = [
    "1. Zipkin",
    "2. Service Discovery", 
    "3. Cloud Config",
    "4. API Gateway",
    "5. User Service",
    "6. Product Service", 
    "7. Order Service",
    "8. Payment Service",
    "9. Shipping Service",
    "10. Favourite Service",
    "11. Proxy Client"
  ]
  description = "Orden de despliegue implementado con dependencias"
}

# Servicios con acceso público
output "public_services" {
  value = [
    "API Gateway (LoadBalancer)",
    "Service Discovery (LoadBalancer)", 
    "Zipkin (LoadBalancer)"
  ]
  description = "Servicios con acceso público directo"
} 