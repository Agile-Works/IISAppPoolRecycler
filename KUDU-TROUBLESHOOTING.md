# Kudu Deployment Troubleshooting Guide

## MSBuild Error: '"\MSBuild.exe"' is not recognized

### Problem
When deploying via Kudu, you encounter this error:
```
'"\MSBuild.exe"' is not recognized as an internal or external command,
operable program or batch file.
```

### Root Cause
This error occurs when:
1. The Kudu environment is trying to use MSBuild instead of `dotnet` CLI
2. MSBuild is not available in the PATH on the deployment server
3. The deployment script is calling MSBuild directly instead of using `dotnet publish`

### Solutions

#### Solution 1: Use the Fixed deploy.cmd (Recommended)
The updated `deploy.cmd` script has been fixed to:
- Use only `dotnet` commands instead of MSBuild
- Include better error handling and logging
- Verify .NET 6.0 runtime availability
- Provide detailed deployment progress

#### Solution 2: Use Simple Deployment Script
If you continue to encounter issues, switch to the simple deployment script:

1. **Rename deployment files**:
   ```cmd
   ren .deployment .deployment-original
   ren .deployment-simple .deployment
   ```

2. **The simple script (`deploy-simple.cmd`) only uses**:
   - `dotnet restore`
   - `dotnet publish` 
   - Basic file copying

#### Solution 3: Manual Azure App Service Deployment
If Kudu deployment continues to fail:

1. **Build locally**:
   ```cmd
   dotnet publish IISAppPoolRecycler.csproj --configuration Release --output ./publish
   ```

2. **Deploy via Azure CLI**:
   ```bash
   az webapp deployment source config-zip --resource-group myResourceGroup --name myAppName --src ./publish.zip
   ```

3. **Deploy via Visual Studio/VS Code**:
   - Use Azure extension
   - Right-click project → Publish → Azure

### Prevention
To avoid this issue in the future:

1. **Always use .NET SDK-style projects** (`Microsoft.NET.Sdk.Web`)
2. **Avoid legacy MSBuild tasks** in project files
3. **Use `dotnet` CLI commands** instead of MSBuild directly
4. **Test deployment scripts locally** before pushing

### Verification
After deployment, verify it worked:

1. **Check the application URL**:
   ```
   https://your-app.azurewebsites.net/swagger
   ```

2. **Test API endpoints**:
   ```bash
   curl "https://your-app.azurewebsites.net/api/webhook/sites"
   curl "https://your-app.azurewebsites.net/api/webhook/app-pools"
   ```

3. **Check application logs**:
   - Go to Azure Portal → App Service → Log Stream
   - Or use: `az webapp log tail --name myAppName --resource-group myResourceGroup`

### Common Issues and Fixes

#### Issue: "dotnet command not found"
**Fix**: Ensure .NET 6.0 runtime is configured in Azure App Service:
```bash
az webapp config set --resource-group myResourceGroup --name myAppName --net-framework-version "v6.0"
```

#### Issue: "Project file not found"
**Fix**: Verify the repository structure and ensure `IISAppPoolRecycler.csproj` is in the root.

#### Issue: "Package restore failed"
**Fix**: Check NuGet package sources and network connectivity in the deployment environment.

### Advanced Debugging

1. **Enable detailed Kudu logs**:
   Set environment variable: `SCM_TRACE_LEVEL=4`

2. **Access Kudu console**:
   Go to: `https://your-app.scm.azurewebsites.net/DebugConsole`

3. **Check deployment logs**:
   ```
   https://your-app.scm.azurewebsites.net/api/deployments
   ```

4. **Manually test commands**:
   ```cmd
   D:\home\site\repository> dotnet --version
   D:\home\site\repository> dotnet restore IISAppPoolRecycler.csproj
   D:\home\site\repository> dotnet publish IISAppPoolRecycler.csproj --output D:\home\site\wwwroot --configuration Release
   ```

## Contact
If you continue to experience issues, please provide:
1. Full deployment log output
2. Azure App Service configuration
3. Repository structure
4. Kudu environment details

This troubleshooting guide should resolve the MSBuild deployment error and get your IIS App Pool Recycler deployed successfully.
