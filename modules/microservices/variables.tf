variable "namespace" {
  description = "Namespace de Kubernetes"
  type        = string
}

variable "project_id" {
  description = "ID del proyecto de Google Cloud"
  type        = string
}

variable "container_registry_hostname" {
  description = "Hostname del container registry"
  type        = string
}

variable "image_tag" {
  description = "Tag de la imagen de los microservicios"
  type        = string
}

variable "config_map_name" {
  description = "Nombre del ConfigMap principal"
  type        = string
}

variable "cloud_config_map_name" {
  description = "Nombre del ConfigMap de cloud-config"
  type        = string
}

variable "dependencies" {
  description = "Dependencias para los microservicios"
  type        = any
  default     = []
}

variable "microservices" {
  description = "Mapa de configuración de microservicios"
  type = map(object({
    port              = number
    target_port       = number
    replicas          = number
    service_type      = string
    health_check_path = string
    memory_request    = string
    memory_limit      = string
    cpu_request       = string
    cpu_limit         = string
  }))
} 