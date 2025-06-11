# Deployment Guide

## Windows Server Deployment

### Prerequisites
1. Windows Server with IIS installed and configured
2. .NET 8.0 Runtime installed
3. Administrator privileges on the server

### Installation Steps

1. **Copy Application Files**
   - Copy the entire application folder to your Windows Server
   - Recommended location: `C:\inetpub\IISAppPoolRecycler\`

2. **Run as Administrator**
   - Open PowerShell or Command Prompt as Administrator
   - Navigate to the application directory

3. **Start the Application**
   
   **Option A: Using PowerShell (Recommended)**
   ```powershell
   .\start-windows.ps1
   ```
   
   **Option B: Using Command Prompt**
   ```cmd
   start-windows.bat
   ```
   
   **Option C: Manual Start**
   ```cmd
   dotnet run --configuration Release
   ```

4. **Verify Installation**
   - Open browser and navigate to `https://localhost:5001/swagger`
   - You should see the API documentation
   - Test the `/api/webhook/sites` endpoint to verify IIS connectivity

### Windows Service Installation (Optional)

To run the application as a Windows Service:

1. **Install as Service**
   ```cmd
   sc create "IISAppPoolRecycler" binPath="C:\path\to\your\app\IISAppPoolRecycler.exe"
   sc config "IISAppPoolRecycler" start=auto
   sc start "IISAppPoolRecycler"
   ```

2. **Alternative: Using NSSM**
   - Download NSSM (Non-Sucking Service Manager)
   - Install the service:
     ```cmd
     nssm install IISAppPoolRecycler
     nssm set IISAppPoolRecycler Application "dotnet"
     nssm set IISAppPoolRecycler AppParameters "C:\path\to\your\app\IISAppPoolRecycler.dll"
     nssm set IISAppPoolRecycler AppDirectory "C:\path\to\your\app"
     nssm start IISAppPoolRecycler
     ```

## Uptime Kuma Configuration

### Webhook Setup

1. **In Uptime Kuma Admin Panel:**
   - Go to Settings > Notifications
   - Add a new notification
   - Choose "Webhook" as the notification type

2. **Webhook Configuration:**
   ```
   Webhook URL: http://your-server:5000/api/webhook/uptime-kuma
   HTTP Method: POST
   Content Type: application/json
   ```

3. **Test the Webhook:**
   - Use the "Test" button in Uptime Kuma
   - Check the application logs for webhook reception

### Monitor Configuration

1. **Add Monitors:**
   - Add your websites as HTTP/HTTPS monitors
   - Ensure the URL matches exactly what IIS serves

2. **Notification Settings:**
   - Attach the webhook notification to your monitors
   - Configure to send notifications when status changes

## Testing

### Manual Testing

1. **Test App Pool Lookup:**
   ```bash
   curl "http://localhost:5000/api/webhook/lookup/https://yoursite.com"
   ```

2. **Test Manual Recycle:**
   ```bash
   curl -X POST http://localhost:5000/api/webhook/recycle \
        -H "Content-Type: application/json" \
        -d '{"url": "https://yoursite.com"}'
   ```

3. **List All Sites:**
   ```bash
   curl "http://localhost:5000/api/webhook/sites"
   ```

### Webhook Testing

1. **Simulate Uptime Kuma Webhook:**
   ```bash
   curl -X POST http://localhost:5000/api/webhook/uptime-kuma \
        -H "Content-Type: application/json" \
        -d '{
          "monitor": {
            "url": "https://yoursite.com",
            "name": "Your Site"
          },
          "heartbeat": {
            "status": 0,
            "time": "2025-06-10T10:00:00Z",
            "msg": "Site is down"
          }
        }'
   ```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   - Ensure running as Administrator
   - Check Windows Event Logs for IIS access issues

2. **Port Already in Use**
   - Change ports in `appsettings.json`
   - Or stop the service using the ports

3. **IIS Sites Not Found**
   - Verify IIS is running
   - Check that sites are properly configured with bindings

4. **App Pool Not Found**
   - Verify app pool names in IIS Manager
   - Check that the site's app pool is properly assigned

### Logging

- Application logs are written to console by default
- For service deployment, configure file logging in `appsettings.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    },
    "File": {
      "Path": "C:\\logs\\iisrecycler.log",
      "LogLevel": "Information"
    }
  }
}
```

## Security Considerations

1. **Network Security**
   - Consider using HTTPS in production
   - Implement firewall rules to restrict access

2. **Authentication**
   - Add API key authentication for production use
   - Consider IP whitelisting for webhook endpoints

3. **Monitoring**
   - Monitor application logs regularly
   - Set up alerts for failed recycle attempts
