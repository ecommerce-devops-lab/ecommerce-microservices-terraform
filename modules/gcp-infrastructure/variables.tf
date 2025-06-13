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