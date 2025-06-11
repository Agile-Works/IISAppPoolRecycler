# Local Kudu Deployment Test Script
# This script simulates what Kudu does during deployment

param(
    [string]$TargetPath = ".\publish",
    [string]$Configuration = "Release"
)

Write-Host "IIS App Pool Recycler - Local Deployment Test" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Warning: Not running as administrator. IIS operations may fail." -ForegroundColor Yellow
}

# Clean previous build
if (Test-Path $TargetPath) {
    Write-Host "Cleaning previous deployment..." -ForegroundColor Yellow
    Remove-Item -Path $TargetPath -Recurse -Force
}

# Create target directory
New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null

try {
    # Step 1: Restore packages
    Write-Host "Restoring NuGet packages..." -ForegroundColor Cyan
    dotnet restore
    if ($LASTEXITCODE -ne 0) { throw "Package restore failed" }

    # Step 2: Build and publish
    Write-Host "Building and publishing application..." -ForegroundColor Cyan
    dotnet publish -c $Configuration -o $TargetPath --no-restore
    if ($LASTEXITCODE -ne 0) { throw "Build/publish failed" }

    # Step 3: Copy additional files
    Write-Host "Copying additional deployment files..." -ForegroundColor Cyan
    
    $filesToCopy = @(
        "web.config",
        "start-windows.ps1",
        "start-windows.bat", 
        "DEPLOYMENT.md",
        "README.md"
    )
    
    foreach ($file in $filesToCopy) {
        if (Test-Path $file) {
            Copy-Item $file -Destination $TargetPath -Force
            Write-Host "  Copied: $file" -ForegroundColor Gray
        }
    }

    # Step 4: Create logs directory
    $logsPath = Join-Path $TargetPath "logs"
    New-Item -Path $logsPath -ItemType Directory -Force | Out-Null
    Write-Host "  Created logs directory" -ForegroundColor Gray

    # Step 5: Validate deployment
    Write-Host "Validating deployment..." -ForegroundColor Cyan
    $requiredFiles = @(
        "IISAppPoolRecycler.dll",
        "web.config",
        "appsettings.json"
    )
    
    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $TargetPath $file
        if (-not (Test-Path $filePath)) {
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -gt 0) {
        Write-Host "ERROR: Missing required files:" -ForegroundColor Red
        $missingFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        throw "Deployment validation failed"
    }

    Write-Host ""
    Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Deployment location: $TargetPath" -ForegroundColor Yellow
    Write-Host "Files deployed:" -ForegroundColor Yellow
    Get-ChildItem $TargetPath -File | ForEach-Object { 
        Write-Host "  - $($_.Name)" -ForegroundColor Gray 
    }
    
    Write-Host ""
    Write-Host "Next steps for IIS deployment:" -ForegroundColor Yellow
    Write-Host "1. Copy contents of '$TargetPath' to your IIS application folder" -ForegroundColor Cyan
    Write-Host "2. Ensure the Application Pool has 'Load User Profile' enabled" -ForegroundColor Cyan
    Write-Host "3. Ensure the Application Pool identity has IIS management permissions" -ForegroundColor Cyan
    Write-Host "4. Configure Uptime Kuma webhook to point to your IIS application" -ForegroundColor Cyan
    
    Write-Host ""
    Write-Host "To test locally, run:" -ForegroundColor Yellow
    Write-Host "cd $TargetPath && dotnet IISAppPoolRecycler.dll" -ForegroundColor Cyan

} catch {
    Write-Host ""
    Write-Host "❌ Deployment failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
