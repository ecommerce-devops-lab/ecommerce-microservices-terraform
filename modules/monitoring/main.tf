# ZIPKIN - Servicio de monitoring
resource "kubernetes_deployment" "zipkin" {
  metadata {
    name      = "zipkin"
    namespace = var.namespace
    labels = {
      app = "zipkin"
    }
  }

  spec {
    replicas = var.zipkin_config.replicas

    selector {
      match_labels = {
        app = "zipkin"
      }
    }

    template {
      metadata {
        labels = {
          app = "zipkin"
        }
      }

      spec {
        container {
          image = var.zipkin_config.image
          name  = "zipkin"

          port {
            container_port = var.zipkin_config.target_port
            protocol       = "TCP"
          }

          resources {
            limits = {
              memory = var.zipkin_config.memory_limit
              cpu    = var.zipkin_config.cpu_limit
            }
            requests = {
              memory = var.zipkin_config.memory_request
              cpu    = var.zipkin_config.cpu_request
            }
          }

          liveness_probe {
            http_get {
              path = var.zipkin_config.health_check_path
              port = var.zipkin_config.target_port
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = var.zipkin_config.health_check_path
              port = var.zipkin_config.target_port
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [var.namespace_dependency]
}

resource "kubernetes_service" "zipkin" {
  metadata {
    name      = "zipkin"
    namespace = var.namespace
    labels = {
      app = "zipkin"
    }
  }

  spec {
    selector = {
      app = "zipkin"
    }

    port {
      port        = var.zipkin_config.port
      target_port = var.zipkin_config.target_port
      protocol    = "TCP"
    }

    type = var.zipkin_config.service_type
  }

  depends_on = [kubernetes_deployment.zipkin]
} 