variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  type        = string
}

variable "zone" {
  description = "The zone to deploy to"
  type        = string
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
}

variable "gke_num_nodes" {
  description = "Number of nodes in the GKE cluster"
  type        = number
}

variable "container_registry_hostname" {
  description = "Hostname del container registry"
  type        = string
  default     = "gcr.io"
}

variable "image_tag" {
  description = "Tag de la imagen de los microservicios"
  type        = string
  default     = "v2"
}

variable "namespace" {
  description = "Namespace de Kubernetes para los microservicios"
  type        = string
  default     = "ecommerce"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "production"
}

# Variables específicas para los microservicios
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
  default = {
    "service-discovery" = {
      port              = 8761
      target_port       = 8761
      replicas          = 1
      service_type      = "LoadBalancer"
      health_check_path = "/actuator/health"
      memory_request    = "384Mi"
      memory_limit      = "512Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
    "cloud-config" = {
      port              = 9296
      target_port       = 9296
      replicas          = 1
      service_type      = "LoadBalancer"
      health_check_path = "/actuator/health"
      memory_request    = "512Mi"
      memory_limit      = "768Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
    "api-gateway" = {
      port              = 8080
      target_port       = 8080
      replicas          = 1
      service_type      = "LoadBalancer"
      health_check_path = "/actuator/health"
      memory_request    = "384Mi"
      memory_limit      = "512Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
    "user-service" = {
      port              = 8700
      target_port       = 8700
      replicas          = 1
      service_type      = "ClusterIP"
      health_check_path = "/actuator/health"
      memory_request    = "384Mi"
      memory_limit      = "512Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
    "product-service" = {
      port              = 8500
      target_port       = 8500
      replicas          = 1
      service_type      = "ClusterIP"
      health_check_path = "/actuator/health"
      memory_request    = "384Mi"
      memory_limit      = "512Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
    "order-service" = {
      port              = 8300
      target_port       = 8300
      replicas          = 1
      service_type      = "ClusterIP"
      health_check_path = "/actuator/health"
      memory_request    = "384Mi"
      memory_limit      = "512Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
    "payment-service" = {
      port              = 8400
      target_port       = 8400
      replicas          = 1
      service_type      = "ClusterIP"
      health_check_path = "/actuator/health"
      memory_request    = "512Mi"
      memory_limit      = "768Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
    "shipping-service" = {
      port              = 8600
      target_port       = 8600
      replicas          = 1
      service_type      = "ClusterIP"
      health_check_path = "/actuator/health"
      memory_request    = "384Mi"
      memory_limit      = "512Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
    "favourite-service" = {
      port              = 8800
      target_port       = 8800
      replicas          = 1
      service_type      = "ClusterIP"
      health_check_path = "/actuator/health"
      memory_request    = "384Mi"
      memory_limit      = "512Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
    "proxy-client" = {
      port              = 8900
      target_port       = 8900
      replicas          = 1
      service_type      = "LoadBalancer"
      health_check_path = "/actuator/health"
      memory_request    = "256Mi"
      memory_limit      = "384Mi"
      cpu_request       = "125m"
      cpu_limit         = "250m"
    }
  }
}

# Configuración para Zipkin
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
  default = {
    port              = 9411
    target_port       = 9411
    replicas          = 1
    service_type      = "LoadBalancer"
    health_check_path = "/health"
    memory_request    = "256Mi"
    memory_limit      = "384Mi"
    cpu_request       = "125m"
    cpu_limit         = "250m"
    image             = "openzipkin/zipkin"
  }
}

variable "service_url" {
  description = "The URL of the service to be used in the API endpoints"
  type        = string
}

variable "db_host" {
  description = "Database host"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "api_key" {
  description = "API key for service authentication"
  type        = string
  sensitive   = true
} 