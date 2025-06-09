# Script de despliegue para microservicios en GCP (PowerShell)
# Autor: Asistente AI
# Fecha: (Get-Date)

param(
    [string]$ProjectId = "ecommerce-microservices-back",
    [string]$ClusterName = "ecommerce-microservices-cluster",
    [string]$Zone = "us-central1-a",
    [switch]$Help
)

# Función para mostrar ayuda
function Show-Help {
    Write-Host "Uso: .\deploy.ps1 [-ProjectId <ID>] [-ClusterName <Nombre>] [-Zone <Zona>] [-Help]"
    Write-Host ""
    Write-Host "Parámetros:"
    Write-Host "  -ProjectId    ID del proyecto de GCP (default: ecommerce-microservices-back)"
    Write-Host "  -ClusterName  Nombre del clúster GKE (default: ecommerce-microservices-cluster)"
    Write-Host "  -Zone         Zona de GCP (default: us-central1-a)"
    Write-Host "  -Help         Mostrar esta ayuda"
    Write-Host ""
    Write-Host "Ejemplos:"
    Write-Host "  .\deploy.ps1"
    Write-Host "  .\deploy.ps1 -ProjectId 'mi-proyecto'"
    Write-Host "  .\deploy.ps1 -ProjectId 'mi-proyecto' -ClusterName 'mi-cluster' -Zone 'us-west1-a'"
}

# Función para imprimir mensajes coloreados
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Verificar prerequisitos
function Test-Prerequisites {
    Write-Status "Verificando prerequisitos..."
    
    # Verificar gcloud
    try {
        $null = Get-Command gcloud -ErrorAction Stop
    }
    catch {
        Write-Error "gcloud no está instalado. Por favor instale Google Cloud SDK."
        exit 1
    }
    
    # Verificar terraform
    try {
        $null = Get-Command terraform -ErrorAction Stop
    }
    catch {
        Write-Error "terraform no está instalado. Por favor instale Terraform."
        exit 1
    }
    
    # Verificar kubectl
    try {
        $null = Get-Command kubectl -ErrorAction Stop
    }
    catch {
        Write-Error "kubectl no está instalado. Por favor instale kubectl."
        exit 1
    }
    
    Write-Success "Todos los prerequisitos están instalados."
}

# Verificar autenticación con GCP
function Test-GCPAuth {
    Write-Status "Verificando autenticación con Google Cloud..."
    
    $authResult = gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null
    if (-not $authResult) {
        Write-Error "No hay una cuenta activa en gcloud. Ejecute 'gcloud auth login'."
        exit 1
    }
    
    Write-Success "Autenticado con Google Cloud."
}

# Verificar proyecto
function Test-Project {
    param([string]$ProjectId)
    
    Write-Status "Verificando proyecto: $ProjectId"
    
    $projectResult = gcloud projects describe $ProjectId 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "El proyecto $ProjectId no existe o no tiene acceso."
        exit 1
    }
    
    gcloud config set project $ProjectId | Out-Null
    Write-Success "Proyecto configurado: $ProjectId"
}

# Habilitar APIs
function Enable-APIs {
    Write-Status "Habilitando APIs necesarias..."
    
    gcloud services enable container.googleapis.com | Out-Null
    gcloud services enable compute.googleapis.com | Out-Null
    
    Write-Success "APIs habilitadas."
}

# Inicializar Terraform
function Initialize-Terraform {
    Write-Status "Inicializando Terraform..."
    
    terraform init
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Terraform inicializado correctamente."
    }
    else {
        Write-Error "Error al inicializar Terraform."
        exit 1
    }
}

# Planificar despliegue
function New-DeploymentPlan {
    Write-Status "Planificando el despliegue..."
    
    terraform plan
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Plan generado correctamente."
    }
    else {
        Write-Error "Error al generar el plan."
        exit 1
    }
}

# Aplicar configuración
function Start-Deployment {
    Write-Status "Aplicando la configuración..."
    
    terraform apply -auto-approve
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Despliegue completado correctamente."
    }
    else {
        Write-Error "Error durante el despliegue."
        exit 1
    }
}

# Configurar kubectl
function Set-KubectlConfig {
    param(
        [string]$ClusterName,
        [string]$Zone,
        [string]$ProjectId
    )
    
    Write-Status "Configurando kubectl..."
    
    gcloud container clusters get-credentials $ClusterName --zone $Zone --project $ProjectId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "kubectl configurado correctamente."
    }
    else {
        Write-Error "Error al configurar kubectl."
        exit 1
    }
}

# Verificar despliegue
function Test-Deployment {
    Write-Status "Verificando el despliegue..."
    
    Write-Host ""
    Write-Status "Estado del clúster:"
    kubectl cluster-info
    
    Write-Host ""
    Write-Status "Nodos del clúster:"
    kubectl get nodes
    
    Write-Host ""
    Write-Status "Pods en el namespace ecommerce:"
    kubectl get pods -n ecommerce
    
    Write-Host ""
    Write-Status "Servicios en el namespace ecommerce:"
    kubectl get services -n ecommerce
    
    Write-Success "Verificación completada."
}

# Mostrar información de acceso
function Show-AccessInfo {
    Write-Status "Información de acceso a los servicios:"
    
    Write-Host ""
    Write-Warning "Para obtener las IPs externas de los servicios, ejecute:"
    Write-Host "kubectl get service api-gateway -n ecommerce"
    Write-Host "kubectl get service zipkin -n ecommerce"
    Write-Host "kubectl get service service-discovery -n ecommerce"
    
    Write-Host ""
    Write-Warning "Para ver logs de un servicio específico:"
    Write-Host "kubectl logs -f deployment/api-gateway -n ecommerce"
    
    Write-Host ""
    Write-Warning "Para escalar un servicio:"
    Write-Host "kubectl scale deployment api-gateway --replicas=3 -n ecommerce"
}

# Función principal
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Host "=================================================="
    Write-Host "   Despliegue de Microservicios E-commerce GCP   "
    Write-Host "=================================================="
    Write-Host ""
    
    Write-Status "Parámetros del despliegue:"
    Write-Host "  Proyecto: $ProjectId"
    Write-Host "  Clúster: $ClusterName"
    Write-Host "  Zona: $Zone"
    Write-Host ""
    
    # Ejecutar pasos del despliegue
    Test-Prerequisites
    Test-GCPAuth
    Test-Project -ProjectId $ProjectId
    Enable-APIs
    Initialize-Terraform
    New-DeploymentPlan
    
    # Confirmar antes de aplicar
    Write-Host ""
    $confirmation = Read-Host "¿Desea continuar con el despliegue? (y/N)"
    
    if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
        Start-Deployment
        Set-KubectlConfig -ClusterName $ClusterName -Zone $Zone -ProjectId $ProjectId
        
        # Esperar un poco para que los pods se inicien
        Write-Status "Esperando a que los pods se inicien..."
        Start-Sleep -Seconds 30
        
        Test-Deployment
        Show-AccessInfo
        
        Write-Host ""
        Write-Success "¡Despliegue completado exitosamente!"
    }
    else {
        Write-Warning "Despliegue cancelado por el usuario."
    }
}

# Ejecutar función principal
Main 