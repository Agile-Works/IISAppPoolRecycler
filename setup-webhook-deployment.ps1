# GitHub Webhook to IIS Kudu - Setup Script
# Run this script on your IIS server as Administrator

param(
    [string]$WebhookPath = "C:\kudu-webhooks",
    [string]$SiteName = "Default Web Site",
    [string]$WebhookAppName = "github-webhook",
    [string]$WebhookSecret = "",
    [string]$DeploymentPath = "C:\inetpub\wwwroot\IISRecycler",
    [string]$AppPoolName = "DefaultAppPool"
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "GitHub Webhook to IIS Kudu Setup" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script requires administrator privileges!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Running as Administrator" -ForegroundColor Green

# Generate webhook secret if not provided
if ([string]::IsNullOrEmpty($WebhookSecret)) {
    $WebhookSecret = [System.Web.Security.Membership]::GeneratePassword(32, 8)
    Write-Host "Generated webhook secret: $WebhookSecret" -ForegroundColor Yellow
    Write-Host "IMPORTANT: Save this secret for GitHub webhook configuration!" -ForegroundColor Red
}

# Check prerequisites
Write-Host "`nChecking prerequisites..." -ForegroundColor Cyan

# Check IIS
try {
    Import-Module WebAdministration -ErrorAction Stop
    Write-Host "✅ IIS WebAdministration module available" -ForegroundColor Green
} catch {
    Write-Host "❌ IIS WebAdministration module not available" -ForegroundColor Red
    exit 1
}

# Check PHP (for webhook receiver)
try {
    php --version | Out-Null
    Write-Host "✅ PHP is available" -ForegroundColor Green
} catch {
    Write-Host "⚠️ PHP not found - you may need to install PHP for webhook receiver" -ForegroundColor Yellow
    Write-Host "Alternative: You can use the PowerShell webhook receiver instead" -ForegroundColor Yellow
}

# Check Git
try {
    git --version | Out-Null
    Write-Host "✅ Git is available" -ForegroundColor Green
} catch {
    Write-Host "❌ Git not found - required for repository cloning" -ForegroundColor Red
    exit 1
}

# Create webhook directory
Write-Host "`nSetting up webhook infrastructure..." -ForegroundColor Cyan

if (Test-Path $WebhookPath) {
    Write-Host "Webhook directory already exists: $WebhookPath" -ForegroundColor Yellow
} else {
    New-Item -Path $WebhookPath -ItemType Directory -Force | Out-Null
    Write-Host "✅ Created webhook directory: $WebhookPath" -ForegroundColor Green
}

# Download webhook files from repository
Write-Host "Downloading webhook files..." -ForegroundColor Yellow

$files = @(
    "webhook-receiver.php",
    "deploy-webhook.bat",
    "config.ini.example"
)

foreach ($file in $files) {
    $url = "https://raw.githubusercontent.com/Agile-Works/IISAppPoolRecycler/main/$file"
    $destination = Join-Path $WebhookPath $file
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
        Write-Host "✅ Downloaded: $file" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Failed to download: $file" -ForegroundColor Yellow
        Write-Host "You may need to copy this file manually" -ForegroundColor Gray
    }
}

# Create configuration file
$configPath = Join-Path $WebhookPath "config.ini"
Write-Host "`nCreating configuration file..." -ForegroundColor Yellow

$configContent = @"
[webhook]
secret=$WebhookSecret
repository=Agile-Works/IISAppPoolRecycler
branch=main
deployment_path=$DeploymentPath
app_pool_name=$AppPoolName
test_endpoint=http://localhost/IISRecycler/api/webhook/app-pools
"@

Set-Content -Path $configPath -Value $configContent
Write-Host "✅ Configuration file created: $configPath" -ForegroundColor Green

# Configure IIS application for webhook
Write-Host "`nConfiguring IIS application..." -ForegroundColor Cyan

try {
    # Check if application already exists
    $existingApp = Get-WebApplication -Site $SiteName -Name $WebhookAppName -ErrorAction SilentlyContinue
    
    if ($existingApp) {
        Write-Host "Updating existing webhook application..." -ForegroundColor Yellow
        Set-WebApplication -Site $SiteName -Name $WebhookAppName -PhysicalPath $WebhookPath
    } else {
        Write-Host "Creating new webhook application..." -ForegroundColor Yellow
        New-WebApplication -Site $SiteName -Name $WebhookAppName -PhysicalPath $WebhookPath
    }
    
    Write-Host "✅ IIS webhook application configured" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Failed to configure IIS application: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Set permissions
Write-Host "`nSetting permissions..." -ForegroundColor Cyan

try {
    # Give IIS_IUSRS permission to webhook directory
    $acl = Get-Acl $WebhookPath
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $WebhookPath -AclObject $acl
    
    Write-Host "✅ Permissions set for IIS_IUSRS" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Failed to set permissions - you may need to set them manually" -ForegroundColor Yellow
}

# Test webhook endpoint
Write-Host "`nTesting webhook endpoint..." -ForegroundColor Cyan

$webhookUrl = "http://localhost/$WebhookAppName/webhook-receiver.php"
try {
    $response = Invoke-WebRequest -Uri $webhookUrl -Method GET -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 401) {
        Write-Host "✅ Webhook endpoint is accessible" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️ Webhook endpoint test failed - check PHP configuration" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nWebhook Configuration:" -ForegroundColor Cyan
Write-Host "  Webhook URL: http://your-server-ip/$WebhookAppName/webhook-receiver.php" -ForegroundColor White
Write-Host "  Secret: $WebhookSecret" -ForegroundColor Yellow
Write-Host "  Directory: $WebhookPath" -ForegroundColor White

Write-Host "`nGitHub Webhook Settings:" -ForegroundColor Cyan
Write-Host "  1. Go to: https://github.com/Agile-Works/IISAppPoolRecycler/settings/hooks" -ForegroundColor White
Write-Host "  2. Add webhook with:" -ForegroundColor White
Write-Host "     - Payload URL: http://your-server-ip/$WebhookAppName/webhook-receiver.php" -ForegroundColor Gray
Write-Host "     - Content type: application/json" -ForegroundColor Gray
Write-Host "     - Secret: $WebhookSecret" -ForegroundColor Gray
Write-Host "     - Events: Just the push event" -ForegroundColor Gray

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Configure GitHub webhook with the settings above" -ForegroundColor White
Write-Host "  2. Ensure your server is accessible from the internet" -ForegroundColor White
Write-Host "  3. Test with a commit to the repository" -ForegroundColor White
Write-Host "  4. Monitor logs: $WebhookPath\webhook.log" -ForegroundColor White

Write-Host "`nMonitoring Commands:" -ForegroundColor Cyan
Write-Host "  View webhook logs: Get-Content $WebhookPath\webhook.log -Tail 20" -ForegroundColor Gray
Write-Host "  View deployment logs: Get-Content $WebhookPath\webhook-deployment.log -Tail 20" -ForegroundColor Gray

Write-Host "`nSetup completed successfully! 🎉" -ForegroundColor Green
