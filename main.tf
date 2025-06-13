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
  service_url    = var.service_url
  db_host        = var.db_host
  db_name        = var.db_name
  api_key        = var.api_key
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

# Módulo de microservicios - Fase 4: User Service
module "user_service" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "user-service" = var.microservices["user-service"]
  }
  dependencies                = [time_sleep.wait_for_api_gateway]
}

# Esperar a que User Service esté listo
resource "time_sleep" "wait_for_user_service" {
  depends_on = [module.user_service]
  create_duration = "60s"
}

# Módulo de microservicios - Fase 5: Product Service
module "product_service" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "product-service" = var.microservices["product-service"]
  }
  dependencies                = [time_sleep.wait_for_user_service]
}

# Esperar a que Product Service esté listo
resource "time_sleep" "wait_for_product_service" {
  depends_on = [module.product_service]
  create_duration = "60s"
}

# Módulo de microservicios - Fase 6: Order Service
module "order_service" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "order-service" = var.microservices["order-service"]
  }
  dependencies                = [time_sleep.wait_for_product_service]
}

# Esperar a que Order Service esté listo
resource "time_sleep" "wait_for_order_service" {
  depends_on = [module.order_service]
  create_duration = "60s"
}

# Módulo de microservicios - Fase 7: Payment Service
module "payment_service" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "payment-service" = var.microservices["payment-service"]
  }
  dependencies                = [time_sleep.wait_for_order_service]
}

# Esperar a que Payment Service esté listo
resource "time_sleep" "wait_for_payment_service" {
  depends_on = [module.payment_service]
  create_duration = "60s"
}

# Módulo de microservicios - Fase 8: Shipping Service
module "shipping_service" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "shipping-service" = var.microservices["shipping-service"]
  }
  dependencies                = [time_sleep.wait_for_payment_service]
}

# Esperar a que Shipping Service esté listo
resource "time_sleep" "wait_for_shipping_service" {
  depends_on = [module.shipping_service]
  create_duration = "60s"
}

# Módulo de microservicios - Fase 9: Favourite Service
module "favourite_service" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "favourite-service" = var.microservices["favourite-service"]
  }
  dependencies                = [time_sleep.wait_for_shipping_service]
}

# Esperar a que Favourite Service esté listo
resource "time_sleep" "wait_for_favourite_service" {
  depends_on = [module.favourite_service]
  create_duration = "60s"
}

# Módulo de microservicios - Fase 10: Proxy Client (último)
module "proxy_client" {
  source = "./modules/microservices"

  namespace                   = module.kubernetes_base.namespace_name
  project_id                  = var.project_id
  container_registry_hostname = var.container_registry_hostname
  image_tag                   = var.image_tag
  config_map_name             = module.kubernetes_base.config_map_name
  cloud_config_map_name       = module.kubernetes_base.cloud_config_map_name
  microservices               = {
    "proxy-client" = var.microservices["proxy-client"]
  }
  dependencies                = [time_sleep.wait_for_favourite_service]
} 