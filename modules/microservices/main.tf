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

          # Configuración específica para Service Discovery
          dynamic "env" {
            for_each = each.key == "service-discovery" ? [1] : []
            content {
              name  = "SPRING_APPLICATION_JSON"
              value_from {
                config_map_key_ref {
                  name = var.config_map_name
                  key  = "SPRING_APPLICATION_JSON_EUREKA_SERVER"
                }
              }
            }
          }

          # Configuración de Eureka y Spring Cloud Config usando SPRING_APPLICATION_JSON (mayor prioridad)
          dynamic "env" {
            for_each = contains(["cloud-config", "proxy-client", "service-discovery"], each.key) ? [] : [1]
            content {
              name  = "SPRING_APPLICATION_JSON"
              value = jsonencode({
                server = {
                  port = each.value.target_port
                }
                eureka = {
                  client = {
                    enabled = true
                    register-with-eureka = true
                    fetch-registry = true
                    service-url = {
                      defaultZone = "http://service-discovery:8761/eureka/"
                    }
                  }
                  instance = {
                    prefer-ip-address = false
                    hostname = each.key
                  }
                }
                spring = {
                  cloud = {
                    config = {
                      uri = "http://cloud-config:9296"
                      enabled = true
                      fail-fast = false
                    }
                  }
                  config = {
                    import = "configserver:http://cloud-config:9296"
                  }
                }
              })
            }
          }

          # Variables adicionales para Spring Cloud Config (máxima prioridad)
          dynamic "env" {
            for_each = contains(["cloud-config", "proxy-client", "service-discovery"], each.key) ? [] : [1]
            content {
              name  = "SPRING_CONFIG_IMPORT"
              value = "configserver:http://cloud-config:9296"
            }
          }

          # Variables de entorno de Eureka para microservicios (como respaldo)
          dynamic "env" {
            for_each = contains(["service-discovery", "cloud-config", "proxy-client"], each.key) ? [] : [1]
            content {
              name  = "EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE"
              value = "http://service-discovery:8761/eureka/"
            }
          }

          dynamic "env" {
            for_each = contains(["service-discovery", "cloud-config", "proxy-client"], each.key) ? [] : [1]
            content {
              name  = "EUREKA_CLIENT_ENABLED"
              value = "true"
            }
          }

          dynamic "env" {
            for_each = contains(["service-discovery", "cloud-config", "proxy-client"], each.key) ? [] : [1]
            content {
              name  = "EUREKA_CLIENT_REGISTER_WITH_EUREKA"
              value = "true"
            }
          }

          dynamic "env" {
            for_each = contains(["service-discovery", "cloud-config", "proxy-client"], each.key) ? [] : [1]
            content {
              name  = "EUREKA_CLIENT_FETCH_REGISTRY"
              value = "true"
            }
          }

          dynamic "env" {
            for_each = contains(["service-discovery", "cloud-config", "proxy-client"], each.key) ? [] : [1]
            content {
              name  = "EUREKA_INSTANCE_PREFER_IP_ADDRESS"
              value = "false"
            }
          }

          dynamic "env" {
            for_each = contains(["service-discovery", "cloud-config", "proxy-client"], each.key) ? [] : [1]
            content {
              name  = "EUREKA_INSTANCE_HOSTNAME"
              value = each.key
            }
          }

          # Variables de entorno de Spring Cloud Config para microservicios
          dynamic "env" {
            for_each = contains(["service-discovery", "cloud-config", "proxy-client"], each.key) ? [] : [1]
            content {
              name  = "SPRING_CLOUD_CONFIG_URI"
              value = "http://cloud-config:9296"
            }
          }

          dynamic "env" {
            for_each = contains(["service-discovery", "cloud-config", "proxy-client"], each.key) ? [] : [1]
            content {
              name  = "SPRING_CLOUD_CONFIG_ENABLED"
              value = "true"
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

          # Startup probe - especialmente importante para service-discovery
          startup_probe {
            http_get {
              path = each.key == "service-discovery" ? "/actuator/health/readiness" : (contains(["cloud-config", "api-gateway"], each.key) ? each.value.health_check_path : "/${each.key}${each.value.health_check_path}")
              port = each.value.target_port
            }
            initial_delay_seconds = each.key == "service-discovery" ? 30 : 45
            period_seconds        = 10
            timeout_seconds       = 15
            failure_threshold     = each.key == "service-discovery" ? 30 : 40
          }

          liveness_probe {
            http_get {
              path = each.key == "service-discovery" ? "/actuator/health/liveness" : (contains(["cloud-config", "api-gateway"], each.key) ? each.value.health_check_path : "/${each.key}${each.value.health_check_path}")
              port = each.value.target_port
            }
            initial_delay_seconds = each.key == "service-discovery" ? 180 : (each.key == "cloud-config" ? 120 : 240)
            period_seconds        = 30
            timeout_seconds       = each.key == "service-discovery" ? 15 : 15
            failure_threshold     = each.key == "service-discovery" ? 6 : 8
          }

          readiness_probe {
            http_get {
              path = each.key == "service-discovery" ? "/actuator/health/readiness" : (contains(["cloud-config", "api-gateway"], each.key) ? each.value.health_check_path : "/${each.key}${each.value.health_check_path}")
              port = each.value.target_port
            }
            initial_delay_seconds = each.key == "service-discovery" ? 90 : (each.key == "cloud-config" ? 60 : 180)
            period_seconds        = 15
            timeout_seconds       = each.key == "service-discovery" ? 12 : 12
            failure_threshold     = each.key == "service-discovery" ? 5 : 6
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