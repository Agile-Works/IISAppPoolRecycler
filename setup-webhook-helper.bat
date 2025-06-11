@echo off
echo ============================================
echo GitHub Webhook Setup Helper
echo ============================================
echo.

:: Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator
    echo Right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Running as Administrator... ✓

:: Check prerequisites
echo.
echo Checking prerequisites...

:: Check Git
git --version >nul 2>&1
if %errorlevel% equ 0 (
    echo Git installed... ✓
) else (
    echo ERROR: Git not found. Please install Git first.
    echo Download from: https://git-scm.com/download/win
    pause
    exit /b 1
)

:: Check .NET
dotnet --version >nul 2>&1
if %errorlevel% equ 0 (
    echo .NET installed... ✓
) else (
    echo ERROR: .NET not found. Please install .NET 8.0 Runtime.
    echo Download from: https://dotnet.microsoft.com/download
    pause
    exit /b 1
)

:: Check IIS
"%systemroot%\system32\inetsrv\appcmd" list sites >nul 2>&1
if %errorlevel% equ 0 (
    echo IIS available... ✓
) else (
    echo ERROR: IIS not available or not configured properly.
    echo Please install and configure IIS with ASP.NET Core module.
    pause
    exit /b 1
)

:: Check PHP (optional)
php --version >nul 2>&1
if %errorlevel% equ 0 (
    echo PHP available... ✓
) else (
    echo WARNING: PHP not found. PowerShell webhook receiver will be used instead.
)

echo.
echo Prerequisites check completed!
echo.

:: Get server information
echo Please provide your server information:
echo.

:: Get server IP
set /p SERVER_IP=Enter your server's public IP address or domain: 
if "%SERVER_IP%"=="" (
    echo ERROR: Server IP/domain is required
    pause
    exit /b 1
)

echo.
echo Server IP/Domain: %SERVER_IP%

:: Confirm setup
echo.
echo Ready to set up GitHub webhook continuous deployment:
echo - Server: %SERVER_IP%
echo - Repository: Agile-Works/IISAppPoolRecycler
echo - Webhook directory: C:\kudu-webhooks
echo - Deployment directory: C:\inetpub\wwwroot\IISRecycler
echo.

set /p CONFIRM=Continue with setup? (Y/N): 
if /i not "%CONFIRM%"=="Y" (
    echo Setup cancelled.
    pause
    exit /b 0
)

echo.
echo Starting automated setup...

:: Run PowerShell setup script
powershell -ExecutionPolicy Bypass -Command "& { if (Test-Path '.\setup-continuous-deployment.ps1') { .\setup-continuous-deployment.ps1 -ServerIP '%SERVER_IP%' } else { Write-Host 'ERROR: setup-continuous-deployment.ps1 not found in current directory' -ForegroundColor Red; Write-Host 'Please ensure you are running this from the repository root directory.' -ForegroundColor Yellow; pause } }"

if %errorlevel% neq 0 (
    echo.
    echo Setup failed. Please check the error messages above.
    echo.
    echo Manual setup options:
    echo 1. Review the setup logs
    echo 2. Run individual setup steps manually
    echo 3. Check the documentation: GITHUB-WEBHOOK-CONTINUOUS-DEPLOYMENT.md
    pause
    exit /b 1
)

echo.
echo ============================================
echo Setup completed successfully!
echo ============================================
echo.
echo Next steps:
echo 1. Configure GitHub webhook with the provided URL and secret
echo 2. Test with a small commit to your repository
echo 3. Monitor deployment logs in C:\kudu-webhooks\
echo.
echo GitHub webhook configuration:
echo Repository: https://github.com/Agile-Works/IISAppPoolRecycler/settings/hooks
echo Payload URL: http://%SERVER_IP%/github-webhook/webhook-receiver.php
echo Content type: application/json
echo Secret: (check the setup output above)
echo Events: Just the push event
echo.
echo For detailed instructions, see: GITHUB-WEBHOOK-CONTINUOUS-DEPLOYMENT.md
echo.

pause
