# IIS App Pool Recycler - Windows Deployment Script
# This script should be run on a Windows Server with IIS installed

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges to manage IIS. Please run as administrator." -ForegroundColor Red
    exit 1
}

# Build the application
Write-Host "Building IIS App Pool Recycler..." -ForegroundColor Green
dotnet build --configuration Release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

# Start the application
Write-Host "Starting IIS App Pool Recycler..." -ForegroundColor Green
Write-Host "The application will start on:" -ForegroundColor Yellow
Write-Host "  HTTP:  http://localhost:5000" -ForegroundColor Cyan
Write-Host "  HTTPS: https://localhost:5001" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available endpoints:" -ForegroundColor Yellow
Write-Host "  POST /api/webhook/uptime-kuma     - Uptime Kuma webhook endpoint" -ForegroundColor Cyan
Write-Host "  POST /api/webhook/recycle         - Manual app pool recycling" -ForegroundColor Cyan
Write-Host "  GET  /api/webhook/sites           - List all IIS sites" -ForegroundColor Cyan
Write-Host "  GET  /api/webhook/app-pools       - List all app pools" -ForegroundColor Cyan
Write-Host "  GET  /api/webhook/lookup/{url}    - Lookup app pool for URL" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop the application" -ForegroundColor Yellow
Write-Host ""

dotnet run --configuration Release
