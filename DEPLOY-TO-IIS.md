# IIS App Pool Recycler - Kudu Deployment Guide

## 🚀 Deploying to Your IIS Instance with Kudu

This guide will walk you through deploying the IIS App Pool Recycler to your IIS server using Kudu.

## Prerequisites Checklist

✅ **Your IIS Server Setup:**
- [ ] Windows Server with IIS installed and running
- [ ] .NET 8.0 Runtime installed on the server
- [ ] Kudu installed and configured on your IIS server
- [ ] Git installed on the server (for Git-based deployment)
- [ ] Administrator privileges on the IIS server

✅ **Application Permissions:**
- [ ] Application Pool identity has "Load User Profile" enabled
- [ ] Application Pool identity has IIS management permissions
- [ ] Required Windows Features enabled (IIS-WebServerRole, IIS-WebServer, etc.)

## Deployment Options

### Option 1: Git-Based Kudu Deployment (Recommended)

If your IIS server has Kudu with Git support:

1. **On your IIS server**, clone the repository:
   ```cmd
   git clone https://github.com/Agile-Works/IISAppPoolRecycler.git C:\deployments\IISAppPoolRecycler
   cd C:\deployments\IISAppPoolRecycler
   ```

2. **Run the Kudu deployment script**:
   ```cmd
   deploy.cmd
   ```

3. **Configure IIS Application**:
   ```cmd
   :: Create IIS application (run as administrator)
   "%systemroot%\system32\inetsrv\appcmd" add app /site.name:"Default Web Site" /path:/IISRecycler /physicalPath:"C:\deployments\IISAppPoolRecycler"
   
   :: Configure application pool
   "%systemroot%\system32\inetsrv\appcmd" set config /section:applicationPools /[name='DefaultAppPool'].processModel.loadUserProfile:true
   ```

### Option 2: Manual Kudu-Style Deployment

If you need to deploy manually but want to follow Kudu patterns:

1. **Copy files to your IIS server**
2. **On the server**, navigate to the deployment directory
3. **Run the deployment commands manually**:

```cmd
:: Step 1: Restore packages
dotnet restore IISAppPoolRecycler.csproj

:: Step 2: Build and publish
dotnet publish IISAppPoolRecycler.csproj --output "C:\inetpub\wwwroot\IISRecycler" --configuration Release

:: Step 3: Copy additional files
copy web.config "C:\inetpub\wwwroot\IISRecycler\"
copy start-windows.ps1 "C:\inetpub\wwwroot\IISRecycler\"
copy start-windows.bat "C:\inetpub\wwwroot\IISRecycler\"
copy DEPLOYMENT.md "C:\inetpub\wwwroot\IISRecycler\"
```

### Option 3: Azure Web Apps with Kudu

If deploying to Azure Web Apps:

1. **Create Azure Web App**:
   ```bash
   az webapp create --resource-group myResourceGroup --plan myAppServicePlan --name myIISRecyclerApp --runtime "DOTNETCORE|8.0"
   ```

2. **Configure App Settings**:
   ```bash
   az webapp config appsettings set --resource-group myResourceGroup --name myIISRecyclerApp --settings ASPNETCORE_ENVIRONMENT=Production WEBSITE_LOAD_USER_PROFILE=1
   ```

3. **Deploy via Git**:
   ```bash
   az webapp deployment source config --resource-group myResourceGroup --name myIISRecyclerApp --repo-url https://github.com/Agile-Works/IISAppPoolRecycler.git --branch main --manual-integration
   ```

## Deployment Files Explanation

The repository includes these Kudu-specific files:

- **`.deployment`** - Tells Kudu to use the custom deploy.cmd script
- **`deploy.cmd`** - Custom deployment script that handles .NET Core deployment
- **`web.config`** - IIS configuration for ASP.NET Core hosting
- **`appsettings.Production.json`** - Production environment settings

## Post-Deployment Configuration

### 1. Verify Application is Running

Visit your application URL:
- **Local IIS**: `http://your-server/IISRecycler/swagger`
- **Azure**: `https://your-app.azurewebsites.net/swagger`

### 2. Test API Endpoints

```bash
# Test site listing (replace with your URL)
curl "http://your-server/IISRecycler/api/webhook/sites"

# Test app pool listing
curl "http://your-server/IISRecycler/api/webhook/app-pools"

# Test URL lookup
curl "http://your-server/IISRecycler/api/webhook/lookup/https://example.com"
```

### 3. Configure Uptime Kuma

In your Uptime Kuma dashboard:

1. **Go to Settings > Notifications**
2. **Add new notification**:
   - Type: `Webhook`
   - Name: `IIS App Pool Recycler`
   - Webhook URL: `http://your-server/IISRecycler/api/webhook/uptime-kuma`
   - HTTP Method: `POST`
   - Content Type: `application/json`

3. **Attach to monitors** that you want to trigger app pool recycling

## Troubleshooting

### Common Deployment Issues

1. **Build Fails**:
   ```cmd
   # Check .NET version
   dotnet --version
   
   # Ensure .NET 8.0 is installed
   dotnet --list-runtimes
   ```

2. **Permission Denied**:
   ```cmd
   # Run as administrator and check app pool identity
   "%systemroot%\system32\inetsrv\appcmd" list apppool "DefaultAppPool" /text:processModel.identityType
   ```

3. **IIS Module Not Found**:
   ```cmd
   # Install ASP.NET Core Module
   # Download from: https://dotnet.microsoft.com/en-us/download/dotnet/8.0
   ```

### Verification Commands

```cmd
# Check IIS application status
"%systemroot%\system32\inetsrv\appcmd" list app

# Check application pool status
"%systemroot%\system32\inetsrv\appcmd" list apppool

# Check site bindings
"%systemroot%\system32\inetsrv\appcmd" list site

# View application logs
type "C:\inetpub\wwwroot\IISRecycler\logs\stdout*.log"
```

## Security Considerations

1. **HTTPS Configuration**:
   ```cmd
   # Configure HTTPS redirect in IIS Manager
   # Or add SSL certificate and configure bindings
   ```

2. **Authentication** (Optional):
   - Consider adding API key authentication for production
   - Implement IP whitelisting for webhook endpoints

3. **Firewall**:
   ```cmd
   # Allow HTTP/HTTPS traffic
   netsh advfirewall firewall add rule name="IIS App Pool Recycler HTTP" dir=in action=allow protocol=TCP localport=80
   netsh advfirewall firewall add rule name="IIS App Pool Recycler HTTPS" dir=in action=allow protocol=TCP localport=443
   ```

## Monitoring and Maintenance

1. **Application Logs**: Monitor `C:\inetpub\wwwroot\IISRecycler\logs\`
2. **IIS Logs**: Check IIS logs for HTTP errors
3. **Event Viewer**: Monitor Windows Event Logs for IIS-related issues
4. **Performance**: Monitor CPU and memory usage of the application

## Next Steps

1. ✅ Deploy the application using one of the methods above
2. ✅ Verify all API endpoints are working
3. ✅ Configure Uptime Kuma webhook integration
4. ✅ Test the complete workflow with a test site
5. ✅ Set up monitoring and alerting
6. ✅ Create backup and recovery procedures

---

## Quick Reference Commands

**Deploy from Git**:
```cmd
git clone https://github.com/Agile-Works/IISAppPoolRecycler.git
cd IISAppPoolRecycler
deploy.cmd
```

**Manual Build and Deploy**:
```cmd
dotnet publish --configuration Release --output "C:\inetpub\wwwroot\IISRecycler"
copy web.config "C:\inetpub\wwwroot\IISRecycler\"
```

**Test Webhook**:
```bash
curl -X POST "http://your-server/IISRecycler/api/webhook/uptime-kuma" \
     -H "Content-Type: application/json" \
     -d '{"monitor":{"url":"https://example.com"},"heartbeat":{"status":0}}'
```
