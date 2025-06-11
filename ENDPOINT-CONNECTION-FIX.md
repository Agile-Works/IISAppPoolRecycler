# 🚨 URGENT: Cannot Connect to Any Endpoints - FIXED!

## ❌ **Problem**: Application deployed but no endpoints respond

This is a common ASP.NET Core IIS deployment issue. Here's the **step-by-step fix**:

## 🛠️ **IMMEDIATE FIX STEPS:**

### **Step 1: Run the Quick Fix Script**
1. **Download the quick fix script** to your IIS server
2. **Run PowerShell as Administrator**
3. **Execute the fix script**:
   ```powershell
   .\quick-iis-fix.ps1 -ApplicationPath "C:\inetpub\wwwroot" -AppName "IISRecycler"
   ```

### **Step 2: Verify Application Pool Settings**
The most common cause is **incorrect Application Pool configuration**:

```powershell
# Run these commands in PowerShell as Administrator
Import-Module WebAdministration

# Get your app pool name
$app = Get-WebApplication -Site "Default Web Site" -Name "IISRecycler"
$appPoolName = $app.ApplicationPool

# Fix critical settings
Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name managedRuntimeVersion -Value ""
Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name processModel.loadUserProfile -Value $true

# Restart the app pool
Restart-WebAppPool -Name $appPoolName
```

### **Step 3: Use the Minimal web.config (If Needed)**
If the app still doesn't respond, replace your web.config:

```powershell
# On your IIS server, in the application directory
copy web.config web.config.backup
copy web.config.minimal web.config

# Restart app pool
Restart-WebAppPool -Name "YourAppPoolName"
```

## 🔍 **MOST COMMON CAUSES & FIXES:**

### **1. ❌ Wrong .NET CLR Version in App Pool**
**Problem**: App Pool set to .NET Framework instead of "No Managed Code"
**Fix**: 
```powershell
Set-ItemProperty -Path "IIS:\AppPools\YourAppPool" -Name managedRuntimeVersion -Value ""
```

### **2. ❌ Missing ASP.NET Core Runtime**
**Problem**: Server doesn't have .NET 6.0 runtime installed
**Fix**: Install from https://dotnet.microsoft.com/download/dotnet/6.0
**Verify**: `dotnet --list-runtimes` should show `Microsoft.AspNetCore.App 6.x`

### **3. ❌ Application Pool Not Started**
**Problem**: App pool crashed or stopped
**Fix**: 
```powershell
Start-WebAppPool -Name "YourAppPool"
Restart-WebAppPool -Name "YourAppPool"
```

### **4. ❌ Incorrect URL Binding**
**Problem**: Application not properly configured for URL paths
**Fix**: Add `ASPNETCORE_URLS=http://*:80` environment variable (already in fixed web.config)

### **5. ❌ Permissions Issues**
**Problem**: App pool identity doesn't have proper permissions
**Fix**: 
```powershell
# Enable Load User Profile
Set-ItemProperty -Path "IIS:\AppPools\YourAppPool" -Name processModel.loadUserProfile -Value $true
```

## 🧪 **TESTING AFTER FIX:**

Test these URLs (replace `localhost` with your server IP):

```bash
# Basic connectivity
curl http://localhost/IISRecycler

# Swagger UI (should show API documentation)
curl http://localhost/IISRecycler/swagger

# API endpoints
curl http://localhost/IISRecycler/api/webhook/sites
curl http://localhost/IISRecycler/api/webhook/app-pools

# Test webhook
curl -X POST http://localhost/IISRecycler/api/webhook/uptime-kuma \
     -H "Content-Type: application/json" \
     -d '{"monitor":{"url":"https://example.com"},"heartbeat":{"status":0}}'
```

## 📋 **DIAGNOSTIC CHECKLIST:**

- [ ] **App Pool .NET CLR Version**: Set to "No Managed Code"
- [ ] **App Pool State**: Started
- [ ] **Load User Profile**: Enabled
- [ ] **ASP.NET Core Runtime**: Installed (.NET 6.0)
- [ ] **Application Files**: Present in wwwroot directory
- [ ] **web.config**: Correct configuration
- [ ] **Logs Directory**: Created with proper permissions
- [ ] **Port 80**: Not blocked by firewall

## 🔍 **STILL NOT WORKING? Advanced Diagnostics:**

### **Check Application Logs:**
```powershell
# Look for startup errors
Get-Content "C:\inetpub\wwwroot\IISRecycler\logs\stdout*.log" -Tail 20
```

### **Check Windows Event Logs:**
1. Open **Event Viewer**
2. Navigate to: **Applications and Services Logs** → **Microsoft** → **Windows** → **IIS-W3SVC-WP**
3. Look for errors related to your app pool

### **Manual Application Test:**
```powershell
# Test if the app runs manually
cd "C:\inetpub\wwwroot\IISRecycler"
dotnet IISAppPoolRecycler.dll
```

### **Check Process:**
```powershell
# See if the application process is running
Get-Process | Where-Object {$_.ProcessName -like "*dotnet*"}
```

## 🎯 **EXPECTED RESULTS:**

After fixing, you should see:
- ✅ `http://localhost/IISRecycler/swagger` shows Swagger UI
- ✅ `http://localhost/IISRecycler/api/webhook/sites` returns JSON list of IIS sites
- ✅ `http://localhost/IISRecycler/api/webhook/app-pools` returns JSON list of app pools
- ✅ Application logs show successful startup

## 📞 **EMERGENCY CONTACTS & RESOURCES:**

- **Quick Fix Script**: `quick-iis-fix.ps1`
- **Minimal Config**: `web.config.minimal` 
- **Diagnostic Script**: `diagnose-iis.ps1`
- **Troubleshooting Guide**: `KUDU-TROUBLESHOOTING.md`

**The #1 fix is usually setting the App Pool .NET CLR version to "No Managed Code"!** 🎯
