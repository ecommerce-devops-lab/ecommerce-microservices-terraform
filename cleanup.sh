#!/bin/bash

# Script de limpieza para infraestructura de microservicios en GCP
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
    
    # Verificar terraform
    if ! command -v terraform &> /dev/null; then
        print_error "terraform no está instalado."
        exit 1
    fi
    
    # Verificar que estamos en el directorio correcto
    if [ ! -f "main.tf" ]; then
        print_error "No se encontró main.tf. Asegúrese de estar en el directorio microservices-terraform."
        exit 1
    fi
    
    print_success "Prerequisitos verificados."
}

# Mostrar recursos que serán eliminados
show_resources() {
    print_status "Mostrando recursos que serán eliminados..."
    
    terraform plan -destroy
    
    if [ $? -ne 0 ]; then
        print_error "Error al generar el plan de destrucción."
        exit 1
    fi
}

# Confirmar destrucción
confirm_destruction() {
    echo ""
    print_warning "⚠️  ADVERTENCIA: Esta acción eliminará PERMANENTEMENTE todos los recursos."
    print_warning "⚠️  Esto incluye:"
    echo "   - El clúster GKE y todos los pods/servicios"
    echo "   - La VPC y subredes"
    echo "   - Todos los datos no persistentes"
    echo ""
    
    read -p "¿Está seguro de que desea continuar? Escriba 'DELETE' para confirmar: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        print_warning "Operación cancelada por el usuario."
        exit 0
    fi
}

# Realizar backup de estado (opcional)
backup_state() {
    print_status "Creando backup del estado de Terraform..."
    
    if [ -f "terraform.tfstate" ]; then
        cp terraform.tfstate "terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "Backup del estado creado."
    else
        print_warning "No se encontró archivo de estado local."
    fi
}

# Destruir infraestructura
destroy_infrastructure() {
    print_status "Destruyendo la infraestructura..."
    
    terraform destroy -auto-approve
    
    if [ $? -eq 0 ]; then
        print_success "Infraestructura destruida correctamente."
    else
        print_error "Error durante la destrucción de la infraestructura."
        exit 1
    fi
}

# Limpiar archivos locales (opcional)
cleanup_local() {
    read -p "¿Desea eliminar los archivos de estado y configuración local? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Limpiando archivos locales..."
        
        # Eliminar directorio .terraform
        if [ -d ".terraform" ]; then
            rm -rf .terraform
            print_success "Directorio .terraform eliminado."
        fi
        
        # Eliminar archivos de estado
        if [ -f "terraform.tfstate" ]; then
            rm terraform.tfstate
            print_success "Archivo terraform.tfstate eliminado."
        fi
        
        if [ -f "terraform.tfstate.backup" ]; then
            rm terraform.tfstate.backup
            print_success "Archivo terraform.tfstate.backup eliminado."
        fi
        
        # Eliminar lock file
        if [ -f ".terraform.lock.hcl" ]; then
            rm .terraform.lock.hcl
            print_success "Archivo .terraform.lock.hcl eliminado."
        fi
        
    else
        print_warning "Archivos locales conservados."
    fi
}

# Verificar que los recursos fueron eliminados
verify_cleanup() {
    print_status "Verificando que los recursos fueron eliminados..."
    
    local project_id=${1:-"ecommerce-microservices-back"}
    local cluster_name=${2:-"ecommerce-microservices-cluster"}
    local zone=${3:-"us-central1-a"}
    
    # Verificar si gcloud está disponible
    if command -v gcloud &> /dev/null; then
        print_status "Verificando clúster GKE..."
        
        if gcloud container clusters describe "$cluster_name" --zone="$zone" --project="$project_id" &> /dev/null; then
            print_warning "El clúster $cluster_name aún existe. Puede necesitar eliminación manual."
        else
            print_success "Clúster GKE eliminado correctamente."
        fi
        
        print_status "Verificando VPC..."
        local vpc_name="${cluster_name}-vpc"
        
        if gcloud compute networks describe "$vpc_name" --project="$project_id" &> /dev/null; then
            print_warning "La VPC $vpc_name aún existe. Puede necesitar eliminación manual."
        else
            print_success "VPC eliminada correctamente."
        fi
    else
        print_warning "gcloud no disponible. No se puede verificar la eliminación en GCP."
    fi
}

# Función principal
main() {
    echo "=================================================="
    echo "      Limpieza de Infraestructura GCP           "
    echo "=================================================="
    echo ""
    
    # Obtener parámetros
    local project_id=${1:-"ecommerce-microservices-back"}
    local cluster_name=${2:-"ecommerce-microservices-cluster"}
    local zone=${3:-"us-central1-a"}
    
    print_status "Parámetros de limpieza:"
    echo "  Proyecto: $project_id"
    echo "  Clúster: $cluster_name"
    echo "  Zona: $zone"
    echo ""
    
    # Ejecutar pasos de limpieza
    check_prerequisites
    show_resources
    confirm_destruction
    backup_state
    destroy_infrastructure
    cleanup_local
    verify_cleanup "$project_id" "$cluster_name" "$zone"
    
    echo ""
    print_success "¡Limpieza completada exitosamente!"
    print_warning "Recuerde verificar en la consola de GCP que todos los recursos fueron eliminados."
}

# Mostrar ayuda
show_help() {
    echo "Uso: $0 [PROJECT_ID] [CLUSTER_NAME] [ZONE]"
    echo ""
    echo "Este script destruye completamente la infraestructura creada por Terraform."
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
    echo ""
    echo "⚠️  ADVERTENCIA: Esta operación es IRREVERSIBLE y eliminará todos los recursos."
}

# Verificar argumentos
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Ejecutar función principal
main "$@" 