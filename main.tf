terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Recurso de tiempo para esperar a que el clúster esté listo
resource "time_sleep" "wait_for_cluster" {
  depends_on = [module.gcp_infrastructure]
  create_duration = "30s"
}

# Data sources para configurar el provider de Kubernetes
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gcp_infrastructure.cluster_endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gcp_infrastructure.cluster_ca_certificate)
  
  # Añadir configuración para reconexiones
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "gke-gcloud-auth-plugin"
  }
}

# Módulo de infraestructura GCP
module "gcp_infrastructure" {
  source = "./modules/gcp-infrastructure"

  project_id     = var.project_id
  region         = var.region
  zone           = var.zone
  cluster_name   = var.cluster_name
  gke_num_nodes  = var.gke_num_nodes
}

# Módulo de configuración base de Kubernetes
module "kubernetes_base" {
  source = "./modules/kubernetes"

  namespace           = var.namespace
  cluster_dependency  = time_sleep.wait_for_cluster
}

# Módulo de monitoring (Zipkin)
module "monitoring" {
  source = "./modules/monitoring"

  namespace            = module.kubernetes_base.namespace_name
  namespace_dependency = module.kubernetes_base.namespace_name
  zipkin_config        = var.zipkin_config
}

# Módulo de microservicios - Fase 1: Service Discovery
module "service_discovery" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "service-discovery" = var.microservices["service-discovery"]
  }
  dependencies                = [module.monitoring.zipkin_service_name]
}

# Esperar a que Service Discovery esté listo
resource "time_sleep" "wait_for_service_discovery" {
  depends_on = [module.service_discovery]
  create_duration = "120s"
}

# Módulo de microservicios - Fase 2: Cloud Config
module "cloud_config" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "cloud-config" = var.microservices["cloud-config"]
  }
  dependencies                = [time_sleep.wait_for_service_discovery]
}

# Esperar a que Cloud Config esté listo
resource "time_sleep" "wait_for_cloud_config" {
  depends_on = [module.cloud_config]
  create_duration = "90s"
}

# Módulo de microservicios - Fase 3: API Gateway
module "api_gateway" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "api-gateway" = var.microservices["api-gateway"]
  }
  dependencies                = [time_sleep.wait_for_cloud_config]
}

# Esperar a que API Gateway esté listo
resource "time_sleep" "wait_for_api_gateway" {
  depends_on = [module.api_gateway]
  create_duration = "60s"
}

# Módulo de microservicios - Fase 4: Resto de microservicios
module "business_services" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "user-service"      = var.microservices["user-service"]
    "product-service"   = var.microservices["product-service"]
    "order-service"     = var.microservices["order-service"]
    "payment-service"   = var.microservices["payment-service"]
    "shipping-service"  = var.microservices["shipping-service"]
    "favourite-service" = var.microservices["favourite-service"]
    "proxy-client"      = var.microservices["proxy-client"]
  }
  dependencies                = [time_sleep.wait_for_api_gateway]
} 