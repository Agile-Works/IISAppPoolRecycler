# Complete GitHub to IIS Kudu Continuous Deployment Setup
# Run this script on your IIS server as Administrator

param(
    [string]$ServerIP = "",
    [string]$WebhookSecret = "",
    [string]$DeploymentPath = "C:\inetpub\wwwroot\IISRecycler",
    [string]$WebhookPath = "C:\kudu-webhooks",
    [string]$SiteName = "Default Web Site",
    [string]$WebhookAppName = "github-webhook",
    [string]$AppPoolName = "DefaultAppPool",
    [string]$Repository = "Agile-Works/IISAppPoolRecycler",
    [string]$Branch = "main"
)

# Enhanced logging and UI
function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Type) {
        "Success" { 
            Write-Host "✅ [$timestamp] $Message" -ForegroundColor Green 
            Add-Content -Path "$WebhookPath\setup.log" -Value "SUCCESS [$timestamp] $Message"
        }
        "Warning" { 
            Write-Host "⚠️  [$timestamp] $Message" -ForegroundColor Yellow 
            Add-Content -Path "$WebhookPath\setup.log" -Value "WARNING [$timestamp] $Message"
        }
        "Error" { 
            Write-Host "❌ [$timestamp] $Message" -ForegroundColor Red 
            Add-Content -Path "$WebhookPath\setup.log" -Value "ERROR [$timestamp] $Message"
        }
        default { 
            Write-Host "ℹ️  [$timestamp] $Message" -ForegroundColor Cyan 
            Add-Content -Path "$WebhookPath\setup.log" -Value "INFO [$timestamp] $Message"
        }
    }
}

function Show-Banner {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "🚀 GitHub to IIS Continuous Deployment" -ForegroundColor Magenta
    Write-Host "   Complete Automated Setup" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ""
}

function Test-Prerequisites {
    Write-Status "Checking prerequisites..." "Info"
    
    # Check administrator privileges
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Status "This script requires administrator privileges!" "Error"
        exit 1
    }
    Write-Status "Administrator privileges confirmed" "Success"
    
    # Check IIS
    try {
        Import-Module WebAdministration -ErrorAction Stop
        Write-Status "IIS module available" "Success"
    } catch {
        Write-Status "IIS not available - please install IIS first" "Error"
        exit 1
    }
    
    # Check .NET
    try {
        $dotnetVersion = dotnet --version 2>$null
        if ($dotnetVersion) {
            Write-Status ".NET version: $dotnetVersion" "Success"
        } else {
            throw "dotnet not found"
        }
    } catch {
        Write-Status ".NET not found - please install .NET 6.0 Runtime" "Error"
        exit 1
    }
    
    # Check Git
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            Write-Status "Git available: $gitVersion" "Success"
        } else {
            throw "git not found"
        }
    } catch {
        Write-Status "Git not found - please install Git" "Error"
        exit 1
    }
    
    # Check PHP (for webhook receiver)
    try {
        $phpVersion = php --version 2>$null | Select-Object -First 1
        if ($phpVersion) {
            Write-Status "PHP available: $($phpVersion.Substring(0, 50))..." "Success"
        } else {
            Write-Status "PHP not found - installing PHP or use PowerShell webhook receiver" "Warning"
        }
    } catch {
        Write-Status "PHP not available - will use PowerShell webhook receiver instead" "Warning"
    }
}

function Get-UserInput {
    if (-not $ServerIP) {
        do {
            $ServerIP = Read-Host "Enter your server's public IP address or domain"
        } while (-not $ServerIP)
    }
    
    if (-not $WebhookSecret) {
        Write-Host "Generating secure webhook secret..." -ForegroundColor Yellow
        $WebhookSecret = [System.Convert]::ToBase64String([System.Security.Cryptography.RNGCryptoServiceProvider]::new().GetBytes(32))
        Write-Status "Generated webhook secret: $($WebhookSecret.Substring(0, 10))..." "Success"
    }
    
    return @{
        ServerIP = $ServerIP
        WebhookSecret = $WebhookSecret
    }
}

function Setup-WebhookInfrastructure {
    Write-Status "Setting up webhook infrastructure..." "Info"
    
    # Create webhook directory
    if (Test-Path $WebhookPath) {
        Write-Status "Webhook directory already exists: $WebhookPath" "Warning"
    } else {
        New-Item -Path $WebhookPath -ItemType Directory -Force | Out-Null
        Write-Status "Created webhook directory: $WebhookPath" "Success"
    }
    
    # Create deployment target directory
    if (-not (Test-Path $DeploymentPath)) {
        New-Item -Path $DeploymentPath -ItemType Directory -Force | Out-Null
        Write-Status "Created deployment directory: $DeploymentPath" "Success"
    }
    
    # Download webhook files from repository
    Write-Status "Downloading webhook files from GitHub..." "Info"
    
    $files = @(
        @{ Source = "webhook-receiver.php"; Destination = "webhook-receiver.php" },
        @{ Source = "deploy-webhook.bat"; Destination = "deploy-webhook.bat" },
        @{ Source = "config.ini.example"; Destination = "config.ini.example" }
    )
    
    foreach ($file in $files) {
        try {
            $url = "https://raw.githubusercontent.com/$Repository/main/$($file.Source)"
            $destinationPath = Join-Path $WebhookPath $file.Destination
            
            Invoke-WebRequest -Uri $url -OutFile $destinationPath -UseBasicParsing
            Write-Status "Downloaded: $($file.Source)" "Success"
        } catch {
            Write-Status "Failed to download $($file.Source): $($_.Exception.Message)" "Warning"
        }
    }
}

function Create-WebhookConfiguration {
    Write-Status "Creating webhook configuration..." "Info"
    
    $configContent = @"
# GitHub Webhook to IIS Kudu Deployment Configuration
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

[webhook]
secret=$WebhookSecret
repository=$Repository
deployment_path=$DeploymentPath
branch=$Branch
app_pool_name=$AppPoolName

[logging]
enabled=true
log_file=webhook-deployment.log
debug_mode=false

[deployment]
backup_before_deploy=true
restart_app_pool=true
test_endpoint=http://localhost/IISRecycler/api/webhook/sites
"@
    
    $configPath = Join-Path $WebhookPath "config.ini"
    Set-Content -Path $configPath -Value $configContent
    Write-Status "Created configuration file: $configPath" "Success"
    
    # Set secure permissions on config file
    try {
        $acl = Get-Acl $configPath
        $acl.SetAccessRuleProtection($true, $false)
        $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
        $acl.SetAccessRule($adminRule)
        $acl.SetAccessRule($systemRule)
        Set-Acl -Path $configPath -AclObject $acl
        Write-Status "Set secure permissions on configuration file" "Success"
    } catch {
        Write-Status "Warning: Could not set secure permissions on config file" "Warning"
    }
}

function Setup-IISApplication {
    Write-Status "Configuring IIS application for webhook..." "Info"
    
    try {
        # Check if website exists
        $website = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
        if (-not $website) {
            Write-Status "Website '$SiteName' not found - please create it first" "Error"
            return $false
        }
        
        # Create webhook application
        $webApp = Get-WebApplication -Site $SiteName -Name $WebhookAppName -ErrorAction SilentlyContinue
        if ($webApp) {
            Write-Status "Webhook application already exists" "Warning"
        } else {
            New-WebApplication -Site $SiteName -Name $WebhookAppName -PhysicalPath $WebhookPath
            Write-Status "Created IIS application: /$WebhookAppName" "Success"
        }
        
        # Create main application if it doesn't exist
        $mainApp = Get-WebApplication -Site $SiteName -Name "IISRecycler" -ErrorAction SilentlyContinue
        if (-not $mainApp) {
            New-WebApplication -Site $SiteName -Name "IISRecycler" -PhysicalPath $DeploymentPath -ApplicationPool $AppPoolName
            Write-Status "Created main IIS application: /IISRecycler" "Success"
        }
        
        # Configure application pool
        $appPool = Get-IISAppPool -Name $AppPoolName -ErrorAction SilentlyContinue
        if ($appPool) {
            Set-ItemProperty -Path "IIS:\AppPools\$AppPoolName" -Name processModel.loadUserProfile -Value $true
            Write-Status "Configured application pool: $AppPoolName" "Success"
        }
        
        return $true
    } catch {
        Write-Status "Failed to configure IIS: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Create-PowerShellWebhookReceiver {
    Write-Status "Creating PowerShell webhook receiver as backup..." "Info"
    
    $psWebhookContent = @'
# PowerShell Webhook Receiver for GitHub to IIS Deployment
# This is an alternative to the PHP receiver

param(
    [string]$ConfigPath = ".\config.ini"
)

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path "webhook.log" -Value "[$timestamp] $Message"
    Write-Host "[$timestamp] $Message"
}

try {
    # Read configuration
    if (-not (Test-Path $ConfigPath)) {
        Write-Log "ERROR: Configuration file not found: $ConfigPath"
        exit 1
    }
    
    $config = @{}
    Get-Content $ConfigPath | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $config[$matches[1]] = $matches[2]
        }
    }
    
    Write-Log "Webhook request received"
    Write-Log "Starting deployment process..."
    
    # Change to webhook directory
    Set-Location -Path $PSScriptRoot
    
    # Execute deployment script
    $deployScript = ".\deploy-webhook.bat"
    if (Test-Path $deployScript) {
        Write-Log "Executing deployment script: $deployScript"
        & cmd.exe /c $deployScript
        Write-Log "Deployment script completed"
    } else {
        Write-Log "ERROR: Deployment script not found: $deployScript"
        exit 1
    }
    
    Write-Log "Webhook processing completed successfully"
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    exit 1
}
'@
    
    $psWebhookPath = Join-Path $WebhookPath "webhook-receiver.ps1"
    Set-Content -Path $psWebhookPath -Value $psWebhookContent
    Write-Status "Created PowerShell webhook receiver: $psWebhookPath" "Success"
}

function Test-WebhookEndpoint {
    Write-Status "Testing webhook endpoint..." "Info"
    
    $webhookUrl = "http://$ServerIP/$WebhookAppName/webhook-receiver.php"
    
    try {
        $response = Invoke-WebRequest -Uri $webhookUrl -Method GET -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 405) {
            Write-Status "Webhook endpoint is accessible: $webhookUrl" "Success"
        }
    } catch {
        Write-Status "Webhook endpoint test failed - this is normal if PHP is not configured" "Warning"
        Write-Status "Alternative PowerShell receiver has been created" "Info"
    }
}

function Show-GitHubInstructions {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "🎯 GitHub Webhook Configuration" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "1. Go to your GitHub repository:" -ForegroundColor Cyan
    Write-Host "   https://github.com/$Repository/settings/hooks" -ForegroundColor White
    
    Write-Host ""
    Write-Host "2. Click 'Add webhook' and configure:" -ForegroundColor Cyan
    Write-Host "   Payload URL: http://$ServerIP/$WebhookAppName/webhook-receiver.php" -ForegroundColor Yellow
    Write-Host "   Content type: application/json" -ForegroundColor White
    Write-Host "   Secret: $WebhookSecret" -ForegroundColor Yellow
    Write-Host "   Events: Just the push event" -ForegroundColor White
    Write-Host "   Active: ✅ Checked" -ForegroundColor White
    
    Write-Host ""
    Write-Host "3. Alternative PowerShell endpoint (if PHP unavailable):" -ForegroundColor Cyan
    Write-Host "   Create a scheduled task or web endpoint to call:" -ForegroundColor White
    Write-Host "   PowerShell.exe -File '$WebhookPath\webhook-receiver.ps1'" -ForegroundColor Yellow
}

function Show-TestingInstructions {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "🧪 Testing Your Setup" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    
    Write-Host ""
    Write-Host "1. Test manual deployment:" -ForegroundColor Cyan
    Write-Host "   cd $WebhookPath" -ForegroundColor Gray
    Write-Host "   .\deploy-webhook.bat" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "2. Test webhook delivery:" -ForegroundColor Cyan
    Write-Host "   Make a small commit to your repository" -ForegroundColor Gray
    Write-Host "   Check GitHub webhook delivery status" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "3. Monitor deployment logs:" -ForegroundColor Cyan
    Write-Host "   Get-Content $WebhookPath\webhook-deployment.log -Tail 20" -ForegroundColor Gray
    Write-Host "   Get-Content $WebhookPath\webhook.log -Tail 20" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "4. Test the deployed application:" -ForegroundColor Cyan
    Write-Host "   curl http://$ServerIP/IISRecycler/api/webhook/sites" -ForegroundColor Gray
    Write-Host "   curl http://$ServerIP/IISRecycler/swagger" -ForegroundColor Gray
}

function Show-MonitoringSetup {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "📊 Monitoring & Maintenance" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
    
    Write-Host ""
    Write-Host "Deployment Monitoring Commands:" -ForegroundColor Cyan
    Write-Host "  View recent deployments:" -ForegroundColor White
    Write-Host "    Get-Content $WebhookPath\webhook-deployment.log -Tail 50" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Check application status:" -ForegroundColor White
    Write-Host "    Invoke-WebRequest http://$ServerIP/IISRecycler/api/webhook/sites" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Monitor IIS application pool:" -ForegroundColor White
    Write-Host "    Get-IISAppPool -Name $AppPoolName | Select-Object Name, State" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Check GitHub webhook deliveries:" -ForegroundColor White
    Write-Host "    Visit: https://github.com/$Repository/settings/hooks" -ForegroundColor Gray
}

function Generate-SetupSummary {
    $summaryPath = Join-Path $WebhookPath "setup-summary.txt"
    $summary = @"
GitHub to IIS Continuous Deployment Setup Summary
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Configuration:
- Server IP: $ServerIP
- Repository: $Repository
- Branch: $Branch
- Webhook Path: $WebhookPath
- Deployment Path: $DeploymentPath
- Application Pool: $AppPoolName

Webhook URL: http://$ServerIP/$WebhookAppName/webhook-receiver.php
Secret: $WebhookSecret

Files Created:
- $WebhookPath\config.ini
- $WebhookPath\webhook-receiver.php (downloaded)
- $WebhookPath\deploy-webhook.bat (downloaded)
- $WebhookPath\webhook-receiver.ps1 (PowerShell alternative)
- $WebhookPath\setup.log
- $WebhookPath\setup-summary.txt

IIS Configuration:
- Application: /$WebhookAppName -> $WebhookPath
- Application: /IISRecycler -> $DeploymentPath
- App Pool: $AppPoolName (Load User Profile enabled)

Next Steps:
1. Configure GitHub webhook with the URL and secret above
2. Test with a commit to the repository
3. Monitor logs in $WebhookPath
4. Verify application deployment

Support:
- Setup logs: $WebhookPath\setup.log
- Deployment logs: $WebhookPath\webhook-deployment.log
- Webhook logs: $WebhookPath\webhook.log
"@
    
    Set-Content -Path $summaryPath -Value $summary
    Write-Status "Generated setup summary: $summaryPath" "Success"
}

# Main execution
try {
    Show-Banner
    
    # Get user input
    $userConfig = Get-UserInput
    $ServerIP = $userConfig.ServerIP
    $WebhookSecret = $userConfig.WebhookSecret
    
    # Run setup steps
    Test-Prerequisites
    Setup-WebhookInfrastructure
    Create-WebhookConfiguration
    
    $iisConfigured = Setup-IISApplication
    if (-not $iisConfigured) {
        Write-Status "IIS configuration failed - please check manually" "Warning"
    }
    
    Create-PowerShellWebhookReceiver
    Test-WebhookEndpoint
    Generate-SetupSummary
    
    # Show instructions
    Show-GitHubInstructions
    Show-TestingInstructions
    Show-MonitoringSetup
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✅ Setup Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Status "Continuous deployment setup completed successfully!" "Success"
    
    Write-Host ""
    Write-Host "🚀 Your GitHub to IIS continuous deployment pipeline is ready!" -ForegroundColor Magenta
    Write-Host "   Configure the GitHub webhook and test with a commit." -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Status "Setup failed: $($_.Exception.Message)" "Error"
    Write-Host "Check the setup log for details: $WebhookPath\setup.log" -ForegroundColor Red
    exit 1
}
