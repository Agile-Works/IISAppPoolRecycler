# IIS ASP.NET Core Troubleshooting Script
# Run this script on your IIS server to diagnose deployment issues

param(
    [string]$ApplicationPath = "C:\inetpub\wwwroot",
    [string]$AppName = "IISRecycler"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IIS ASP.NET Core Deployment Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$AppPath = Join-Path $ApplicationPath $AppName

Write-Host "`n1. Checking Application Files..." -ForegroundColor Yellow

# Check if application files exist
if (Test-Path "$AppPath\IISAppPoolRecycler.dll") {
    Write-Host "✅ Application DLL found: IISAppPoolRecycler.dll" -ForegroundColor Green
} else {
    Write-Host "❌ Application DLL missing: IISAppPoolRecycler.dll" -ForegroundColor Red
    Write-Host "   Expected location: $AppPath\IISAppPoolRecycler.dll" -ForegroundColor Yellow
}

if (Test-Path "$AppPath\web.config") {
    Write-Host "✅ web.config found" -ForegroundColor Green
} else {
    Write-Host "❌ web.config missing" -ForegroundColor Red
}

if (Test-Path "$AppPath\appsettings.json") {
    Write-Host "✅ appsettings.json found" -ForegroundColor Green
} else {
    Write-Host "⚠️ appsettings.json missing (optional)" -ForegroundColor Yellow
}

Write-Host "`n2. Checking .NET Runtime..." -ForegroundColor Yellow

try {
    $dotnetVersion = dotnet --version
    Write-Host "✅ .NET CLI available: $dotnetVersion" -ForegroundColor Green
    
    $runtimes = dotnet --list-runtimes
    $aspNetCoreRuntime = $runtimes | Where-Object { $_ -match "Microsoft\.AspNetCore\.App 6\." }
    
    if ($aspNetCoreRuntime) {
        Write-Host "✅ ASP.NET Core 6.x runtime available" -ForegroundColor Green
        $aspNetCoreRuntime | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    } else {
        Write-Host "❌ ASP.NET Core 6.x runtime not found" -ForegroundColor Red
        Write-Host "   Available runtimes:" -ForegroundColor Yellow
        $runtimes | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    }
} catch {
    Write-Host "❌ .NET CLI not available" -ForegroundColor Red
}

Write-Host "`n3. Checking IIS Configuration..." -ForegroundColor Yellow

try {
    Import-Module WebAdministration -ErrorAction Stop
    
    # Check if application exists
    $app = Get-WebApplication -Site "Default Web Site" -Name $AppName -ErrorAction SilentlyContinue
    if ($app) {
        Write-Host "✅ IIS Application '$AppName' exists" -ForegroundColor Green
        Write-Host "   Physical Path: $($app.PhysicalPath)" -ForegroundColor Gray
        Write-Host "   Application Pool: $($app.ApplicationPool)" -ForegroundColor Gray
    } else {
        Write-Host "❌ IIS Application '$AppName' not found" -ForegroundColor Red
    }
    
    # Check application pool
    if ($app) {
        $appPool = Get-WebAppPoolState -Name $app.ApplicationPool -ErrorAction SilentlyContinue
        if ($appPool) {
            Write-Host "✅ Application Pool '$($app.ApplicationPool)' state: $($appPool.Value)" -ForegroundColor Green
            
            $poolConfig = Get-ItemProperty -Path "IIS:\AppPools\$($app.ApplicationPool)" -Name processModel.loadUserProfile -ErrorAction SilentlyContinue
            if ($poolConfig -and $poolConfig.Value -eq $true) {
                Write-Host "✅ Load User Profile enabled" -ForegroundColor Green
            } else {
                Write-Host "⚠️ Load User Profile not enabled (may cause issues)" -ForegroundColor Yellow
            }
        }
    }
    
} catch {
    Write-Host "❌ Cannot access IIS configuration: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n4. Checking Application Logs..." -ForegroundColor Yellow

$logPath = Join-Path $AppPath "logs"
if (Test-Path $logPath) {
    Write-Host "✅ Logs directory exists: $logPath" -ForegroundColor Green
    
    $logFiles = Get-ChildItem "$logPath\stdout*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if ($logFiles) {
        Write-Host "📋 Recent log files:" -ForegroundColor Cyan
        $logFiles | Select-Object -First 5 | ForEach-Object {
            Write-Host "   $($_.Name) - $($_.LastWriteTime)" -ForegroundColor Gray
        }
        
        Write-Host "`n📄 Latest log content (last 20 lines):" -ForegroundColor Cyan
        $latestLog = $logFiles | Select-Object -First 1
        Get-Content $latestLog.FullName -Tail 20 | ForEach-Object {
            if ($_ -match "error|exception|fail") {
                Write-Host "   $_" -ForegroundColor Red
            } elseif ($_ -match "warn") {
                Write-Host "   $_" -ForegroundColor Yellow
            } else {
                Write-Host "   $_" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "⚠️ No log files found in $logPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Logs directory missing: $logPath" -ForegroundColor Red
    Write-Host "   Creating logs directory..." -ForegroundColor Yellow
    try {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
        Write-Host "✅ Logs directory created" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to create logs directory: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n5. Testing Application Startup..." -ForegroundColor Yellow

if (Test-Path "$AppPath\IISAppPoolRecycler.dll") {
    try {
        Push-Location $AppPath
        Write-Host "Testing application startup manually..." -ForegroundColor Gray
        
        # Try to run the application manually to see startup errors
        $process = Start-Process -FilePath "dotnet" -ArgumentList "IISAppPoolRecycler.dll" -WorkingDirectory $AppPath -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 3
        
        if (!$process.HasExited) {
            Write-Host "✅ Application starts successfully" -ForegroundColor Green
            $process.Kill()
        } else {
            Write-Host "❌ Application failed to start (exit code: $($process.ExitCode))" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Error testing application: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        Pop-Location
    }
}

Write-Host "`n6. HTTP Response Test..." -ForegroundColor Yellow

$testUrls = @(
    "http://localhost/$AppName",
    "http://localhost/$AppName/swagger",
    "http://localhost/$AppName/api/webhook/sites"
)

foreach ($url in $testUrls) {
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        Write-Host "✅ $url - Status: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode) {
            Write-Host "⚠️ $url - Status: $statusCode" -ForegroundColor Yellow
        } else {
            Write-Host "❌ $url - Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Diagnostic Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`n🔧 Common Solutions:" -ForegroundColor White
Write-Host "1. Ensure ASP.NET Core 6.x runtime is installed" -ForegroundColor Gray
Write-Host "2. Enable 'Load User Profile' in Application Pool" -ForegroundColor Gray
Write-Host "3. Check application logs in the logs directory" -ForegroundColor Gray
Write-Host "4. Verify web.config configuration" -ForegroundColor Gray
Write-Host "5. Restart Application Pool: Restart-WebAppPool -Name 'YourAppPool'" -ForegroundColor Gray
Write-Host "6. Use diagnostic web.config: Copy web.config.diagnostic to web.config" -ForegroundColor Gray

Write-Host "`n📚 Additional Resources:" -ForegroundColor White
Write-Host "- KUDU-TROUBLESHOOTING.md in the repository" -ForegroundColor Gray
Write-Host "- Check Windows Event Viewer: Applications and Services Logs > Microsoft > Windows > IIS-W3SVC-WP" -ForegroundColor Gray
Write-Host "- IIS Manager: Check Failed Request Tracing if enabled" -ForegroundColor Gray

Write-Host "`nDiagnostics completed!" -ForegroundColor Green
