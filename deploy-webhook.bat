@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Enhanced GitHub Webhook Deployment Script
echo ========================================
echo Started at: %date% %time%

:: Create deployment timestamp
set DEPLOY_ID=%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set DEPLOY_ID=%DEPLOY_ID: =0%

:: Create detailed log entry
echo %date% %time% - [DEPLOY_%DEPLOY_ID%] Webhook deployment started >> webhook-deployment.log
echo Deployment ID: %DEPLOY_ID%

:: Read configuration with validation
set CONFIG_FILE=%~dp0config.ini
if not exist "%CONFIG_FILE%" (
    echo ERROR: Configuration file not found: %CONFIG_FILE%
    echo %date% %time% - [DEPLOY_%DEPLOY_ID%] ERROR: Configuration file not found >> webhook-deployment.log
    exit /b 1
)

echo Loading configuration from: %CONFIG_FILE%

:: Parse configuration file with enhanced error handling
for /f "tokens=1,2 delims==" %%a in ('type "%CONFIG_FILE%" ^| findstr /v "^#" ^| findstr /v "^\["') do (
    if "%%a" neq "" if "%%b" neq "" (
        set "%%a=%%b"
        echo   %%a = %%b
    )
)

:: Validate required configuration with detailed error messages
echo Validating configuration...
if not defined deployment_path (
    echo ERROR: deployment_path not configured in config.ini
    echo %date% %time% - [DEPLOY_%DEPLOY_ID%] ERROR: deployment_path not configured >> webhook-deployment.log
    exit /b 1
)

if not defined repository (
    echo ERROR: repository not configured in config.ini
    echo %date% %time% - [DEPLOY_%DEPLOY_ID%] ERROR: repository not configured >> webhook-deployment.log
    exit /b 1
)

if not defined branch (
    set branch=main
    echo WARNING: branch not configured, using default: main
)

echo Configuration validated successfully
echo Deployment Configuration:
echo - Repository: %repository%
echo - Branch: %branch%
echo - Deployment Path: %deployment_path%
echo - App Pool: %app_pool_name%
echo.

::  Enhanced temporary directory creation with better error handling
set TEMP_DIR=C:\temp\webhook-deploy-%DEPLOY_ID%-%RANDOM%
echo Creating temporary directory: %TEMP_DIR%
mkdir "%TEMP_DIR%" 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Failed to create temporary directory: %TEMP_DIR%
    echo %date% %time% - [DEPLOY_%DEPLOY_ID%] ERROR: Failed to create temp directory >> webhook-deployment.log
    exit /b 1
)

cd /d "%TEMP_DIR%"

:: Clone repository with detailed logging
echo.
echo Cloning repository from GitHub...
echo Repository: https://github.com/%repository%.git
echo Branch: %branch%
echo %date% %time% - [DEPLOY_%DEPLOY_ID%] Cloning repository: %repository% branch: %branch% >> %~dp0webhook-deployment.log

git clone --depth 1 --branch %branch% --single-branch https://github.com/%repository%.git . 2>>%~dp0webhook-deployment.log
set CLONE_RESULT=%errorlevel%

if %CLONE_RESULT% neq 0 (
    echo ERROR: Git clone failed with exit code %CLONE_RESULT%
    echo %date% %time% - [DEPLOY_%DEPLOY_ID%] ERROR: Git clone failed with code %CLONE_RESULT% >> %~dp0webhook-deployment.log
    cd /d %~dp0
    rmdir /s /q "%TEMP_DIR%" 2>nul
    exit /b %CLONE_RESULT%
)

echo Git clone completed successfully
echo Repository cloned to: %TEMP_DIR%

:: Verify essential files exist
echo.
echo Verifying repository structure...
if not exist "deploy.cmd" (
    echo ERROR: deploy.cmd not found in repository
    echo %date% %time% - [DEPLOY_%DEPLOY_ID%] ERROR: deploy.cmd not found >> %~dp0webhook-deployment.log
    cd /d %~dp0
    rmdir /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

if not exist "IISAppPoolRecycler.csproj" (
    echo ERROR: IISAppPoolRecycler.csproj not found in repository
    echo %date% %time% - [DEPLOY_%DEPLOY_ID%] ERROR: Project file not found >> %~dp0webhook-deployment.log
    cd /d %~dp0
    rmdir /s /q "%TEMP_DIR%" 2>nul
    exit /b 1
)

echo Repository structure verified successfully

:: Set deployment environment variables
set DEPLOYMENT_SOURCE=%TEMP_DIR%
set DEPLOYMENT_TARGET=%deployment_path%
set ARTIFACTS=%deployment_path%\..\artifacts
set IN_PLACE_DEPLOYMENT=1

echo.
echo Running Kudu deployment script...
echo %date% %time% - Running deploy.cmd >> %~dp0webhook-deployment.log

:: Execute deployment script
call deploy.cmd >>%~dp0webhook-deployment.log 2>&1
set DEPLOY_RESULT=%errorlevel%

if %DEPLOY_RESULT% neq 0 (
    echo ERROR: Kudu deployment failed with exit code %DEPLOY_RESULT%
    echo %date% %time% - ERROR: Deploy failed with code %DEPLOY_RESULT% >> %~dp0webhook-deployment.log
    cd /d %~dp0
    rmdir /s /q "%TEMP_DIR%" 2>nul
    exit /b %DEPLOY_RESULT%
)

echo Kudu deployment completed successfully

:: Optional: Restart IIS application pool
if defined app_pool_name (
    echo.
    echo Restarting application pool: %app_pool_name%
    echo %date% %time% - Restarting app pool %app_pool_name% >> %~dp0webhook-deployment.log
    
    "%systemroot%\system32\inetsrv\appcmd" recycle apppool /apppool.name:"%app_pool_name%" >>%~dp0webhook-deployment.log 2>&1
    if %errorlevel% equ 0 (
        echo Application pool restarted successfully
    ) else (
        echo WARNING: Failed to restart application pool
        echo %date% %time% - WARNING: App pool restart failed >> %~dp0webhook-deployment.log
    )
)

:: Clean up temporary directory
echo.
echo Cleaning up temporary files...
cd /d %~dp0
rmdir /s /q "%TEMP_DIR%" 2>nul

:: Log successful completion
echo.
echo ========================================
echo Deployment completed successfully!
echo Completed at: %date% %time%
echo ========================================
echo %date% %time% - Webhook deployment completed successfully >> webhook-deployment.log

:: Optional: Test the deployed application
if defined test_endpoint (
    echo.
    echo Testing deployed application...
    curl -f "%test_endpoint%" >nul 2>&1
    if %errorlevel% equ 0 (
        echo Application test passed
        echo %date% %time% - Application test passed >> webhook-deployment.log
    ) else (
        echo WARNING: Application test failed
        echo %date% %time% - WARNING: Application test failed >> webhook-deployment.log
    )
)

exit /b 0
