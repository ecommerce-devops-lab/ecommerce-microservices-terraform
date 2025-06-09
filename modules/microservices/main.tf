# Deployment genérico para microservicios
resource "kubernetes_deployment" "microservice" {
  for_each = var.microservices

  metadata {
    name      = each.key
    namespace = var.namespace
    labels = {
      app = each.key
    }
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = {
        app = each.key
      }
    }

    template {
      metadata {
        labels = {
          app = each.key
        }
      }

      spec {
        container {
          image = "${var.container_registry_hostname}/${var.project_id}/${each.key}:${var.image_tag}"
          name  = each.key

          port {
            container_port = each.value.target_port
            protocol       = "TCP"
          }

          resources {
            limits = {
              memory = each.value.memory_limit
              cpu    = each.value.cpu_limit
            }
            requests = {
              memory = each.value.memory_request
              cpu    = each.value.cpu_request
            }
          }

          env_from {
            config_map_ref {
              name = var.config_map_name
            }
          }

          # Configuración específica para cloud-config
          dynamic "volume_mount" {
            for_each = each.key == "cloud-config" ? [1] : []
            content {
              name       = "cloud-config-volume"
              mount_path = "/config"
            }
          }

          liveness_probe {
            http_get {
              path = each.value.health_check_path
              port = each.value.target_port
            }
            initial_delay_seconds = each.key == "service-discovery" ? 120 : (each.key == "cloud-config" ? 90 : 180)
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = each.value.health_check_path
              port = each.value.target_port
            }
            initial_delay_seconds = each.key == "service-discovery" ? 60 : (each.key == "cloud-config" ? 45 : 120)
            period_seconds        = 15
            timeout_seconds       = 8
            failure_threshold     = 3
          }
        }

        # Volumen específico para cloud-config
        dynamic "volume" {
          for_each = each.key == "cloud-config" ? [1] : []
          content {
            name = "cloud-config-volume"
            config_map {
              name = var.cloud_config_map_name
            }
          }
        }
      }
    }
  }

  depends_on = [var.dependencies]
}

# Servicio genérico para microservicios
resource "kubernetes_service" "microservice" {
  for_each = var.microservices

  metadata {
    name      = each.key
    namespace = var.namespace
    labels = {
      app = each.key
    }
  }

  spec {
    selector = {
      app = each.key
    }

    port {
      port        = each.value.port
      target_port = each.value.target_port
      protocol    = "TCP"
    }

    type = each.value.service_type
  }

  depends_on = [kubernetes_deployment.microservice]
} 