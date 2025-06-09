variable "project_id" {
  description = "El ID del proyecto de Google Cloud"
  type        = string
}

variable "region" {
  description = "La región de Google Cloud donde se desplegará la infraestructura"
  type        = string
}

variable "zone" {
  description = "La zona específica dentro de la región"
  type        = string
}

variable "cluster_name" {
  description = "El nombre del clúster GKE"
  type        = string
}

variable "gke_num_nodes" {
  description = "Número de nodos en el clúster GKE"
  type        = number
} 