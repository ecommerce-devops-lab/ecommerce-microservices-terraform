#!/bin/bash

# Script para limpiar recursos de Kubernetes existentes
# Autor: Asistente AI

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Obtener parámetros
NAMESPACE=${1:-"ecommerce"}
CLUSTER_NAME=${2:-"ecommerce-microservices-cluster"}
ZONE=${3:-"us-central1-a"}
PROJECT_ID=${4:-"ecommerce-microservices-back"}

print_status "Script de limpieza de recursos de Kubernetes"
echo "=============================================="
echo "Namespace: $NAMESPACE"
echo "Clúster: $CLUSTER_NAME"
echo "Zona: $ZONE" 
echo "Proyecto: $PROJECT_ID"
echo ""

# Verificar si kubectl está configurado
print_status "Verificando conexión con el clúster..."
if ! kubectl cluster-info &> /dev/null; then
    print_warning "No hay conexión con Kubernetes. Configurando kubectl..."
    gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$ZONE" --project "$PROJECT_ID"
    
    if [ $? -ne 0 ]; then
        print_error "Error al configurar kubectl"
        exit 1
    fi
fi

print_success "Conexión con Kubernetes establecida"

# Verificar si el namespace existe
print_status "Verificando namespace $NAMESPACE..."
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_warning "Namespace $NAMESPACE encontrado. Limpiando recursos..."
    
    echo ""
    print_warning "¿Está seguro de que desea eliminar TODOS los recursos en el namespace $NAMESPACE?"
    print_warning "Esta acción eliminará:"
    echo "  - Todos los deployments"
    echo "  - Todos los services" 
    echo "  - Todos los configmaps"
    echo "  - El namespace completo"
    echo ""
    read -p "Escriba 'SI' para confirmar: " -r
    
    if [[ $REPLY == "SI" ]]; then
        print_status "Eliminando deployments..."
        kubectl delete deployments --all -n "$NAMESPACE" --timeout=60s || print_warning "Error eliminando deployments"
        
        print_status "Eliminando services..."
        kubectl delete services --all -n "$NAMESPACE" --timeout=60s || print_warning "Error eliminando services"
        
        print_status "Eliminando configmaps..."
        kubectl delete configmaps --all -n "$NAMESPACE" --timeout=60s || print_warning "Error eliminando configmaps"
        
        print_status "Eliminando namespace..."
        kubectl delete namespace "$NAMESPACE" --timeout=120s || print_warning "Error eliminando namespace"
        
        # Esperar a que el namespace se elimine completamente
        print_status "Esperando a que el namespace se elimine completamente..."
        while kubectl get namespace "$NAMESPACE" &> /dev/null; do
            echo -n "."
            sleep 2
        done
        echo ""
        
        print_success "Namespace $NAMESPACE eliminado completamente"
    else
        print_warning "Operación cancelada por el usuario"
        exit 0
    fi
else
    print_status "Namespace $NAMESPACE no existe"
fi

print_success "Limpieza de Kubernetes completada"
echo ""
print_warning "Ahora puede ejecutar Terraform de nuevo:"
echo "terraform plan"
echo "terraform apply"
echo ""
print_warning "O usar el script de corrección:"
echo "./fix-errors.sh" 