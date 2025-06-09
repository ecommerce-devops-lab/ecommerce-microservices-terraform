output "namespace_name" {
  value       = kubernetes_namespace.ecommerce.metadata[0].name
  description = "Nombre del namespace creado"
}

output "config_map_name" {
  value       = kubernetes_config_map.ecommerce_config.metadata[0].name
  description = "Nombre del ConfigMap principal"
}

output "cloud_config_map_name" {
  value       = kubernetes_config_map.cloud_config_files.metadata[0].name
  description = "Nombre del ConfigMap de cloud-config"
} 