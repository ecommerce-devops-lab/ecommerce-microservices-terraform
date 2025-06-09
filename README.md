# Infraestructura de Microservicios E-commerce en GCP

Este directorio contiene la configuración de Terraform para desplegar una arquitectura de microservicios de e-commerce en Google Cloud Platform (GCP) usando Google Kubernetes Engine (GKE).

## Arquitectura

La infraestructura incluye:

- **Clúster GKE** con nodos de 8 GB de RAM (e2-standard-2)
- **VPC personalizada** con subredes para el clúster
- **Despliegue ordenado con dependencias** basado en health checks
- **Servicios públicos** con LoadBalancer para acceso externo:
  - API Gateway (puerto 8080)
  - Service Discovery / Eureka (puerto 8761)
  - Zipkin (puerto 9411)

### Orden de Despliegue con Dependencias

Los microservicios se despliegan en el siguiente orden estricto, donde cada uno espera a que el anterior pase sus health checks:

1. **Zipkin** - Trazabilidad distribuida (servicio base)
2. **Service Discovery** - Eureka Server (depende de Zipkin)
3. **Cloud Config Server** - Configuración centralizada (depende de Service Discovery)
4. **API Gateway** - Gateway principal (depende de Cloud Config)
5. **User Service** - Gestión de usuarios (depende de API Gateway)
6. **Product Service** - Gestión de productos (depende de User Service)
7. **Order Service** - Gestión de pedidos (depende de Product Service)
8. **Payment Service** - Procesamiento de pagos (depende de Order Service)
9. **Shipping Service** - Gestión de envíos (depende de Payment Service)
10. **Favourite Service** - Gestión de favoritos (depende de Shipping Service)
11. **Proxy Client** - Cliente proxy (último en desplegarse)

## Prerequisitos

1. **Google Cloud SDK** instalado y configurado
2. **Terraform** >= 1.0 instalado
3. **kubectl** instalado
4. **Proyecto de GCP** activo con facturación habilitada
5. **APIs habilitadas**:
   - Container API
   - Compute Engine API

## Configuración Inicial

### 1. Autenticación con Google Cloud

```bash
# Iniciar sesión en Google Cloud
gcloud auth login

# Configurar el proyecto por defecto
gcloud config set project ecommerce-microservices-back

# Configurar las credenciales de aplicación por defecto
gcloud auth application-default login
```

### 2. Habilitar APIs necesarias

```bash
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
```

### 3. Preparar las imágenes Docker

Antes de desplegar la infraestructura, asegúrese de que las imágenes de los microservicios estén disponibles en Google Container Registry:

```bash
# Ejecutar el script de build y push desde el directorio raíz del proyecto
build-and-push.bat ecommerce-microservices-back
```

## Despliegue

### 1. Inicializar Terraform

```bash
cd microservices-terraform
terraform init
```

### 2. Revisar y personalizar variables (opcional)

```bash
# Copiar el archivo de ejemplo
cp terraform.tfvars.example terraform.tfvars

# Editar las variables según sus necesidades
# Las variables más importantes son:
# - project_id: ID de su proyecto de GCP
# - region: región donde desplegar
# - zone: zona específica
# - cluster_name: nombre del clúster
```

### 3. Planificar el despliegue

```bash
terraform plan
```

### 4. Aplicar la configuración

```bash
terraform apply
```

El proceso tardará aproximadamente 15-20 minutos en completarse debido al despliegue secuencial con dependencias.

### 5. Configurar kubectl

```bash
# Obtener las credenciales del clúster
gcloud container clusters get-credentials ecommerce-microservices-cluster --zone us-central1-a --project ecommerce-microservices-back
```

## Verificación del Despliegue

### Verificar el estado del clúster

```bash
# Ver información del clúster
kubectl cluster-info

# Ver los nodos
kubectl get nodes

# Ver los pods en el namespace ecommerce (deberían aparecer en orden)
kubectl get pods -n ecommerce

# Ver los servicios
kubectl get services -n ecommerce
```

### Obtener IPs externas de servicios públicos

```bash
# Obtener la IP externa del API Gateway
kubectl get service api-gateway -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Obtener la IP externa de Zipkin
kubectl get service zipkin -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Obtener la IP externa del Service Discovery (Eureka)
kubectl get service service-discovery -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Acceder a las interfaces web

Una vez obtenidas las IPs externas:

- **API Gateway**: `http://<EXTERNAL_IP>:8080`
- **Zipkin UI**: `http://<EXTERNAL_IP>:9411`
- **Eureka UI**: `http://<EXTERNAL_IP>:8761`

### Verificar orden de despliegue

```bash
# Ver el orden de creación de los pods
kubectl get pods -n ecommerce --sort-by=.metadata.creationTimestamp

# Ver eventos del namespace para seguir el despliegue
kubectl get events -n ecommerce --sort-by='.lastTimestamp'
```

### Verificar logs de los servicios

```bash
# Ver logs de un microservicio específico
kubectl logs -f deployment/api-gateway -n ecommerce

# Ver logs de todos los pods de un servicio
kubectl logs -l app=user-service -n ecommerce

# Verificar health checks
kubectl describe pod <pod-name> -n ecommerce
```

## Configuración de Variables

### Variables principales

| Variable        | Descripción            | Valor por defecto                 |
| --------------- | ---------------------- | --------------------------------- |
| `project_id`    | ID del proyecto de GCP | `ecommerce-microservices-back`    |
| `region`        | Región de Google Cloud | `us-central1`                     |
| `zone`          | Zona específica        | `us-central1-a`                   |
| `cluster_name`  | Nombre del clúster GKE | `ecommerce-microservices-cluster` |
| `gke_num_nodes` | Número de nodos        | `2`                               |
| `image_tag`     | Tag de las imágenes    | `0.1.0`                           |

### Personalización de microservicios

Puede personalizar la configuración de cada microservicio editando la variable `microservices` en `terraform.tfvars`:

```hcl
microservices = {
  "api-gateway" = {
    port              = 8080
    target_port       = 8080
    replicas          = 2  # Aumentar para alta disponibilidad
    service_type      = "LoadBalancer"
    health_check_path = "/actuator/health"
    memory_request    = "512Mi"
    memory_limit      = "768Mi"
    cpu_request       = "250m"
    cpu_limit         = "500m"
  }
}
```

## Escalamiento

### Escalar manualmente un deployment

```bash
# Escalar el API Gateway a 3 réplicas
kubectl scale deployment api-gateway --replicas=3 -n ecommerce
```

### Escalar el clúster

```bash
# Escalar el node pool a 4 nodos
gcloud container clusters resize ecommerce-microservices-cluster --num-nodes=4 --zone=us-central1-a
```

## Monitoreo y Observabilidad

### Zipkin UI

Zipkin está configurado como LoadBalancer y accesible públicamente:

```bash
# Obtener la IP externa de Zipkin
ZIPKIN_IP=$(kubectl get service zipkin -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Zipkin UI: http://$ZIPKIN_IP:9411"
```

### Eureka Service Discovery UI

Eureka también tiene acceso público:

```bash
# Obtener la IP externa de Eureka
EUREKA_IP=$(kubectl get service service-discovery -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Eureka UI: http://$EUREKA_IP:8761"
```

### Logs de aplicación

```bash
# Ver logs en tiempo real
kubectl logs -f deployment/api-gateway -n ecommerce

# Ver logs de todos los pods de un servicio
kubectl logs -l app=user-service -n ecommerce
```

## Características de Despliegue

### Health Checks Robustos

- **Readiness Probes**: Configurados con umbrales estrictos para garantizar que cada servicio esté completamente listo
- **Liveness Probes**: Monitoreo continuo de la salud de los servicios
- **Dependencias Explícitas**: Cada servicio espera a que el anterior sea completamente funcional

### Servicios Públicos

- **API Gateway**: Punto de entrada principal para todas las APIs
- **Service Discovery**: Interfaz web para monitorear servicios registrados
- **Zipkin**: Dashboard para trazabilidad distribuida y análisis de rendimiento

## Limpieza

Para eliminar toda la infraestructura:

```bash
terraform destroy
```

**⚠️ Advertencia**: Este comando eliminará permanentemente el clúster y todos los recursos asociados.

## Solución de Problemas

### Pods en estado Pending

```bash
# Verificar recursos del clúster
kubectl describe nodes

# Verificar events del namespace
kubectl get events -n ecommerce --sort-by='.lastTimestamp'
```

### Problemas de dependencias

```bash
# Verificar que las dependencias estén listas
kubectl get pods -n ecommerce --sort-by=.metadata.creationTimestamp

# Verificar health checks específicos
kubectl describe pod <pod-name> -n ecommerce
```

### Problemas de conectividad entre servicios

```bash
# Verificar DNS interno
kubectl exec -it deployment/api-gateway -n ecommerce -- nslookup user-service.ecommerce.svc.cluster.local

# Verificar configuración del ConfigMap
kubectl describe configmap ecommerce-config -n ecommerce
```

### ImagePullBackOff

```bash
# Verificar que las imágenes existen en GCR
gcloud container images list --repository=gcr.io/ecommerce-microservices-back

# Verificar permisos del service account
kubectl describe pod <pod-name> -n ecommerce
```

### LoadBalancer no obtiene IP externa

```bash
# Verificar estado del LoadBalancer
kubectl describe service api-gateway -n ecommerce

# Verificar quotas de IP externas
gcloud compute project-info describe --project=ecommerce-microservices-back
```

## Estructura de Archivos

```
microservices-terraform/
├── main.tf                    # Configuración principal de GCP/GKE
├── variables.tf              # Definición de variables
├── kubernetes.tf             # Recursos de Kubernetes con dependencias
├── outputs.tf                # Outputs del despliegue
├── terraform.tfvars.example  # Ejemplo de variables
└── README.md                 # Esta documentación
```

## Contacto y Soporte

Para problemas o mejoras, revisar la documentación de:

- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
