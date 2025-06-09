@echo off
REM Script para limpiar recursos de Kubernetes existentes (Windows)
REM Autor: Asistente AI

setlocal enabledelayedexpansion

REM Obtener parametros
set NAMESPACE=%1
if "%NAMESPACE%"=="" set NAMESPACE=ecommerce

set CLUSTER_NAME=%2
if "%CLUSTER_NAME%"=="" set CLUSTER_NAME=ecommerce-microservices-cluster

set ZONE=%3
if "%ZONE%"=="" set ZONE=us-central1-a

set PROJECT_ID=%4
if "%PROJECT_ID%"=="" set PROJECT_ID=ecommerce-microservices-back

echo Script de limpieza de recursos de Kubernetes
echo ==============================================
echo Namespace: %NAMESPACE%
echo Cluster: %CLUSTER_NAME%
echo Zona: %ZONE%
echo Proyecto: %PROJECT_ID%
echo.

REM Verificar si kubectl esta configurado
echo [INFO] Verificando conexion con el cluster...
kubectl cluster-info >nul 2>&1
if errorlevel 1 (
    echo [WARNING] No hay conexion con Kubernetes. Configurando kubectl...
    gcloud container clusters get-credentials %CLUSTER_NAME% --zone %ZONE% --project %PROJECT_ID%
    
    if errorlevel 1 (
        echo [ERROR] Error al configurar kubectl
        exit /b 1
    )
)

echo [SUCCESS] Conexion con Kubernetes establecida

REM Verificar si el namespace existe
echo [INFO] Verificando namespace %NAMESPACE%...
kubectl get namespace %NAMESPACE% >nul 2>&1
if not errorlevel 1 (
    echo [WARNING] Namespace %NAMESPACE% encontrado. Limpiando recursos...
    echo.
    echo [WARNING] Esta seguro de que desea eliminar TODOS los recursos en el namespace %NAMESPACE%?
    echo [WARNING] Esta accion eliminara:
    echo   - Todos los deployments
    echo   - Todos los services
    echo   - Todos los configmaps
    echo   - El namespace completo
    echo.
    set /p CONFIRM="Escriba 'SI' para confirmar: "
    
    if "!CONFIRM!"=="SI" (
        echo [INFO] Eliminando deployments...
        kubectl delete deployments --all -n %NAMESPACE% --timeout=60s
        
        echo [INFO] Eliminando services...
        kubectl delete services --all -n %NAMESPACE% --timeout=60s
        
        echo [INFO] Eliminando configmaps...
        kubectl delete configmaps --all -n %NAMESPACE% --timeout=60s
        
        echo [INFO] Eliminando namespace...
        kubectl delete namespace %NAMESPACE% --timeout=120s
        
        REM Esperar a que el namespace se elimine completamente
        echo [INFO] Esperando a que el namespace se elimine completamente...
        :wait_loop
        kubectl get namespace %NAMESPACE% >nul 2>&1
        if not errorlevel 1 (
            echo .
            timeout /t 2 /nobreak >nul
            goto wait_loop
        )
        echo.
        
        echo [SUCCESS] Namespace %NAMESPACE% eliminado completamente
    ) else (
        echo [WARNING] Operacion cancelada por el usuario
        exit /b 0
    )
) else (
    echo [INFO] Namespace %NAMESPACE% no existe
)

echo [SUCCESS] Limpieza de Kubernetes completada
echo.
echo [WARNING] Ahora puede ejecutar Terraform de nuevo:
echo terraform plan
echo terraform apply
echo.
echo [WARNING] O usar el script de correccion:
echo fix-errors.bat

pause 