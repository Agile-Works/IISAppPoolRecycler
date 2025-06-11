# Deployment Validation Script
# This script validates that the deployment is ready for Kudu

Write-Host "IIS App Pool Recycler - Deployment Validation" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

$errors = @()
$warnings = @()

# Check required files
$requiredFiles = @(
    ".deployment",
    "deploy.cmd", 
    "web.config",
    "Program.cs",
    "appsettings.json",
    "appsettings.Production.json",
    "IISAppPoolRecycler.csproj"
)

Write-Host "Checking required files..." -ForegroundColor Cyan
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ $file" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $file" -ForegroundColor Red
        $errors += "Missing required file: $file"
    }
}

# Check project can build
Write-Host "`nChecking build..." -ForegroundColor Cyan
try {
    $buildOutput = dotnet build --configuration Release --verbosity quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Build successful" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Build failed" -ForegroundColor Red
        $errors += "Build failed: $buildOutput"
    }
} catch {
    Write-Host "  ❌ Build error" -ForegroundColor Red
    $errors += "Build error: $($_.Exception.Message)"
}

# Check web.config
Write-Host "`nChecking web.config..." -ForegroundColor Cyan
if (Test-Path "web.config") {
    $webConfig = Get-Content "web.config" -Raw
    if ($webConfig -match "IISAppPoolRecycler\.dll") {
        Write-Host "  ✅ web.config references correct DLL" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  web.config may not reference correct DLL" -ForegroundColor Yellow
        $warnings += "web.config should reference IISAppPoolRecycler.dll"
    }
    
    if ($webConfig -match "AspNetCoreModuleV2") {
        Write-Host "  ✅ web.config uses AspNetCoreModuleV2" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  web.config should use AspNetCoreModuleV2" -ForegroundColor Yellow
        $warnings += "Consider using AspNetCoreModuleV2 in web.config"
    }
}

# Check .deployment file
Write-Host "`nChecking .deployment file..." -ForegroundColor Cyan
if (Test-Path ".deployment") {
    $deploymentConfig = Get-Content ".deployment" -Raw
    if ($deploymentConfig -match "deploy\.cmd") {
        Write-Host "  ✅ .deployment references deploy.cmd" -ForegroundColor Green
    } else {
        Write-Host "  ❌ .deployment should reference deploy.cmd" -ForegroundColor Red
        $errors += ".deployment file should contain: command = deploy.cmd"
    }
}

# Check NuGet packages
Write-Host "`nChecking critical packages..." -ForegroundColor Cyan
$csprojContent = Get-Content "IISAppPoolRecycler.csproj" -Raw
$criticalPackages = @(
    "Microsoft.Web.Administration",
    "Microsoft.AspNetCore.Server.IIS"
)

foreach ($package in $criticalPackages) {
    if ($csprojContent -match $package) {
        Write-Host "  ✅ $package referenced" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  $package not found" -ForegroundColor Yellow
        $warnings += "Consider adding package: $package"
    }
}

# Check Git status
Write-Host "`nChecking Git status..." -ForegroundColor Cyan
try {
    $gitStatus = git status --porcelain 2>$null
    if ($gitStatus) {
        Write-Host "  ⚠️  Uncommitted changes detected" -ForegroundColor Yellow
        $warnings += "There are uncommitted changes. Consider committing before deployment."
        Write-Host "    Uncommitted files:" -ForegroundColor Gray
        git status --porcelain | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    } else {
        Write-Host "  ✅ Working directory clean" -ForegroundColor Green
    }
} catch {
    Write-Host "  ⚠️  Not a Git repository or Git not available" -ForegroundColor Yellow
    $warnings += "Consider using Git for version control"
}

# Summary
Write-Host "`n" + "="*50 -ForegroundColor Gray
Write-Host "Validation Summary" -ForegroundColor Yellow

if ($errors.Count -eq 0) {
    Write-Host "✅ No critical errors found!" -ForegroundColor Green
    Write-Host "The application is ready for Kudu deployment." -ForegroundColor Green
} else {
    Write-Host "❌ Critical errors found:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
}

if ($warnings.Count -gt 0) {
    Write-Host "`n⚠️  Warnings:" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Fix any critical errors above" -ForegroundColor White
Write-Host "2. Test local deployment: .\deploy-local.ps1" -ForegroundColor White
Write-Host "3. Commit and push to your Git repository" -ForegroundColor White
Write-Host "4. Deploy to your IIS/Azure App Service" -ForegroundColor White
Write-Host "5. Configure Uptime Kuma webhook URL" -ForegroundColor White

if ($errors.Count -eq 0) {
    exit 0
} else {
    exit 1
}
