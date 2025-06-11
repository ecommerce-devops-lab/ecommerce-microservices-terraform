# Crear namespace
resource "kubernetes_namespace" "ecommerce" {
  metadata {
    name = var.namespace
  }
  
  depends_on = [var.cluster_dependency]
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

    # Configuración específica para Service Discovery (no se registra a sí mismo)
    SPRING_APPLICATION_JSON_EUREKA_SERVER = jsonencode({
      server = {
        port = 8761
      }
      spring = {
        application = {
          name = "SERVICE-DISCOVERY"
        }
      }
      eureka = {
        client = {
          register-with-eureka = false
          fetch-registry = false
        }
        server = {
          enable-self-preservation = false
          eviction-interval-timer-in-ms = 15000
          response-cache-auto-expiration-in-seconds = 30
        }
        instance = {
          lease-renewal-interval-in-seconds = 30
          lease-expiration-duration-in-seconds = 90
        }
      }
      management = {
        endpoints = {
          web = {
            exposure = {
              include = "health,info,metrics"
            }
          }
        }
        endpoint = {
          health = {
            probes = {
              enabled = true
            }
            show-details = "always"
          }
        }
        health = {
          livenessstate = {
            enabled = true
          }
          readinessstate = {
            enabled = true
          }
        }
      }
      logging = {
        level = {
          "com.netflix.eureka" = "WARN"
          "com.netflix.discovery" = "WARN"
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