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

    # Configuración correcta de Cloud Config (NO localhost)
    SPRING_CLOUD_CONFIG_URI = "http://cloud-config:9296"
    SPRING_CLOUD_CONFIG_FAIL_FAST = "false"
    
    # Configuración base H2 para todos los microservicios de negocio
    SPRING_DATASOURCE_URL = "jdbc:h2:mem:testdb"
    SPRING_DATASOURCE_DRIVER_CLASS_NAME = "org.h2.Driver"
    SPRING_DATASOURCE_USERNAME = "sa"
    SPRING_DATASOURCE_PASSWORD = ""
    SPRING_H2_CONSOLE_ENABLED = "true"
    SPRING_JPA_HIBERNATE_DDL_AUTO = "create-drop"
    SPRING_JPA_SHOW_SQL = "false"
    SPRING_JPA_DATABASE_PLATFORM = "org.hibernate.dialect.H2Dialect"
    
    # Configuración Eureka para microservicios cliente
    EUREKA_CLIENT_SERVICE_URL_DEFAULTZONE = "http://service-discovery:8761/eureka/"
    EUREKA_CLIENT_REGISTER_WITH_EUREKA = "true"
    EUREKA_CLIENT_FETCH_REGISTRY = "true"
    EUREKA_INSTANCE_PREFER_IP_ADDRESS = "true"
    
    # Management endpoints
    MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE = "health,info,metrics"
    MANAGEMENT_HEALTH_DB_ENABLED = "false"
    MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED = "true"
    MANAGEMENT_HEALTH_LIVENESSSTATE_ENABLED = "true"
    MANAGEMENT_HEALTH_READINESSSTATE_ENABLED = "true"
    
    # Zipkin
    SPRING_ZIPKIN_BASE_URL = "http://zipkin:9411/"
    
    # Configuración específica para Service Discovery (Eureka Server)
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

    # Configuración específica para Proxy Client
    SPRING_APPLICATION_JSON_PROXY_CLIENT = jsonencode({
      server = {
        port = 8900
      }
      spring = {
        application = {
          name = "PROXY-CLIENT"
        }
        cloud = {
          config = {
            uri = "http://cloud-config:9296"
            enabled = true
            fail-fast = false
          }
        }
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
          hostname = "proxy-client"
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
      # URLs de los microservicios
      user-service = {
        url = "http://user-service:8700"
      }
      product-service = {
        url = "http://product-service:8500"
      }
      order-service = {
        url = "http://order-service:8300"
      }
      payment-service = {
        url = "http://payment-service:8400"
      }
      shipping-service = {
        url = "http://shipping-service:8600"
      }
      favourite-service = {
        url = "http://favourite-service:8800"
      }
    })

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
        application = {
          name = "USER-SERVICE"
        }
        datasource = {
          url = "jdbc:h2:mem:userdb"
          driver-class-name = "org.h2.Driver"
          username = "sa"
          password = ""
        }
        h2 = {
          console = {
            enabled = true
          }
        }
        jpa = {
          hibernate = {
            "ddl-auto" = "create-drop"
          }
          "show-sql" = false
          database-platform = "org.hibernate.dialect.H2Dialect"
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
          "register-with-eureka" = true
          "fetch-registry" = true
        }
        instance = {
          "prefer-ip-address" = true
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
        health = {
          db = {
            enabled = false
          }
        }
      }
    })

    "product-service-dev.yml" = yamlencode({
      server = {
        port = 8500
      }
      spring = {
        application = {
          name = "PRODUCT-SERVICE"
        }
        datasource = {
          url = "jdbc:h2:mem:productdb"
          driver-class-name = "org.h2.Driver"
          username = "sa"
          password = ""
        }
        h2 = {
          console = {
            enabled = true
          }
        }
        jpa = {
          hibernate = {
            "ddl-auto" = "create-drop"
          }
          "show-sql" = false
          database-platform = "org.hibernate.dialect.H2Dialect"
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
          "register-with-eureka" = true
          "fetch-registry" = true
        }
        instance = {
          "prefer-ip-address" = true
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
        health = {
          db = {
            enabled = false
          }
        }
      }
    })

    "order-service-dev.yml" = yamlencode({
      server = {
        port = 8300
      }
      spring = {
        application = {
          name = "ORDER-SERVICE"
        }
        datasource = {
          url = "jdbc:h2:mem:orderdb"
          driver-class-name = "org.h2.Driver"
          username = "sa"
          password = ""
        }
        h2 = {
          console = {
            enabled = true
          }
        }
        jpa = {
          hibernate = {
            "ddl-auto" = "create-drop"
          }
          "show-sql" = false
          database-platform = "org.hibernate.dialect.H2Dialect"
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
          "register-with-eureka" = true
          "fetch-registry" = true
        }
        instance = {
          "prefer-ip-address" = true
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
        health = {
          db = {
            enabled = false
          }
        }
      }
    })

    "payment-service-dev.yml" = yamlencode({
      server = {
        port = 8400
      }
      spring = {
        application = {
          name = "PAYMENT-SERVICE"
        }
        datasource = {
          url = "jdbc:h2:mem:paymentdb"
          driver-class-name = "org.h2.Driver"
          username = "sa"
          password = ""
        }
        h2 = {
          console = {
            enabled = true
          }
        }
        jpa = {
          hibernate = {
            "ddl-auto" = "create-drop"
          }
          "show-sql" = false
          database-platform = "org.hibernate.dialect.H2Dialect"
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
          "register-with-eureka" = true
          "fetch-registry" = true
        }
        instance = {
          "prefer-ip-address" = true
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
        health = {
          db = {
            enabled = false
          }
        }
      }
    })

    "shipping-service-dev.yml" = yamlencode({
      server = {
        port = 8600
      }
      spring = {
        application = {
          name = "SHIPPING-SERVICE"
        }
        datasource = {
          url = "jdbc:h2:mem:shippingdb"
          driver-class-name = "org.h2.Driver"
          username = "sa"
          password = ""
        }
        h2 = {
          console = {
            enabled = true
          }
        }
        jpa = {
          hibernate = {
            "ddl-auto" = "create-drop"
          }
          "show-sql" = false
          database-platform = "org.hibernate.dialect.H2Dialect"
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
          "register-with-eureka" = true
          "fetch-registry" = true
        }
        instance = {
          "prefer-ip-address" = true
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
        health = {
          db = {
            enabled = false
          }
        }
      }
    })

    "favourite-service-dev.yml" = yamlencode({
      server = {
        port = 8800
      }
      spring = {
        application = {
          name = "FAVOURITE-SERVICE"
        }
        datasource = {
          url = "jdbc:h2:mem:favouritedb"
          driver-class-name = "org.h2.Driver"
          username = "sa"
          password = ""
        }
        h2 = {
          console = {
            enabled = true
          }
        }
        jpa = {
          hibernate = {
            "ddl-auto" = "create-drop"
          }
          "show-sql" = false
          database-platform = "org.hibernate.dialect.H2Dialect"
        }
      }
      eureka = {
        client = {
          "service-url" = {
            defaultZone = "http://service-discovery:8761/eureka/"
          }
          "register-with-eureka" = true
          "fetch-registry" = true
        }
        instance = {
          "prefer-ip-address" = true
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
        health = {
          db = {
            enabled = false
          }
        }
      }
    })
  }

  depends_on = [kubernetes_namespace.ecommerce]
} 