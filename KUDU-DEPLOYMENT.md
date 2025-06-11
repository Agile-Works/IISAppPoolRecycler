# Kudu Deployment Guide for IIS App Pool Recycler

This guide covers deploying the IIS App Pool Recycler to Azure Web Apps, Azure App Service, or any IIS environment that supports Kudu deployment.

## Files for Kudu Deployment

The following files have been added to support Kudu deployment:

- `.deployment` - Tells Kudu to use the custom deploy.cmd script
- `deploy.cmd` - Custom deployment script for .NET Core applications
- `web.config` - IIS configuration for ASP.NET Core hosting
- `appsettings.Production.json` - Production environment settings
- `deploy-local.ps1` - Local deployment testing script

## Prerequisites

### For Azure Web Apps
- Azure subscription
- App Service with .NET 6.0 runtime
- Application Pool with "Load User Profile" enabled
- Administrator permissions for IIS management

### For On-Premises IIS with Kudu
- Windows Server with IIS installed
- Kudu installed and configured
- .NET 6.0 Runtime
- Git repository access

## Deployment Steps

### Method 1: Azure Web Apps Deployment

1. **Create Azure Web App**
   ```bash
   # Using Azure CLI
   az webapp create --resource-group myResourceGroup --plan myAppServicePlan --name myIISRecyclerApp --runtime "DOTNETCORE|6.0"
   ```

2. **Configure App Service Settings**
   - Go to Azure Portal → Your App Service → Configuration
   - Add application settings:
     ```
     ASPNETCORE_ENVIRONMENT = Production
     WEBSITE_LOAD_USER_PROFILE = 1
     ```

3. **Deploy via Git**
   ```bash
   # Add Azure remote
   git remote add azure https://your-app-name.scm.azurewebsites.net:443/your-app-name.git
   
   # Deploy
   git push azure main
   ```

4. **Configure Application Pool**
   - In Azure Portal → App Service → Advanced Tools → Go (Kudu)
   - Navigate to Process Explorer
   - Ensure the w3wp.exe process is running with appropriate permissions

### Method 2: Local IIS with Kudu

1. **Prepare IIS Environment**
   ```powershell
   # Enable IIS features
   Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures, IIS-HttpErrors, IIS-HttpStaticContent, IIS-DefaultDocument, IIS-DirectoryBrowsing
   
   # Install ASP.NET Core Module
   # Download and install from Microsoft
   ```

2. **Setup Kudu**
   ```powershell
   # Install Node.js (required for Kudu)
   # Download from nodejs.org
   
   # Install Kudu globally
   npm install -g kudu
   ```

3. **Deploy Application**
   ```powershell
   # Test deployment locally first
   .\deploy-local.ps1 -TargetPath "C:\inetpub\wwwroot\IISRecycler"
   
   # Or use Git deployment
   git clone https://your-repo.git C:\deployments\source
   cd C:\deployments\source
   .\deploy.cmd
   ```

### Method 3: Manual Kudu-Style Deployment

1. **Build Application**
   ```bash
   # Restore and build
   dotnet restore
   dotnet publish -c Release -o ./publish
   ```

2. **Copy Files to IIS**
   ```powershell
   # Copy published files
   Copy-Item -Path "./publish/*" -Destination "C:\inetpub\wwwroot\IISRecycler" -Recurse -Force
   
   # Copy additional files
   Copy-Item web.config "C:\inetpub\wwwroot\IISRecycler\"
   Copy-Item appsettings.Production.json "C:\inetpub\wwwroot\IISRecycler\"
   ```

3. **Configure IIS Site**
   ```powershell
   # Create IIS application (run in elevated PowerShell)
   Import-Module WebAdministration
   New-WebApplication -Site "Default Web Site" -Name "IISRecycler" -PhysicalPath "C:\inetpub\wwwroot\IISRecycler"
   
   # Configure application pool
   Set-ItemProperty -Path "IIS:\AppPools\DefaultAppPool" -Name processModel.loadUserProfile -Value True
   ```

## Configuration

### Application Settings

For Azure Web Apps, configure these in the Azure Portal under Configuration → Application Settings:

```
ASPNETCORE_ENVIRONMENT = Production
WEBSITE_LOAD_USER_PROFILE = 1
ASPNETCORE_URLS = http://+:80
```

### Local IIS Configuration

For on-premises IIS, ensure the following in `web.config`:

```xml
<aspNetCore processPath="dotnet" 
            arguments=".\IISAppPoolRecycler.dll" 
            stdoutLogEnabled="true" 
            stdoutLogFile=".\logs\stdout" 
            hostingModel="inprocess" />
```

## Verification

### 1. Check Application Status
Navigate to your application URL and verify:
- `https://your-app.azurewebsites.net/swagger` - Should show API documentation
- `https://your-app.azurewebsites.net/api/webhook/sites` - Should list IIS sites

### 2. Test Webhook Endpoint
```bash
curl -X POST "https://your-app.azurewebsites.net/api/webhook/uptime-kuma" \
     -H "Content-Type: application/json" \
     -d '{
       "monitor": {"url": "https://example.com"},
       "heartbeat": {"status": 0}
     }'
```

### 3. Check Logs
- Azure: Navigate to App Service → Monitoring → Log Stream
- Local IIS: Check `C:\inetpub\wwwroot\IISRecycler\logs\stdout*.log`

## Uptime Kuma Integration

### Configure Webhook in Uptime Kuma

1. **Add Notification**
   - Type: Webhook
   - URL: `https://your-app.azurewebsites.net/api/webhook/uptime-kuma`
   - Method: POST
   - Content Type: `application/json`

2. **Test Integration**
   - Use Uptime Kuma's test notification feature
   - Monitor application logs for webhook reception
   - Verify app pool recycling in IIS Manager

## Troubleshooting

### Common Issues

1. **MSBuild Error**: `'"\MSBuild.exe"' is not recognized`
   - **Solution**: This is a common Kudu deployment issue. See the detailed [KUDU-TROUBLESHOOTING.md](KUDU-TROUBLESHOOTING.md) guide.
   - **Quick Fix**: Use the alternative simple deployment script by renaming `.deployment-simple` to `.deployment`

2. **Permission Denied**
   - Ensure App Service has "Load User Profile" enabled
   - For local IIS, run Application Pool as administrator or with IIS management permissions

3. **Deployment Fails**
   - Check Kudu deployment logs in Azure Portal → App Service → Deployment Center
   - Verify .NET 6.0 runtime is available

3. **App Pool Recycling Fails**
   - Verify the application can access IIS management APIs
   - Check Windows Event Log for IIS-related errors
   - Ensure correct app pool names in IIS

4. **Webhook Not Received**
   - Verify firewall settings allow incoming connections
   - Check application logs for webhook processing
   - Test with curl or Postman

### Debugging Commands

```bash
# Check application status
curl https://your-app.azurewebsites.net/api/webhook/app-pools

# Test manual recycle
curl -X POST https://your-app.azurewebsites.net/api/webhook/recycle \
     -H "Content-Type: application/json" \
     -d '{"appPoolName": "DefaultAppPool"}'

# Look up app pool for URL
curl https://your-app.azurewebsites.net/api/webhook/lookup/https://example.com
```

## Security Considerations

### For Production Deployment

1. **Enable HTTPS Only**
   - Azure: App Service → TLS/SSL Settings → HTTPS Only
   - Local IIS: Configure SSL certificate and redirect

2. **Implement Authentication**
   - Consider adding API key authentication
   - Implement IP whitelisting for webhook endpoints

3. **Monitor Access**
   - Enable application logging
   - Set up monitoring and alerts for unauthorized access attempts

## Performance Optimization

1. **Enable Compression** (already configured in web.config)
2. **Configure Caching** for static content
3. **Monitor Application Insights** (if using Azure)
4. **Set up Health Checks** for monitoring application status

## Backup and Recovery

1. **Backup Strategy**
   - Regular backups of IIS configuration
   - Source code in version control
   - Documentation of deployment procedures

2. **Recovery Procedures**
   - Automated deployment from Git
   - IIS configuration restoration scripts
   - Database/configuration restore procedures (if applicable)
