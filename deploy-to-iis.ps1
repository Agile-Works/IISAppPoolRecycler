# IIS App Pool Recycler - Advanced Deployment Script
# Run this script on your Windows IIS server as Administrator

param(
    [string]$DeploymentPath = "C:\inetpub\wwwroot\IISRecycler",
    [string]$SiteName = "Default Web Site",
    [string]$AppName = "IISRecycler",
    [switch]$UseGit = $false,
    [string]$GitUrl = "https://github.com/Agile-Works/IISAppPoolRecycler.git"
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "IIS App Pool Recycler - Deployment Tool" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script requires administrator privileges!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Running as Administrator" -ForegroundColor Green

# Check prerequisites
Write-Host "`nChecking prerequisites..." -ForegroundColor Cyan

# Check .NET 6.0
try {
    $dotnetRuntimes = dotnet --list-runtimes 2>$null
    if ($dotnetRuntimes -match "Microsoft\.AspNetCore\.App 6\.") {
        Write-Host "✅ .NET 6.0 Runtime found" -ForegroundColor Green
    } else {
        Write-Host "❌ .NET 6.0 Runtime not found" -ForegroundColor Red
        Write-Host "Please install from: https://dotnet.microsoft.com/en-us/download/dotnet/6.0" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "❌ .NET not found" -ForegroundColor Red
    exit 1
}

# Check IIS
try {
    $iisService = Get-Service W3SVC -ErrorAction Stop
    if ($iisService.Status -eq "Running") {
        Write-Host "✅ IIS is running" -ForegroundColor Green
    } else {
        Write-Host "❌ IIS is not running" -ForegroundColor Red
        Write-Host "Starting IIS..." -ForegroundColor Yellow
        Start-Service W3SVC
    }
} catch {
    Write-Host "❌ IIS is not installed or accessible" -ForegroundColor Red
    exit 1
}

# Check Git (if using Git deployment)
if ($UseGit) {
    try {
        git --version | Out-Null
        Write-Host "✅ Git is available" -ForegroundColor Green
    } catch {
        Write-Host "❌ Git not found (required for Git deployment)" -ForegroundColor Red
        exit 1
    }
}

# Deployment process
Write-Host "`nStarting deployment..." -ForegroundColor Cyan

if ($UseGit) {
    Write-Host "Using Git-based deployment..." -ForegroundColor Yellow
    
    # Create deployment directory
    if (Test-Path $DeploymentPath) {
        Write-Host "Removing existing deployment..." -ForegroundColor Yellow
        Remove-Item -Path $DeploymentPath -Recurse -Force
    }
    
    # Clone repository
    Write-Host "Cloning repository..." -ForegroundColor Yellow
    git clone $GitUrl $DeploymentPath
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Git clone failed" -ForegroundColor Red
        exit 1
    }
    
    # Change to deployment directory
    Set-Location $DeploymentPath
    
    # Run deployment script
    Write-Host "Running deployment script..." -ForegroundColor Yellow
    cmd /c "deploy.cmd"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Deployment script failed" -ForegroundColor Red
        exit 1
    }
    
} else {
    Write-Host "Manual deployment mode..." -ForegroundColor Yellow
    Write-Host "Please ensure application files are in: $DeploymentPath" -ForegroundColor Yellow
    
    if (-not (Test-Path "$DeploymentPath\IISAppPoolRecycler.dll")) {
        Write-Host "❌ Application files not found in $DeploymentPath" -ForegroundColor Red
        Write-Host "Please copy the published application files to this directory first." -ForegroundColor Yellow
        exit 1
    }
}

# Configure IIS
Write-Host "`nConfiguring IIS..." -ForegroundColor Cyan

# Import WebAdministration module
Import-Module WebAdministration -ErrorAction SilentlyContinue

try {
    # Check if application already exists
    $existingApp = Get-WebApplication -Site $SiteName -Name $AppName -ErrorAction SilentlyContinue
    
    if ($existingApp) {
        Write-Host "Updating existing IIS application..." -ForegroundColor Yellow
        Set-WebApplication -Site $SiteName -Name $AppName -PhysicalPath $DeploymentPath
    } else {
        Write-Host "Creating new IIS application..." -ForegroundColor Yellow
        New-WebApplication -Site $SiteName -Name $AppName -PhysicalPath $DeploymentPath
    }
    
    Write-Host "✅ IIS application configured" -ForegroundColor Green
    
    # Configure application pool
    Write-Host "Configuring application pool..." -ForegroundColor Yellow
    $appPool = Get-WebApplication -Site $SiteName -Name $AppName | Select-Object -ExpandProperty ApplicationPool
    
    Set-ItemProperty -Path "IIS:\AppPools\$appPool" -Name processModel.loadUserProfile -Value True
    Write-Host "✅ Application pool configured" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Failed to configure IIS: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test deployment
Write-Host "`nTesting deployment..." -ForegroundColor Cyan

$testUrl = "http://localhost/$AppName/api/webhook/app-pools"
try {
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ API endpoint responding successfully" -ForegroundColor Green
    } else {
        Write-Host "⚠️ API endpoint returned status: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Could not test API endpoint (this is normal if no sites are configured yet)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nApplication URLs:" -ForegroundColor Cyan
Write-Host "  Swagger UI: http://localhost/$AppName/swagger" -ForegroundColor White
Write-Host "  API Base:   http://localhost/$AppName/api/webhook/" -ForegroundColor White

Write-Host "`nTest Commands:" -ForegroundColor Cyan
Write-Host "  List Sites:     curl `"http://localhost/$AppName/api/webhook/sites`"" -ForegroundColor White
Write-Host "  List App Pools: curl `"http://localhost/$AppName/api/webhook/app-pools`"" -ForegroundColor White
Write-Host "  Lookup URL:     curl `"http://localhost/$AppName/api/webhook/lookup/https://example.com`"" -ForegroundColor White

Write-Host "`nUptime Kuma Webhook URL:" -ForegroundColor Cyan
Write-Host "  http://your-server-ip/$AppName/api/webhook/uptime-kuma" -ForegroundColor Yellow

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Test the API endpoints above" -ForegroundColor White
Write-Host "  2. Configure Uptime Kuma with the webhook URL" -ForegroundColor White
Write-Host "  3. Test with a real site monitoring scenario" -ForegroundColor White
Write-Host "  4. Monitor logs in: $DeploymentPath\logs\" -ForegroundColor White

Write-Host "`nDeployment completed successfully! 🎉" -ForegroundColor Green
