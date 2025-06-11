# GitHub Webhook Testing Tool
# Use this script to test your webhook endpoint manually

param(
    [string]$WebhookUrl = "",
    [string]$Secret = "",
    [string]$Repository = "Agile-Works/IISAppPoolRecycler",
    [string]$Branch = "main",
    [string]$CommitMessage = "Test webhook deployment"
)

function Write-TestLog {
    param([string]$Message, [string]$Type = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    switch ($Type) {
        "Success" { Write-Host "✅ [$timestamp] $Message" -ForegroundColor Green }
        "Warning" { Write-Host "⚠️  [$timestamp] $Message" -ForegroundColor Yellow }
        "Error" { Write-Host "❌ [$timestamp] $Message" -ForegroundColor Red }
        default { Write-Host "ℹ️  [$timestamp] $Message" -ForegroundColor Cyan }
    }
}

function Test-WebhookEndpoint {
    param([string]$Url)
    
    Write-TestLog "Testing webhook endpoint accessibility..." "Info"
    
    try {
        # Test basic connectivity
        $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 10 -ErrorAction Stop
        Write-TestLog "Endpoint is accessible (Status: $($response.StatusCode))" "Success"
        return $true
    } catch {
        Write-TestLog "Endpoint not accessible: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-WebhookHealth {
    param([string]$Url)
    
    Write-TestLog "Testing webhook health endpoint..." "Info"
    
    try {
        $healthUrl = $Url + "?health"
        $response = Invoke-RestMethod -Uri $healthUrl -Method GET -TimeoutSec 10
        
        Write-TestLog "Health check response:" "Info"
        Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor Cyan
        
        if ($response.status -eq "healthy") {
            Write-TestLog "Webhook service is healthy" "Success"
            return $true
        } else {
            Write-TestLog "Webhook service health check failed" "Warning"
            return $false
        }
    } catch {
        Write-TestLog "Health check failed: $($_.Exception.Message)" "Warning"
        return $false
    }
}

function Send-TestWebhook {
    param([string]$Url, [string]$Secret, [string]$Repository, [string]$Branch, [string]$CommitMessage)
    
    Write-TestLog "Sending test webhook payload..." "Info"
    
    # Create a realistic GitHub webhook payload
    $payload = @{
        ref = "refs/heads/$Branch"
        repository = @{
            full_name = $Repository
            name = $Repository.Split('/')[1]
            clone_url = "https://github.com/$Repository.git"
        }
        pusher = @{
            name = "webhook-tester"
            email = "test@example.com"
        }
        commits = @(
            @{
                id = (New-Guid).ToString().Replace('-', '').Substring(0, 40)
                message = $CommitMessage
                timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
                author = @{
                    name = "Test User"
                    email = "test@example.com"
                }
                added = @()
                removed = @()
                modified = @("test-file.txt")
            }
        )
        head_commit = @{
            id = (New-Guid).ToString().Replace('-', '').Substring(0, 40)
            message = $CommitMessage
            timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
            author = @{
                name = "Test User"
                email = "test@example.com"
            }
        }
    }
    
    $payloadJson = $payload | ConvertTo-Json -Depth 5
    
    # Create webhook signature if secret is provided
    $headers = @{
        'Content-Type' = 'application/json'
        'User-Agent' = 'GitHub-Hookshot/webhook-test'
        'X-GitHub-Event' = 'push'
        'X-GitHub-Delivery' = (New-Guid).ToString()
    }
    
    if ($Secret) {
        Write-TestLog "Calculating webhook signature..." "Info"
        $hmac = New-Object System.Security.Cryptography.HMACSHA256
        $hmac.Key = [Text.Encoding]::UTF8.GetBytes($Secret)
        $signature = [System.BitConverter]::ToString($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($payloadJson)))
        $signature = "sha256=" + $signature.Replace('-', '').ToLower()
        $headers['X-Hub-Signature-256'] = $signature
        Write-TestLog "Signature: $($signature.Substring(0, 20))..." "Info"
    } else {
        Write-TestLog "No secret provided - sending without signature" "Warning"
    }
    
    try {
        Write-TestLog "Sending POST request to webhook endpoint..." "Info"
        $response = Invoke-RestMethod -Uri $Url -Method POST -Body $payloadJson -Headers $headers -TimeoutSec 30
        
        Write-TestLog "Webhook response received:" "Success"
        Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor Green
        
        return $true
    } catch {
        Write-TestLog "Webhook test failed: $($_.Exception.Message)" "Error"
        
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            Write-TestLog "HTTP Status Code: $statusCode" "Error"
            
            try {
                $errorResponse = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorResponse)
                $errorBody = $reader.ReadToEnd()
                Write-TestLog "Error Response: $errorBody" "Error"
            } catch {
                Write-TestLog "Could not read error response body" "Warning"
            }
        }
        
        return $false
    }
}

function Get-UserInput {
    if (-not $WebhookUrl) {
        do {
            $WebhookUrl = Read-Host "Enter your webhook URL (e.g., http://your-server-ip/github-webhook/webhook-receiver.php)"
        } while (-not $WebhookUrl)
    }
    
    if (-not $Secret) {
        $Secret = Read-Host "Enter your webhook secret (leave empty to skip signature verification)" -AsSecureString
        if ($Secret.Length -gt 0) {
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
            $Secret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        } else {
            $Secret = ""
        }
    }
    
    return @{
        Url = $WebhookUrl
        Secret = $Secret
    }
}

# Main execution
Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "🧪 GitHub Webhook Testing Tool" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

# Get user input if not provided
$config = Get-UserInput
$WebhookUrl = $config.Url
$Secret = $config.Secret

Write-TestLog "Starting webhook tests..." "Info"
Write-TestLog "Target URL: $WebhookUrl" "Info"
Write-TestLog "Repository: $Repository" "Info"
Write-TestLog "Branch: $Branch" "Info"

# Run tests
$tests = @()

# Test 1: Basic connectivity
Write-Host ""
Write-Host "🔍 Test 1: Basic Connectivity" -ForegroundColor Yellow
$connectivityResult = Test-WebhookEndpoint -Url $WebhookUrl
$tests += @{ Name = "Basic Connectivity"; Result = $connectivityResult }

# Test 2: Health check
Write-Host ""
Write-Host "🔍 Test 2: Health Check" -ForegroundColor Yellow
$healthResult = Test-WebhookHealth -Url $WebhookUrl
$tests += @{ Name = "Health Check"; Result = $healthResult }

# Test 3: Webhook payload
Write-Host ""
Write-Host "🔍 Test 3: Webhook Payload" -ForegroundColor Yellow
$webhookResult = Send-TestWebhook -Url $WebhookUrl -Secret $Secret -Repository $Repository -Branch $Branch -CommitMessage $CommitMessage
$tests += @{ Name = "Webhook Payload"; Result = $webhookResult }

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Blue
Write-Host "📊 Test Summary" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue

$passedTests = 0
$totalTests = $tests.Count

foreach ($test in $tests) {
    $status = if ($test.Result) { "PASS" } else { "FAIL" }
    $color = if ($test.Result) { "Green" } else { "Red" }
    $icon = if ($test.Result) { "✅" } else { "❌" }
    
    Write-Host "$icon $($test.Name): $status" -ForegroundColor $color
    if ($test.Result) { $passedTests++ }
}

Write-Host ""
Write-Host "Results: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })

if ($passedTests -eq $totalTests) {
    Write-Host ""
    Write-Host "🎉 All tests passed! Your webhook is ready for GitHub integration." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Configure the webhook in GitHub with the URL and secret above" -ForegroundColor White
    Write-Host "2. Make a test commit to trigger automatic deployment" -ForegroundColor White
    Write-Host "3. Monitor deployment logs on your server" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "⚠️  Some tests failed. Please check your webhook configuration." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Cyan
    Write-Host "1. Verify your server is accessible from the internet" -ForegroundColor White
    Write-Host "2. Check firewall settings (port 80/443)" -ForegroundColor White
    Write-Host "3. Ensure PHP is installed and configured (if using PHP receiver)" -ForegroundColor White
    Write-Host "4. Verify webhook files are in the correct directory" -ForegroundColor White
    Write-Host "5. Check IIS application configuration" -ForegroundColor White
}

Write-Host ""
