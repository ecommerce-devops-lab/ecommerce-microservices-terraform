output "zipkin_service_name" {
  value       = kubernetes_service.zipkin.metadata[0].name
  description = "Nombre del servicio de Zipkin"
}

output "zipkin_service_type" {
  value       = kubernetes_service.zipkin.spec[0].type
  description = "Tipo de servicio de Zipkin"
} 