# Quick IIS Fix Script for ASP.NET Core Deployment Issues
# Run this script on your IIS server as Administrator to fix common deployment issues

param(
    [string]$ApplicationPath = "C:\inetpub\wwwroot",
    [string]$AppName = "IISRecycler",
    [string]$SiteName = "Default Web Site"
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "Quick IIS Fix for ASP.NET Core App" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

$AppPath = Join-Path $ApplicationPath $AppName

Write-Host "`n🔍 STEP 1: Checking Application Files..." -ForegroundColor Yellow

if (!(Test-Path "$AppPath\IISAppPoolRecycler.dll")) {
    Write-Host "❌ Application DLL not found at: $AppPath\IISAppPoolRecycler.dll" -ForegroundColor Red
    Write-Host "Please verify deployment completed successfully" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Application files found" -ForegroundColor Green

Write-Host "`n🔧 STEP 2: Fixing Application Pool Configuration..." -ForegroundColor Yellow

try {
    Import-Module WebAdministration -ErrorAction Stop
    
    # Get or create application
    $app = Get-WebApplication -Site $SiteName -Name $AppName -ErrorAction SilentlyContinue
    if (!$app) {
        Write-Host "Creating IIS application..." -ForegroundColor Cyan
        New-WebApplication -Site $SiteName -Name $AppName -PhysicalPath $AppPath
        $app = Get-WebApplication -Site $SiteName -Name $AppName
    }
    
    $appPoolName = $app.ApplicationPool
    Write-Host "✅ Application Pool: $appPoolName" -ForegroundColor Green
    
    # Fix Application Pool Settings
    Write-Host "Configuring Application Pool settings..." -ForegroundColor Cyan
    
    # Set .NET CLR Version to "No Managed Code" (critical for .NET Core)
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name managedRuntimeVersion -Value ""
    Write-Host "✅ Set .NET CLR Version to 'No Managed Code'" -ForegroundColor Green
    
    # Enable Load User Profile
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name processModel.loadUserProfile -Value $true
    Write-Host "✅ Enabled Load User Profile" -ForegroundColor Green
    
    # Set Identity to ApplicationPoolIdentity
    Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name processModel.identityType -Value ApplicationPoolIdentity
    Write-Host "✅ Set Identity to ApplicationPoolIdentity" -ForegroundColor Green
    
    # Restart Application Pool
    Write-Host "Restarting Application Pool..." -ForegroundColor Cyan
    Restart-WebAppPool -Name $appPoolName
    Start-Sleep -Seconds 3
    Write-Host "✅ Application Pool restarted" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error configuring IIS: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n📁 STEP 3: Creating Logs Directory..." -ForegroundColor Yellow

$logPath = Join-Path $AppPath "logs"
if (!(Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    Write-Host "✅ Created logs directory: $logPath" -ForegroundColor Green
} else {
    Write-Host "✅ Logs directory exists: $logPath" -ForegroundColor Green
}

# Set permissions on logs directory
try {
    $acl = Get-Acl $logPath
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $logPath -AclObject $acl
    Write-Host "✅ Set permissions on logs directory" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Warning: Could not set logs directory permissions" -ForegroundColor Yellow
}

Write-Host "`n🌐 STEP 4: Testing HTTP Endpoints..." -ForegroundColor Yellow

Start-Sleep -Seconds 5  # Give the app time to start

$baseUrl = "http://localhost/$AppName"
$testUrls = @(
    "$baseUrl",
    "$baseUrl/swagger",
    "$baseUrl/api/webhook/sites"
)

$anySuccess = $false
foreach ($url in $testUrls) {
    try {
        Write-Host "Testing: $url" -ForegroundColor Gray
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-Host "✅ $url - Status: $($response.StatusCode)" -ForegroundColor Green
        $anySuccess = $true
    } catch {
        $statusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "No Response" }
        Write-Host "❌ $url - Error: $statusCode" -ForegroundColor Red
    }
}

Write-Host "`n📋 STEP 5: Checking Application Logs..." -ForegroundColor Yellow

$logFiles = Get-ChildItem "$logPath\stdout*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($logFiles) {
    $latestLog = $logFiles | Select-Object -First 1
    Write-Host "📄 Latest log: $($latestLog.Name)" -ForegroundColor Cyan
    Write-Host "Last 10 lines:" -ForegroundColor Gray
    Get-Content $latestLog.FullName -Tail 10 | ForEach-Object {
        if ($_ -match "error|exception|fail|fatal") {
            Write-Host "   $_" -ForegroundColor Red
        } elseif ($_ -match "warn") {
            Write-Host "   $_" -ForegroundColor Yellow
        } else {
            Write-Host "   $_" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "⚠️ No log files found. This might indicate the app isn't starting." -ForegroundColor Yellow
}

Write-Host "`n========================================" -ForegroundColor Green
if ($anySuccess) {
    Write-Host "🎉 SUCCESS! Application is responding!" -ForegroundColor Green
    Write-Host "✅ Your IIS deployment is working!" -ForegroundColor Green
} else {
    Write-Host "❌ Application still not responding" -ForegroundColor Red
    Write-Host "`n🔧 Additional Steps to Try:" -ForegroundColor Yellow
    Write-Host "1. Check Windows Event Viewer for errors" -ForegroundColor Gray
    Write-Host "2. Verify ASP.NET Core Runtime is installed:" -ForegroundColor Gray
    Write-Host "   dotnet --list-runtimes" -ForegroundColor Gray
    Write-Host "3. Try the diagnostic web.config:" -ForegroundColor Gray
    Write-Host "   copy web.config.diagnostic web.config" -ForegroundColor Gray
    Write-Host "4. Check if port 80 is blocked by firewall" -ForegroundColor Gray
    Write-Host "5. Verify the application pool is running:" -ForegroundColor Gray
    Write-Host "   Get-WebAppPoolState -Name '$appPoolName'" -ForegroundColor Gray
}

Write-Host "`n📚 Useful URLs (replace localhost with your server IP):" -ForegroundColor Cyan
Write-Host "  Swagger UI: http://localhost/$AppName/swagger" -ForegroundColor White
Write-Host "  API Test:   http://localhost/$AppName/api/webhook/sites" -ForegroundColor White
Write-Host "  Uptime Kuma Webhook: http://localhost/$AppName/api/webhook/uptime-kuma" -ForegroundColor White

Write-Host "`nScript completed!" -ForegroundColor Green
