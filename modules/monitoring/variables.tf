variable "namespace" {
  description = "Namespace de Kubernetes"
  type        = string
}

variable "namespace_dependency" {
  description = "Dependencia del namespace"
  type        = any
}

variable "zipkin_config" {
  description = "Configuración específica para Zipkin"
  type = object({
    port              = number
    target_port       = number
    replicas          = number
    service_type      = string
    health_check_path = string
    memory_request    = string
    memory_limit      = string
    cpu_request       = string
    cpu_limit         = string
    image             = string
  })
} 