using Microsoft.AspNetCore.Mvc;
using IISAppPoolRecycler.Models;
using IISAppPoolRecycler.Services;
using System.Text.Json;

namespace IISAppPoolRecycler.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class WebhookController : ControllerBase
    {
        private readonly ILogger<WebhookController> _logger;
        private readonly IIISManagementService _iisService;

        public WebhookController(ILogger<WebhookController> logger, IIISManagementService iisService)
        {
            _logger = logger;
            _iisService = iisService;
        }

        [HttpPost("uptime-kuma")]
        public async Task<IActionResult> HandleUptimeKumaWebhook([FromBody] JsonElement payload)
        {
            try
            {
                _logger.LogInformation("Received Uptime Kuma webhook: {Payload}", payload.ToString());

                // Extract monitor URL from the payload
                var monitorUrl = ExtractMonitorUrl(payload);
                
                if (string.IsNullOrEmpty(monitorUrl))
                {
                    _logger.LogWarning("Could not extract monitor URL from webhook payload");
                    return BadRequest("Invalid webhook payload - missing monitor URL");
                }

                // Extract heartbeat status
                var status = ExtractHeartbeatStatus(payload);
                
                _logger.LogInformation("Monitor URL: {Url}, Status: {Status}", monitorUrl, status);

                // Only recycle if the status indicates a problem (status 0 = down)
                if (status == 0)
                {
                    await HandleSiteDown(monitorUrl);
                }
                else
                {
                    _logger.LogInformation("Site is up, no action needed for URL: {Url}", monitorUrl);
                }

                return Ok(new { message = "Webhook processed successfully", url = monitorUrl, status = status });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing Uptime Kuma webhook");
                return StatusCode(500, new { error = "Internal server error processing webhook" });
            }
        }

        [HttpPost("recycle")]
        public async Task<IActionResult> ManualRecycle([FromBody] RecycleRequest request)
        {
            try
            {
                if (string.IsNullOrEmpty(request.Url) && string.IsNullOrEmpty(request.AppPoolName))
                {
                    return BadRequest("Either URL or AppPoolName must be provided");
                }

                string? appPoolName = request.AppPoolName;

                if (!string.IsNullOrEmpty(request.Url))
                {
                    appPoolName = await _iisService.GetAppPoolByUrl(request.Url);
                    if (string.IsNullOrEmpty(appPoolName))
                    {
                        return NotFound($"No app pool found for URL: {request.Url}");
                    }
                }

                var success = await _iisService.RecycleAppPool(appPoolName!);
                
                if (success)
                {
                    return Ok(new { message = "App pool recycled successfully", appPool = appPoolName });
                }
                else
                {
                    return StatusCode(500, new { error = "Failed to recycle app pool", appPool = appPoolName });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during manual recycle");
                return StatusCode(500, new { error = "Internal server error during recycle" });
            }
        }

        [HttpGet("sites")]
        public async Task<IActionResult> GetSites()
        {
            try
            {
                var sites = await _iisService.GetAllSites();
                return Ok(sites);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving sites");
                return StatusCode(500, new { error = "Internal server error retrieving sites" });
            }
        }

        [HttpGet("app-pools")]
        public async Task<IActionResult> GetAppPools()
        {
            try
            {
                var appPools = await _iisService.GetAllAppPools();
                return Ok(appPools);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving app pools");
                return StatusCode(500, new { error = "Internal server error retrieving app pools" });
            }
        }

        [HttpGet("lookup/{*url}")]
        public async Task<IActionResult> LookupAppPool(string url)
        {
            try
            {
                // Decode the URL parameter
                url = Uri.UnescapeDataString(url);
                
                // Ensure URL has a scheme
                if (!url.StartsWith("http://") && !url.StartsWith("https://"))
                {
                    url = "https://" + url;
                }

                var appPoolName = await _iisService.GetAppPoolByUrl(url);
                
                if (string.IsNullOrEmpty(appPoolName))
                {
                    return NotFound(new { message = "No app pool found for URL", url = url });
                }

                return Ok(new { url = url, appPool = appPoolName });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error looking up app pool for URL: {Url}", url);
                return StatusCode(500, new { error = "Internal server error during lookup" });
            }
        }

        private async Task HandleSiteDown(string monitorUrl)
        {
            try
            {
                _logger.LogWarning("Site is down, attempting to recycle app pool for URL: {Url}", monitorUrl);

                var appPoolName = await _iisService.GetAppPoolByUrl(monitorUrl);
                
                if (string.IsNullOrEmpty(appPoolName))
                {
                    _logger.LogError("Could not find app pool for URL: {Url}", monitorUrl);
                    return;
                }

                var success = await _iisService.RecycleAppPool(appPoolName);
                
                if (success)
                {
                    _logger.LogInformation("Successfully recycled app pool {AppPool} for URL: {Url}", appPoolName, monitorUrl);
                }
                else
                {
                    _logger.LogError("Failed to recycle app pool {AppPool} for URL: {Url}", appPoolName, monitorUrl);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error handling site down for URL: {Url}", monitorUrl);
            }
        }

        private string? ExtractMonitorUrl(JsonElement payload)
        {
            try
            {
                // Try to get URL from monitor object
                if (payload.TryGetProperty("monitor", out var monitor))
                {
                    if (monitor.TryGetProperty("url", out var urlProperty))
                    {
                        return urlProperty.GetString();
                    }
                }

                // Alternative: try to get from direct url property
                if (payload.TryGetProperty("url", out var directUrl))
                {
                    return directUrl.GetString();
                }

                return null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error extracting monitor URL from payload");
                return null;
            }
        }

        private int ExtractHeartbeatStatus(JsonElement payload)
        {
            try
            {
                // Try to get status from heartbeat object
                if (payload.TryGetProperty("heartbeat", out var heartbeat))
                {
                    if (heartbeat.TryGetProperty("status", out var statusProperty))
                    {
                        return statusProperty.GetInt32();
                    }
                }

                // Alternative: try to get from direct status property
                if (payload.TryGetProperty("status", out var directStatus))
                {
                    return directStatus.GetInt32();
                }

                // Default to unknown status
                return -1;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error extracting heartbeat status from payload");
                return -1;
            }
        }
    }

    public class RecycleRequest
    {
        public string? Url { get; set; }
        public string? AppPoolName { get; set; }
    }
}
