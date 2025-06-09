# Crear namespace
resource "kubernetes_namespace" "ecommerce" {
  metadata {
    name = var.namespace
  }
  
  depends_on = [time_sleep.wait_for_cluster]
}

# ConfigMap para la configuración de los microservicios
resource "kubernetes_config_map" "ecommerce_config" {
  metadata {
    name      = "ecommerce-config"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  data = {
    SPRING_PROFILES_ACTIVE = "native"
    JAVA_OPTS = "-Xms256m -Xmx512m"

    # Configuración JSON que sobrescribe todo
    SPRING_APPLICATION_JSON = jsonencode({
      eureka = {
        client = {
          serviceUrl = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
          register-with-eureka = true
          fetch-registry = true
        }
        instance = {
          prefer-ip-address = true
        }
      }
    })

    # Cloud Config
    SPRING_CLOUD_CONFIG_URI = "http://cloud-config:9296"
    SPRING_ZIPKIN_BASE_URL = "http://zipkin:9411/"

    # URLs de servicios para la comunicación interna
    USER_SERVICE_HOST = "http://user-service:8700"
    PRODUCT_SERVICE_HOST = "http://product-service:8500"
    ORDER_SERVICE_HOST = "http://order-service:8300"
    FAVOURITE_SERVICE_HOST = "http://favourite-service:8800"
    SHIPPING_SERVICE_HOST = "http://shipping-service:8600"
    PAYMENT_SERVICE_HOST = "http://payment-service:8400"
  }
}

# ConfigMap para las configuraciones nativas de cloud-config
resource "kubernetes_config_map" "cloud_config_files" {
  metadata {
    name      = "cloud-config-files"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  data = {
    "application.yml" = yamlencode({
      server = {
        port = 9296
      }
      spring = {
        application = {
          name = "CLOUD-CONFIG"
        }
        cloud = {
          config = {
            server = {
              native = {
                "search-locations" = "classpath:/config/"
              }
            }
          }
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
        }
      }
      management = {
        endpoints = {
          web = {
            exposure = {
              include = "*"
            }
          }
        }
        health = {
          "show-details" = "always"
        }
      }
    })

    "user-service-dev.yml" = yamlencode({
      server = {
        port = 8700
      }
      spring = {
        datasource = {
          url = "jdbc:postgresql://localhost:5432/userdb"
          username = "admin"
          password = "admin"
        }
        jpa = {
          hibernate = {
            "ddl-auto" = "update"
          }
          "show-sql" = true
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
        }
      }
    })

    "product-service-dev.yml" = yamlencode({
      server = {
        port = 8500
      }
      spring = {
        datasource = {
          url = "jdbc:postgresql://localhost:5432/productdb"
          username = "admin"
          password = "admin"
        }
        jpa = {
          hibernate = {
            "ddl-auto" = "update"
          }
          "show-sql" = true
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
        }
      }
    })

    "order-service-dev.yml" = yamlencode({
      server = {
        port = 8300
      }
      spring = {
        datasource = {
          url = "jdbc:postgresql://localhost:5432/orderdb"
          username = "admin"
          password = "admin"
        }
        jpa = {
          hibernate = {
            "ddl-auto" = "update"
          }
          "show-sql" = true
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
        }
      }
    })
  }

  depends_on = [kubernetes_namespace.ecommerce]
}

# 1. ZIPKIN - Primer servicio a desplegar
resource "kubernetes_deployment" "zipkin" {
  metadata {
    name      = "zipkin"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
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
          image             = var.zipkin_config.image
          name              = "zipkin"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.zipkin_config.target_port
          }

          resources {
            requests = {
              memory = var.zipkin_config.memory_request
              cpu    = var.zipkin_config.cpu_request
            }
            limits = {
              memory = var.zipkin_config.memory_limit
              cpu    = var.zipkin_config.cpu_limit
            }
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
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.zipkin_config.health_check_path
              port = var.zipkin_config.target_port
            }
            initial_delay_seconds = 60
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.ecommerce_config]
}

resource "kubernetes_service" "zipkin" {
  metadata {
    name      = "zipkin"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "zipkin"
    }

    port {
      port        = var.zipkin_config.port
      target_port = var.zipkin_config.target_port
    }

    type = var.zipkin_config.service_type
  }

  depends_on = [kubernetes_deployment.zipkin]
}

# 2. SERVICE-DISCOVERY - Depende de Zipkin
resource "kubernetes_deployment" "service_discovery" {
  metadata {
    name      = "service-discovery"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "service-discovery"
    }
  }

  spec {
    replicas = var.microservices["service-discovery"].replicas

    selector {
      match_labels = {
        app = "service-discovery"
      }
    }

    template {
      metadata {
        labels = {
          app = "service-discovery"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/service-discovery:${var.image_tag}"
          name              = "service-discovery"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["service-discovery"].target_port
          }

          env {
            name  = "SPRING_PROFILES_ACTIVE"
            value = "prod"
          }
          
          env {
            name  = "EUREKA_CLIENT_REGISTER_WITH_EUREKA"
            value = "false"
          }
          
          env {
            name  = "EUREKA_CLIENT_FETCH_REGISTRY"
            value = "false"
          }

          env {
            name  = "SPRING_ZIPKIN_BASE_URL"
            value = "http://zipkin:9411/"
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Xms256m -Xmx512m"
          }

          # env_from {
          #   config_map_ref {
          #     name = kubernetes_config_map.ecommerce_config.metadata[0].name
          #   }
          # }

          resources {
            requests = {
              memory = var.microservices["service-discovery"].memory_request
              cpu    = var.microservices["service-discovery"].cpu_request
            }
            limits = {
              memory = var.microservices["service-discovery"].memory_limit
              cpu    = var.microservices["service-discovery"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["service-discovery"].health_check_path
              port = var.microservices["service-discovery"].target_port
            }
            initial_delay_seconds = 90
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["service-discovery"].health_check_path
              port = var.microservices["service-discovery"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.zipkin]
}

resource "kubernetes_service" "service_discovery" {
  metadata {
    name      = "service-discovery"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "service-discovery"
    }

    port {
      port        = var.microservices["service-discovery"].port
      target_port = var.microservices["service-discovery"].target_port
    }

    type = var.microservices["service-discovery"].service_type
  }

  depends_on = [kubernetes_deployment.service_discovery]
}

# 3. CLOUD-CONFIG - Depende de Service Discovery
resource "kubernetes_deployment" "cloud_config" {
  metadata {
    name      = "cloud-config"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "cloud-config"
    }
  }

  spec {
    replicas = var.microservices["cloud-config"].replicas

    selector {
      match_labels = {
        app = "cloud-config"
      }
    }

    template {
      metadata {
        labels = {
          app = "cloud-config"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/cloud-config:${var.image_tag}"
          name              = "cloud-config"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["cloud-config"].target_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ecommerce_config.metadata[0].name
            }
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/home/app/config"
          }

          resources {
            requests = {
              memory = var.microservices["cloud-config"].memory_request
              cpu    = var.microservices["cloud-config"].cpu_request
            }
            limits = {
              memory = var.microservices["cloud-config"].memory_limit
              cpu    = var.microservices["cloud-config"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["cloud-config"].health_check_path
              port = var.microservices["cloud-config"].target_port
            }
            initial_delay_seconds = 90
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["cloud-config"].health_check_path
              port = var.microservices["cloud-config"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.cloud_config_files.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.service_discovery]
}

resource "kubernetes_service" "cloud_config" {
  metadata {
    name      = "cloud-config"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "cloud-config"
    }

    port {
      port        = var.microservices["cloud-config"].port
      target_port = var.microservices["cloud-config"].target_port
    }

    type = var.microservices["cloud-config"].service_type
  }

  depends_on = [kubernetes_deployment.cloud_config]
}

# 4. API-GATEWAY - Depende de Cloud Config
resource "kubernetes_deployment" "api_gateway" {
  metadata {
    name      = "api-gateway"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "api-gateway"
    }
  }

  spec {
    replicas = var.microservices["api-gateway"].replicas

    selector {
      match_labels = {
        app = "api-gateway"
      }
    }

    template {
      metadata {
        labels = {
          app = "api-gateway"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/api-gateway:${var.image_tag}"
          name              = "api-gateway"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["api-gateway"].target_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ecommerce_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = var.microservices["api-gateway"].memory_request
              cpu    = var.microservices["api-gateway"].cpu_request
            }
            limits = {
              memory = var.microservices["api-gateway"].memory_limit
              cpu    = var.microservices["api-gateway"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["api-gateway"].health_check_path
              port = var.microservices["api-gateway"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["api-gateway"].health_check_path
              port = var.microservices["api-gateway"].target_port
            }
            initial_delay_seconds = 150
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.cloud_config]
}

resource "kubernetes_service" "api_gateway" {
  metadata {
    name      = "api-gateway"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "api-gateway"
    }

    port {
      port        = var.microservices["api-gateway"].port
      target_port = var.microservices["api-gateway"].target_port
    }

    type = var.microservices["api-gateway"].service_type
  }

  depends_on = [kubernetes_deployment.api_gateway]
}

# 5. USER-SERVICE - Depende de API Gateway
resource "kubernetes_deployment" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "user-service"
    }
  }

  spec {
    replicas = var.microservices["user-service"].replicas

    selector {
      match_labels = {
        app = "user-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "user-service"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/user-service:${var.image_tag}"
          name              = "user-service"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["user-service"].target_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ecommerce_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = var.microservices["user-service"].memory_request
              cpu    = var.microservices["user-service"].cpu_request
            }
            limits = {
              memory = var.microservices["user-service"].memory_limit
              cpu    = var.microservices["user-service"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["user-service"].health_check_path
              port = var.microservices["user-service"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["user-service"].health_check_path
              port = var.microservices["user-service"].target_port
            }
            initial_delay_seconds = 150
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.api_gateway]
}

resource "kubernetes_service" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "user-service"
    }

    port {
      port        = var.microservices["user-service"].port
      target_port = var.microservices["user-service"].target_port
    }

    type = var.microservices["user-service"].service_type
  }

  depends_on = [kubernetes_deployment.user_service]
}

# 6. PRODUCT-SERVICE - Depende de User Service
resource "kubernetes_deployment" "product_service" {
  metadata {
    name      = "product-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "product-service"
    }
  }

  spec {
    replicas = var.microservices["product-service"].replicas

    selector {
      match_labels = {
        app = "product-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "product-service"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/product-service:${var.image_tag}"
          name              = "product-service"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["product-service"].target_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ecommerce_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = var.microservices["product-service"].memory_request
              cpu    = var.microservices["product-service"].cpu_request
            }
            limits = {
              memory = var.microservices["product-service"].memory_limit
              cpu    = var.microservices["product-service"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["product-service"].health_check_path
              port = var.microservices["product-service"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["product-service"].health_check_path
              port = var.microservices["product-service"].target_port
            }
            initial_delay_seconds = 150
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.user_service]
}

resource "kubernetes_service" "product_service" {
  metadata {
    name      = "product-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "product-service"
    }

    port {
      port        = var.microservices["product-service"].port
      target_port = var.microservices["product-service"].target_port
    }

    type = var.microservices["product-service"].service_type
  }

  depends_on = [kubernetes_deployment.product_service]
}

# 7. ORDER-SERVICE - Depende de Product Service
resource "kubernetes_deployment" "order_service" {
  metadata {
    name      = "order-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "order-service"
    }
  }

  spec {
    replicas = var.microservices["order-service"].replicas

    selector {
      match_labels = {
        app = "order-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "order-service"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/order-service:${var.image_tag}"
          name              = "order-service"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["order-service"].target_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ecommerce_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = var.microservices["order-service"].memory_request
              cpu    = var.microservices["order-service"].cpu_request
            }
            limits = {
              memory = var.microservices["order-service"].memory_limit
              cpu    = var.microservices["order-service"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["order-service"].health_check_path
              port = var.microservices["order-service"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["order-service"].health_check_path
              port = var.microservices["order-service"].target_port
            }
            initial_delay_seconds = 150
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.product_service]
}

resource "kubernetes_service" "order_service" {
  metadata {
    name      = "order-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "order-service"
    }

    port {
      port        = var.microservices["order-service"].port
      target_port = var.microservices["order-service"].target_port
    }

    type = var.microservices["order-service"].service_type
  }

  depends_on = [kubernetes_deployment.order_service]
}

# 8. PAYMENT-SERVICE - Depende de Order Service
resource "kubernetes_deployment" "payment_service" {
  metadata {
    name      = "payment-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "payment-service"
    }
  }

  spec {
    replicas = var.microservices["payment-service"].replicas

    selector {
      match_labels = {
        app = "payment-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "payment-service"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/payment-service:${var.image_tag}"
          name              = "payment-service"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["payment-service"].target_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ecommerce_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = var.microservices["payment-service"].memory_request
              cpu    = var.microservices["payment-service"].cpu_request
            }
            limits = {
              memory = var.microservices["payment-service"].memory_limit
              cpu    = var.microservices["payment-service"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["payment-service"].health_check_path
              port = var.microservices["payment-service"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["payment-service"].health_check_path
              port = var.microservices["payment-service"].target_port
            }
            initial_delay_seconds = 150
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.order_service]
}

resource "kubernetes_service" "payment_service" {
  metadata {
    name      = "payment-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "payment-service"
    }

    port {
      port        = var.microservices["payment-service"].port
      target_port = var.microservices["payment-service"].target_port
    }

    type = var.microservices["payment-service"].service_type
  }

  depends_on = [kubernetes_deployment.payment_service]
}

# 9. SHIPPING-SERVICE - Depende de Payment Service
resource "kubernetes_deployment" "shipping_service" {
  metadata {
    name      = "shipping-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "shipping-service"
    }
  }

  spec {
    replicas = var.microservices["shipping-service"].replicas

    selector {
      match_labels = {
        app = "shipping-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "shipping-service"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/shipping-service:${var.image_tag}"
          name              = "shipping-service"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["shipping-service"].target_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ecommerce_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = var.microservices["shipping-service"].memory_request
              cpu    = var.microservices["shipping-service"].cpu_request
            }
            limits = {
              memory = var.microservices["shipping-service"].memory_limit
              cpu    = var.microservices["shipping-service"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["shipping-service"].health_check_path
              port = var.microservices["shipping-service"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["shipping-service"].health_check_path
              port = var.microservices["shipping-service"].target_port
            }
            initial_delay_seconds = 150
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.payment_service]
}

resource "kubernetes_service" "shipping_service" {
  metadata {
    name      = "shipping-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "shipping-service"
    }

    port {
      port        = var.microservices["shipping-service"].port
      target_port = var.microservices["shipping-service"].target_port
    }

    type = var.microservices["shipping-service"].service_type
  }

  depends_on = [kubernetes_deployment.shipping_service]
}

# 10. FAVOURITE-SERVICE - Depende de Shipping Service
resource "kubernetes_deployment" "favourite_service" {
  metadata {
    name      = "favourite-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "favourite-service"
    }
  }

  spec {
    replicas = var.microservices["favourite-service"].replicas

    selector {
      match_labels = {
        app = "favourite-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "favourite-service"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/favourite-service:${var.image_tag}"
          name              = "favourite-service"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["favourite-service"].target_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ecommerce_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = var.microservices["favourite-service"].memory_request
              cpu    = var.microservices["favourite-service"].cpu_request
            }
            limits = {
              memory = var.microservices["favourite-service"].memory_limit
              cpu    = var.microservices["favourite-service"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["favourite-service"].health_check_path
              port = var.microservices["favourite-service"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["favourite-service"].health_check_path
              port = var.microservices["favourite-service"].target_port
            }
            initial_delay_seconds = 150
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.shipping_service]
}

resource "kubernetes_service" "favourite_service" {
  metadata {
    name      = "favourite-service"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "favourite-service"
    }

    port {
      port        = var.microservices["favourite-service"].port
      target_port = var.microservices["favourite-service"].target_port
    }

    type = var.microservices["favourite-service"].service_type
  }

  depends_on = [kubernetes_deployment.favourite_service]
}

# 11. PROXY-CLIENT - Último servicio, depende de Favourite Service
resource "kubernetes_deployment" "proxy_client" {
  metadata {
    name      = "proxy-client"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
    labels = {
      app = "proxy-client"
    }
  }

  spec {
    replicas = var.microservices["proxy-client"].replicas

    selector {
      match_labels = {
        app = "proxy-client"
      }
    }

    template {
      metadata {
        labels = {
          app = "proxy-client"
        }
      }

      spec {
        container {
          image             = "${var.container_registry_hostname}/${var.project_id}/proxy-client:${var.image_tag}"
          name              = "proxy-client"
          image_pull_policy = "IfNotPresent"

          port {
            container_port = var.microservices["proxy-client"].target_port
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.ecommerce_config.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = var.microservices["proxy-client"].memory_request
              cpu    = var.microservices["proxy-client"].cpu_request
            }
            limits = {
              memory = var.microservices["proxy-client"].memory_limit
              cpu    = var.microservices["proxy-client"].cpu_limit
            }
          }

          readiness_probe {
            http_get {
              path = var.microservices["proxy-client"].health_check_path
              port = var.microservices["proxy-client"].target_port
            }
            initial_delay_seconds = 120
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 5
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = var.microservices["proxy-client"].health_check_path
              port = var.microservices["proxy-client"].target_port
            }
            initial_delay_seconds = 150
            period_seconds        = 30
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.favourite_service]
}

resource "kubernetes_service" "proxy_client" {
  metadata {
    name      = "proxy-client"
    namespace = kubernetes_namespace.ecommerce.metadata[0].name
  }

  spec {
    selector = {
      app = "proxy-client"
    }

    port {
      port        = var.microservices["proxy-client"].port
      target_port = var.microservices["proxy-client"].target_port
    }

    type = var.microservices["proxy-client"].service_type
  }

  depends_on = [kubernetes_deployment.proxy_client]
} 