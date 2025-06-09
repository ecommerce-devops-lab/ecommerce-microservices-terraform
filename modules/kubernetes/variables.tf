variable "namespace" {
  description = "Namespace de Kubernetes para los microservicios"
  type        = string
  default     = "ecommerce"
}

variable "cluster_dependency" {
  description = "Dependencia del clúster para esperar que esté listo"
  type        = any
} 