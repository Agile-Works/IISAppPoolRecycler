@echo off
echo ============================================
echo IIS App Pool Recycler - Deployment Helper
echo ============================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Running as Administrator
) else (
    echo [ERROR] This script requires administrator privileges!
    echo Please run as administrator and try again.
    pause
    exit /b 1
)

echo.
echo Checking prerequisites...
echo.

REM Check if .NET 8.0 is installed
echo Checking .NET 8.0 Runtime...
dotnet --list-runtimes | findstr "Microsoft.AspNetCore.App 8." >nul
if %errorLevel% == 0 (
    echo [OK] .NET 8.0 Runtime found
) else (
    echo [WARNING] .NET 8.0 Runtime not found
    echo Please install .NET 8.0 Runtime from:
    echo https://dotnet.microsoft.com/en-us/download/dotnet/8.0
)

REM Check IIS
echo.
echo Checking IIS...
sc query w3svc | findstr "RUNNING" >nul
if %errorLevel% == 0 (
    echo [OK] IIS is running
) else (
    echo [ERROR] IIS is not running
    echo Please start IIS service: net start w3svc
)

REM Check if Git is available
echo.
echo Checking Git...
git --version >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] Git is available
    git --version
) else (
    echo [WARNING] Git not found
    echo Git is recommended for easy deployment
)

echo.
echo Deployment options:
echo.
echo 1. Git-based deployment (recommended if Git is available):
echo    git clone https://github.com/Agile-Works/IISAppPoolRecycler.git
echo    cd IISAppPoolRecycler
echo    deploy.cmd
echo.
echo 2. Manual deployment:
echo    - Download and extract the repository
echo    - Run: dotnet publish --configuration Release --output "C:\inetpub\wwwroot\IISRecycler"
echo    - Copy web.config to the output directory
echo    - Configure IIS application
echo.
echo 3. Test deployment:
echo    - Browse to: http://localhost/IISRecycler/swagger
echo    - Test API: http://localhost/IISRecycler/api/webhook/sites
echo.

REM Offer to create IIS application
echo.
set /p choice="Would you like to create the IIS application now? (y/n): "
if /i "%choice%"=="y" (
    echo.
    echo Creating IIS application...
    
    REM Create application
    "%systemroot%\system32\inetsrv\appcmd" add app /site.name:"Default Web Site" /path:/IISRecycler /physicalPath:"C:\inetpub\wwwroot\IISRecycler"
    
    if %errorLevel% == 0 (
        echo [OK] IIS application created successfully
        
        REM Configure application pool
        echo Configuring application pool...
        "%systemroot%\system32\inetsrv\appcmd" set config /section:applicationPools /[name='DefaultAppPool'].processModel.loadUserProfile:true
        
        if %errorLevel% == 0 (
            echo [OK] Application pool configured successfully
        ) else (
            echo [WARNING] Failed to configure application pool
        )
    ) else (
        echo [WARNING] Failed to create IIS application (it may already exist)
    )
)

echo.
echo ============================================
echo Deployment preparation complete!
echo ============================================
echo.
echo Next steps:
echo 1. Deploy the application files
echo 2. Test the API endpoints
echo 3. Configure Uptime Kuma webhook
echo.
pause
