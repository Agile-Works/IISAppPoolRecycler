# GitHub to IIS Kudu - Continuous Deployment Setup

## 🚀 Automatic Deployment from GitHub to IIS with Kudu Webhooks

This guide sets up continuous deployment where every push to your GitHub repository automatically deploys to your IIS instance using Kudu.

## Architecture Overview

```
GitHub Repository → GitHub Webhook → Your IIS Server → Kudu Deployment Script → IIS Application
```

## Prerequisites

- IIS server with Kudu installed and configured
- Public IP or domain for your IIS server (for GitHub webhooks)
- GitHub repository: `https://github.com/Agile-Works/IISAppPoolRecycler`
- Administrator access to your IIS server

## Setup Steps

### Step 1: Configure Kudu Webhook Endpoint on Your IIS Server

1. **Create webhook receiver directory**:
   ```cmd
   mkdir C:\kudu-webhooks
   cd C:\kudu-webhooks
   ```

2. **Download the webhook receiver script**:
   ```cmd
   curl -o webhook-receiver.php https://raw.githubusercontent.com/Agile-Works/IISAppPoolRecycler/main/webhook-receiver.php
   curl -o deploy-webhook.bat https://raw.githubusercontent.com/Agile-Works/IISAppPoolRecycler/main/deploy-webhook.bat
   ```

3. **Configure IIS for webhook endpoint**:
   ```cmd
   :: Create IIS application for webhooks
   "%systemroot%\system32\inetsrv\appcmd" add app /site.name:"Default Web Site" /path:/github-webhook /physicalPath:"C:\kudu-webhooks"
   ```

### Step 2: Configure GitHub Repository Webhook

1. **Go to your GitHub repository**: https://github.com/Agile-Works/IISAppPoolRecycler

2. **Navigate to Settings > Webhooks**

3. **Add webhook**:
   - **Payload URL**: `http://your-server-ip/github-webhook/webhook-receiver.php`
   - **Content type**: `application/json`
   - **Secret**: (generate a secure secret - save this for Step 3)
   - **Events**: Select "Just the push event"
   - **Active**: ✅ Checked

4. **Test the webhook** by making a small commit

### Step 3: Secure Webhook Configuration

Create a configuration file on your server:

```cmd
:: Create webhook config
echo [webhook] > C:\kudu-webhooks\config.ini
echo secret=YOUR_WEBHOOK_SECRET_HERE >> C:\kudu-webhooks\config.ini
echo repository=Agile-Works/IISAppPoolRecycler >> C:\kudu-webhooks\config.ini
echo deployment_path=C:\inetpub\wwwroot\IISRecycler >> C:\kudu-webhooks\config.ini
echo branch=main >> C:\kudu-webhooks\config.ini
```

## Alternative: Kudu Service with Git Integration

If your Kudu installation supports Git integration directly:

### Option A: Kudu Git Deployment

1. **Configure Kudu for Git deployment**:
   ```cmd
   :: Configure Kudu to watch GitHub repository
   kudu config set repository.url https://github.com/Agile-Works/IISAppPoolRecycler.git
   kudu config set repository.branch main
   kudu config set deployment.path C:\inetpub\wwwroot\IISRecycler
   ```

2. **Set up GitHub webhook to Kudu endpoint**:
   - **Payload URL**: `http://your-server-ip:8080/api/deployment` (Kudu's default endpoint)
   - **Content type**: `application/json`
   - **Events**: Push events

### Option B: Azure DevOps Integration (If Available)

If you have Azure DevOps integration:

1. **Create Azure DevOps pipeline**
2. **Connect to GitHub repository**
3. **Configure deployment to your IIS server**

## Manual Setup Files

Let me create the necessary webhook receiver files:

### webhook-receiver.php
```php
<?php
// GitHub webhook receiver for IIS Kudu deployment
$payload = file_get_contents('php://input');
$signature = $_SERVER['HTTP_X_HUB_SIGNATURE_256'] ?? '';

// Load configuration
$config = parse_ini_file('config.ini');
$secret = $config['secret'];
$expected_signature = 'sha256=' . hash_hmac('sha256', $payload, $secret);

// Verify signature
if (!hash_equals($expected_signature, $signature)) {
    http_response_code(401);
    exit('Unauthorized');
}

// Parse payload
$data = json_decode($payload, true);

// Check if it's a push to main branch
if ($data['ref'] === 'refs/heads/' . $config['branch']) {
    // Log the deployment
    file_put_contents('deployment.log', date('Y-m-d H:i:s') . " - Deployment triggered\n", FILE_APPEND);
    
    // Execute deployment script
    exec('deploy-webhook.bat > deployment-output.log 2>&1 &');
    
    http_response_code(200);
    echo 'Deployment triggered';
} else {
    http_response_code(200);
    echo 'Not main branch, skipping deployment';
}
?>
```

### deploy-webhook.bat
```batch
@echo off
echo Starting GitHub webhook deployment...
echo %date% %time% - Deployment started >> deployment.log

:: Read configuration
for /f "tokens=1,2 delims==" %%a in (config.ini) do (
    if "%%a"=="deployment_path" set DEPLOYMENT_PATH=%%b
    if "%%a"=="repository" set REPOSITORY=%%b
)

:: Create temporary directory for clone
set TEMP_DIR=C:\temp\webhook-deploy-%RANDOM%
mkdir %TEMP_DIR%
cd %TEMP_DIR%

:: Clone repository
echo Cloning repository...
git clone https://github.com/%REPOSITORY%.git .
if %errorlevel% neq 0 (
    echo Git clone failed >> C:\kudu-webhooks\deployment.log
    exit /b 1
)

:: Run Kudu deployment
echo Running Kudu deployment...
call deploy.cmd
if %errorlevel% neq 0 (
    echo Kudu deployment failed >> C:\kudu-webhooks\deployment.log
    exit /b 1
)

:: Clean up
cd C:\
rmdir /s /q %TEMP_DIR%

echo %date% %time% - Deployment completed successfully >> C:\kudu-webhooks\deployment.log
echo Deployment completed successfully
```

## Deployment Verification

After setting up the webhook:

1. **Make a test commit** to your repository
2. **Check webhook delivery** in GitHub Settings > Webhooks
3. **Verify deployment logs** on your server:
   ```cmd
   type C:\kudu-webhooks\deployment.log
   type C:\kudu-webhooks\deployment-output.log
   ```
4. **Test the application**:
   ```cmd
   curl http://your-server/IISRecycler/api/webhook/sites
   ```

## Troubleshooting

### Common Issues

1. **Webhook not triggering**:
   - Check GitHub webhook delivery status
   - Verify server is accessible from internet
   - Check firewall settings

2. **Deployment fails**:
   - Check deployment logs
   - Verify Git and .NET are installed on server
   - Ensure proper permissions

3. **IIS application not updating**:
   - Check if deployment path is correct
   - Verify IIS application restart
   - Check application pool recycling

### Debug Commands

```cmd
:: Check webhook logs
type C:\kudu-webhooks\deployment.log

:: Check IIS application status
"%systemroot%\system32\inetsrv\appcmd" list app /app.name:"IISRecycler"

:: Test manual deployment
cd C:\temp
git clone https://github.com/Agile-Works/IISAppPoolRecycler.git
cd IISAppPoolRecycler
deploy.cmd
```

## Security Considerations

1. **Use HTTPS** for webhook endpoints in production
2. **Validate webhook signatures** to prevent unauthorized deployments
3. **Limit webhook access** with firewall rules
4. **Monitor deployment logs** for security issues
5. **Use dedicated service account** for deployments

## Next Steps

1. ✅ Set up webhook receiver on your IIS server
2. ✅ Configure GitHub webhook
3. ✅ Test with a small commit
4. ✅ Monitor deployment logs
5. ✅ Set up notification for deployment status
6. ✅ Configure backup procedures

---

## Quick Setup Commands

**On your IIS server (as Administrator)**:
```cmd
:: Create webhook directory
mkdir C:\kudu-webhooks
cd C:\kudu-webhooks

:: Download webhook files (will be created in next step)
:: Configure IIS application
"%systemroot%\system32\inetsrv\appcmd" add app /site.name:"Default Web Site" /path:/github-webhook /physicalPath:"C:\kudu-webhooks"

:: Create config file
echo [webhook] > config.ini
echo secret=YOUR_SECRET_HERE >> config.ini
echo repository=Agile-Works/IISAppPoolRecycler >> config.ini
echo deployment_path=C:\inetpub\wwwroot\IISRecycler >> config.ini
echo branch=main >> config.ini
```

**In GitHub repository**:
- Go to Settings > Webhooks
- Add webhook with your server URL
- Test with a commit

Your continuous deployment pipeline will be ready! 🚀
