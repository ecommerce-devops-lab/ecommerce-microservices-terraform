@echo off
REM Script para resolver errores de Terraform (Windows)
REM Autor: Asistente AI

echo Script de correccion de errores de Terraform
echo ==================================================

REM 1. Limpiar recursos problematicos del estado
echo [INFO] Limpiando recursos problematicos del estado de Terraform...

REM Verificar si hay estado
if exist terraform.tfstate (
    echo [WARNING] Se encontro un estado de Terraform existente. Limpiando recursos problematicos...
    
    REM Intentar remover el node pool problematico del estado
    terraform state rm google_container_node_pool.primary_nodes 2>nul
    if errorlevel 1 echo [WARNING] Node pool no encontrado en el estado
    
    REM Intentar remover recursos de Kubernetes problematicos
    terraform state rm kubernetes_deployment.zipkin 2>nul
    if errorlevel 1 echo [WARNING] Deployment zipkin no encontrado en el estado
    
    echo [SUCCESS] Estado limpiado
) else (
    echo [INFO] No se encontro estado previo de Terraform
)

REM 2. Reinicializar Terraform
echo [INFO] Reinicializando Terraform...
terraform init -upgrade

if errorlevel 1 (
    echo [ERROR] Error al reinicializar Terraform
    exit /b 1
)

REM 3. Validar configuracion
echo [INFO] Validando configuracion de Terraform...
terraform validate

if errorlevel 1 (
    echo [ERROR] Error en la configuracion de Terraform
    exit /b 1
) else (
    echo [SUCCESS] Configuracion valida
)

REM 4. Generar nuevo plan
echo [INFO] Generando nuevo plan de despliegue...
terraform plan -out=tfplan

if errorlevel 1 (
    echo [ERROR] Error al generar el plan
    exit /b 1
) else (
    echo [SUCCESS] Plan generado correctamente
    echo.
    echo [WARNING] Revise el plan anterior. Si se ve bien, ejecute:
    echo terraform apply tfplan
    echo.
    echo [WARNING] O ejecute el script de despliegue:
    echo deploy.bat
)

echo [SUCCESS] Script de correccion completado
pause 