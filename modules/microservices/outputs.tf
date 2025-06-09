output "service_names" {
  value       = [for service in kubernetes_service.microservice : service.metadata[0].name]
  description = "Nombres de todos los servicios creados"
}

output "service_types" {
  value       = {for k, service in kubernetes_service.microservice : k => service.spec[0].type}
  description = "Tipos de servicio para cada microservicio"
}

output "deployment_names" {
  value       = [for deployment in kubernetes_deployment.microservice : deployment.metadata[0].name]
  description = "Nombres de todos los deployments creados"
} 