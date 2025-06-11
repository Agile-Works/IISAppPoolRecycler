# Copilot Instructions

<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

This is an IIS App Pool Recycler application built using ASP.NET Core Web API. The application:

- Receives webhook notifications from Uptime Kuma when sites go down
- Automatically determines which IIS app pool to recycle based on site bindings
- Uses Microsoft.Web.Administration to manage IIS app pools
- Provides logging and error handling for monitoring operations

Key components:
- Webhook endpoint to receive Uptime Kuma alerts
- IIS service for app pool management
- Site binding lookup service to map URLs to app pools
- Comprehensive logging for operations tracking

When working with this codebase, consider:
- IIS management requires administrator privileges
- Use proper error handling for IIS operations
- Implement security measures for webhook endpoints
- Follow ASP.NET Core best practices for dependency injection
