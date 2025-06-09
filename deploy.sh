#!/bin/bash

# Script de despliegue para microservicios en GCP
# Autor: Asistente AI
# Fecha: $(date)

set -e  # Salir en caso de error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes coloreados
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar prerequisitos
check_prerequisites() {
    print_status "Verificando prerequisitos..."
    
    # Verificar gcloud
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud no está instalado. Por favor instale Google Cloud SDK."
        exit 1
    fi
    
    # Verificar terraform
    if ! command -v terraform &> /dev/null; then
        print_error "terraform no está instalado. Por favor instale Terraform."
        exit 1
    fi
    
    # Verificar kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl no está instalado. Por favor instale kubectl."
        exit 1
    fi
    
    print_success "Todos los prerequisitos están instalados."
}

# Verificar autenticación con GCP
check_auth() {
    print_status "Verificando autenticación con Google Cloud..."
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "No hay una cuenta activa en gcloud. Ejecute 'gcloud auth login'."
        exit 1
    fi
    
    print_success "Autenticado con Google Cloud."
}

# Verificar proyecto
check_project() {
    local project_id=${1:-"ecommerce-microservices-back"}
    
    print_status "Verificando proyecto: $project_id"
    
    if ! gcloud projects describe "$project_id" &> /dev/null; then
        print_error "El proyecto $project_id no existe o no tiene acceso."
        exit 1
    fi
    
    gcloud config set project "$project_id"
    print_success "Proyecto configurado: $project_id"
}

# Habilitar APIs
enable_apis() {
    print_status "Habilitando APIs necesarias..."
    
    gcloud services enable container.googleapis.com
    gcloud services enable compute.googleapis.com
    
    print_success "APIs habilitadas."
}

# Inicializar Terraform
init_terraform() {
    print_status "Inicializando Terraform..."
    
    terraform init
    
    if [ $? -eq 0 ]; then
        print_success "Terraform inicializado correctamente."
    else
        print_error "Error al inicializar Terraform."
        exit 1
    fi
}

# Planificar despliegue
plan_deployment() {
    print_status "Planificando el despliegue..."
    
    terraform plan
    
    if [ $? -eq 0 ]; then
        print_success "Plan generado correctamente."
    else
        print_error "Error al generar el plan."
        exit 1
    fi
}

# Aplicar configuración
apply_deployment() {
    print_status "Aplicando la configuración..."
    
    terraform apply -auto-approve
    
    if [ $? -eq 0 ]; then
        print_success "Despliegue completado correctamente."
    else
        print_error "Error durante el despliegue."
        exit 1
    fi
}

# Configurar kubectl
configure_kubectl() {
    print_status "Configurando kubectl..."
    
    local cluster_name=${1:-"ecommerce-microservices-cluster"}
    local zone=${2:-"us-central1-a"}
    local project_id=${3:-"ecommerce-microservices-back"}
    
    gcloud container clusters get-credentials "$cluster_name" --zone "$zone" --project "$project_id"
    
    if [ $? -eq 0 ]; then
        print_success "kubectl configurado correctamente."
    else
        print_error "Error al configurar kubectl."
        exit 1
    fi
}

# Verificar despliegue
verify_deployment() {
    print_status "Verificando el despliegue..."
    
    echo ""
    print_status "Estado del clúster:"
    kubectl cluster-info
    
    echo ""
    print_status "Nodos del clúster:"
    kubectl get nodes
    
    echo ""
    print_status "Pods en el namespace ecommerce:"
    kubectl get pods -n ecommerce
    
    echo ""
    print_status "Servicios en el namespace ecommerce:"
    kubectl get services -n ecommerce
    
    print_success "Verificación completada."
}

# Mostrar información de acceso
show_access_info() {
    print_status "Información de acceso a los servicios:"
    
    echo ""
    print_warning "Para obtener las IPs externas de los servicios, ejecute:"
    echo "kubectl get service api-gateway -n ecommerce"
    echo "kubectl get service zipkin -n ecommerce"
    echo "kubectl get service service-discovery -n ecommerce"
    
    echo ""
    print_warning "Para ver logs de un servicio específico:"
    echo "kubectl logs -f deployment/api-gateway -n ecommerce"
    
    echo ""
    print_warning "Para escalar un servicio:"
    echo "kubectl scale deployment api-gateway --replicas=3 -n ecommerce"
}

# Función principal
main() {
    echo "=================================================="
    echo "   Despliegue de Microservicios E-commerce GCP   "
    echo "=================================================="
    echo ""
    
    # Obtener parámetros
    local project_id=${1:-"ecommerce-microservices-back"}
    local cluster_name=${2:-"ecommerce-microservices-cluster"}
    local zone=${3:-"us-central1-a"}
    
    print_status "Parámetros del despliegue:"
    echo "  Proyecto: $project_id"
    echo "  Clúster: $cluster_name"
    echo "  Zona: $zone"
    echo ""
    
    # Ejecutar pasos del despliegue
    check_prerequisites
    check_auth
    check_project "$project_id"
    enable_apis
    init_terraform
    plan_deployment
    
    # Confirmar antes de aplicar
    echo ""
    read -p "¿Desea continuar con el despliegue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_deployment
        configure_kubectl "$cluster_name" "$zone" "$project_id"
        
        # Esperar un poco para que los pods se inicien
        print_status "Esperando a que los pods se inicien..."
        sleep 30
        
        verify_deployment
        show_access_info
        
        echo ""
        print_success "¡Despliegue completado exitosamente!"
    else
        print_warning "Despliegue cancelado por el usuario."
        exit 0
    fi
}

# Mostrar ayuda
show_help() {
    echo "Uso: $0 [PROJECT_ID] [CLUSTER_NAME] [ZONE]"
    echo ""
    echo "Parámetros:"
    echo "  PROJECT_ID    ID del proyecto de GCP (default: ecommerce-microservices-back)"
    echo "  CLUSTER_NAME  Nombre del clúster GKE (default: ecommerce-microservices-cluster)"
    echo "  ZONE          Zona de GCP (default: us-central1-a)"
    echo ""
    echo "Ejemplos:"
    echo "  $0"
    echo "  $0 mi-proyecto"
    echo "  $0 mi-proyecto mi-cluster us-west1-a"
    echo ""
    echo "Opciones:"
    echo "  -h, --help    Mostrar esta ayuda"
}

# Verificar argumentos
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Ejecutar función principal
main "$@" 