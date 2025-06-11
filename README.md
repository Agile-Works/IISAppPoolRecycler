# IIS App Pool Recycler

An ASP.NET Core Web API application that automatically recycles IIS application pools based on webhook notifications from Uptime Kuma monitoring system.

## Project Status

✅ **Completed Features:**
- Uptime Kuma webhook integration
- Automatic site-to-app-pool mapping via IIS bindings lookup
- Manual app pool recycling API endpoints
- Comprehensive logging and error handling
- IIS management using Microsoft.Web.Administration
- RESTful API with Swagger documentation
- Windows deployment scripts

✅ **Ready for Deployment:**
- The application is built and tested
- Deployment scripts are provided for Windows Server
- Comprehensive documentation included

## Features

- **Webhook Integration**: Receives notifications from Uptime Kuma when monitored sites go down
- **Automatic Discovery**: Determines which IIS app pool to recycle by looking up site bindings (no manual configuration required)
- **IIS Management**: Uses Microsoft.Web.Administration to interact with IIS
- **Comprehensive Logging**: Tracks all operations for monitoring and troubleshooting
- **RESTful API**: Provides endpoints for manual operations and system status

## Prerequisites

- Windows Server with IIS installed
- .NET 6.0 Runtime
- Administrator privileges (required for IIS management)
- Uptime Kuma monitoring system

## Installation & Deployment

### Quick Start (Local Development)
1. Clone the repository
2. Build the application:
   ```bash
   dotnet build
   ```
3. Run the application:
   ```bash
   dotnet run
   ```

### Production Deployment

#### Option 1: Kudu Deployment (Recommended for Azure/IIS)
See [KUDU-DEPLOYMENT.md](KUDU-DEPLOYMENT.md) for comprehensive deployment guide.

Quick steps:
1. Validate deployment readiness:
   ```powershell
   .\validate-deployment.ps1
   ```
2. Test local deployment:
   ```powershell
   .\deploy-local.ps1
   ```
3. Deploy to Azure Web Apps or IIS with Kudu

#### Option 2: Manual Windows Server Deployment
See [DEPLOYMENT.md](DEPLOYMENT.md) for Windows Server deployment guide.

Quick steps:
1. Run deployment scripts:
   ```powershell
   .\start-windows.ps1
   ```
   or
   ```cmd
   start-windows.bat
   ```

The application will start on:
- HTTP: http://localhost:5000
- HTTPS: https://localhost:5001

## API Endpoints

### Webhook Endpoint
- **POST** `/api/webhook/uptime-kuma` - Receives Uptime Kuma webhook notifications

### Manual Operations
- **POST** `/api/webhook/recycle` - Manually recycle an app pool by URL or app pool name
- **GET** `/api/webhook/lookup/{url}` - Look up which app pool serves a specific URL

### System Information
- **GET** `/api/webhook/sites` - List all IIS sites with their bindings and app pools
- **GET** `/api/webhook/app-pools` - List all IIS application pools

## Uptime Kuma Configuration

Configure your Uptime Kuma notifications to send webhooks to:
```
POST http://your-server:5000/api/webhook/uptime-kuma
```

The webhook payload should include the monitor URL and status information.

## How It Works

1. **Webhook Reception**: Uptime Kuma sends a webhook when a site goes down (status = 0)
2. **URL Parsing**: The application extracts the monitor URL from the webhook payload
3. **Binding Lookup**: The system searches IIS sites to find which one serves the URL by:
   - Matching protocol (HTTP/HTTPS)
   - Matching port number
   - Matching hostname (supports wildcards like *.example.com)
4. **App Pool Recycling**: Once the correct app pool is identified, it's recycled using IIS management APIs
5. **Logging**: All operations are logged for monitoring and troubleshooting

## Manual Recycle Examples

### Recycle by URL
```bash
curl -X POST http://localhost:5000/api/webhook/recycle \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'
```

### Recycle by App Pool Name
```bash
curl -X POST http://localhost:5000/api/webhook/recycle \
  -H "Content-Type: application/json" \
  -d '{"appPoolName": "MyAppPool"}'
```

### Lookup App Pool for URL
```bash
curl http://localhost:5000/api/webhook/lookup/https://example.com
```

## Security Considerations

- Run the application with administrator privileges for IIS access
- Consider implementing authentication for webhook endpoints in production
- Use HTTPS in production environments
- Monitor logs for unauthorized access attempts

## Logging

The application provides comprehensive logging including:
- Webhook receipts and processing
- App pool lookup operations
- Recycling attempts and results
- Error conditions and troubleshooting information

Logs are written to the console and can be configured to write to files or other destinations using standard ASP.NET Core logging configuration.

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the application runs with administrator privileges
2. **App Pool Not Found**: Verify the URL mapping is correct and the site exists in IIS
3. **Webhook Not Received**: Check firewall settings and ensure the endpoint is accessible

### Debugging

- Check the application logs for detailed operation information
- Use the `/api/webhook/sites` endpoint to verify site configurations
- Test manual recycling with the `/api/webhook/recycle` endpoint

.