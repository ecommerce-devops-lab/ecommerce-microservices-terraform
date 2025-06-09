#!/bin/bash

# Script para resolver errores de Terraform
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

print_status "Script de corrección de errores de Terraform"
echo "=================================================="

# 1. Limpiar recursos problemáticos del estado
print_status "Limpiando recursos problemáticos del estado de Terraform..."

# Verificar si hay estado
if [ -f "terraform.tfstate" ]; then
    print_warning "Se encontró un estado de Terraform existente. Limpiando recursos problemáticos..."
    
    # Intentar remover el node pool problemático del estado
    terraform state rm google_container_node_pool.primary_nodes 2>/dev/null || print_warning "Node pool no encontrado en el estado"
    
    # Intentar remover recursos de Kubernetes problemáticos
    terraform state rm kubernetes_deployment.zipkin 2>/dev/null || print_warning "Deployment zipkin no encontrado en el estado"
    
    print_success "Estado limpiado"
else
    print_status "No se encontró estado previo de Terraform"
fi

# 2. Reinicializar Terraform
print_status "Reinicializando Terraform..."
terraform init -upgrade

# 3. Validar configuración
print_status "Validando configuración de Terraform..."
terraform validate

if [ $? -eq 0 ]; then
    print_success "Configuración válida"
else
    print_error "Error en la configuración de Terraform"
    exit 1
fi

# 4. Generar nuevo plan
print_status "Generando nuevo plan de despliegue..."
terraform plan -out=tfplan

if [ $? -eq 0 ]; then
    print_success "Plan generado correctamente"
    echo ""
    print_warning "Revise el plan anterior. Si se ve bien, ejecute:"
    echo "terraform apply tfplan"
    echo ""
    print_warning "O ejecute el script de despliegue:"
    echo "./deploy.sh"
else
    print_error "Error al generar el plan"
    exit 1
fi

print_success "Script de corrección completado" 