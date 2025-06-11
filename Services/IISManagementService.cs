using Microsoft.Web.Administration;
using System.Text.RegularExpressions;

namespace IISAppPoolRecycler.Services
{
    public interface IIISManagementService
    {
        Task<string?> GetAppPoolByUrl(string url);
        Task<bool> RecycleAppPool(string appPoolName);
        Task<IEnumerable<string>> GetAllAppPools();
        Task<IEnumerable<SiteInfo>> GetAllSites();
    }

    public class IISManagementService : IIISManagementService
    {
        private readonly ILogger<IISManagementService> _logger;

        public IISManagementService(ILogger<IISManagementService> logger)
        {
            _logger = logger;
        }

        public Task<string?> GetAppPoolByUrl(string url)
        {
            try
            {
                _logger.LogInformation("Looking up app pool for URL: {Url}", url);

                var uri = new Uri(url);
                var host = uri.Host;
                var port = uri.Port;
                var scheme = uri.Scheme;

                using (var serverManager = new ServerManager())
                {
                    foreach (var site in serverManager.Sites)
                    {
                        foreach (var binding in site.Bindings)
                        {
                            // Check if binding matches the requested URL
                            if (DoesBindingMatch(binding, host, port, scheme))
                            {
                                _logger.LogInformation("Found matching site: {SiteName} with app pool: {AppPool}", 
                                    site.Name, site.ApplicationDefaults.ApplicationPoolName);
                                return Task.FromResult<string?>(site.ApplicationDefaults.ApplicationPoolName);
                            }
                        }
                    }
                }

                _logger.LogWarning("No matching app pool found for URL: {Url}", url);
                return Task.FromResult<string?>(null);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error looking up app pool for URL: {Url}", url);
                throw;
            }
        }

        public Task<bool> RecycleAppPool(string appPoolName)
        {
            try
            {
                _logger.LogInformation("Attempting to recycle app pool: {AppPoolName}", appPoolName);

                using (var serverManager = new ServerManager())
                {
                    var appPool = serverManager.ApplicationPools[appPoolName];
                    
                    if (appPool == null)
                    {
                        _logger.LogError("App pool not found: {AppPoolName}", appPoolName);
                        return Task.FromResult(false);
                    }

                    // Check current state
                    var currentState = appPool.State;
                    _logger.LogInformation("App pool {AppPoolName} current state: {State}", appPoolName, currentState);

                    // Recycle the app pool
                    appPool.Recycle();
                    serverManager.CommitChanges();

                    _logger.LogInformation("Successfully recycled app pool: {AppPoolName}", appPoolName);
                    return Task.FromResult(true);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error recycling app pool: {AppPoolName}", appPoolName);
                return Task.FromResult(false);
            }
        }

        public Task<IEnumerable<string>> GetAllAppPools()
        {
            try
            {
                using (var serverManager = new ServerManager())
                {
                    var appPools = serverManager.ApplicationPools.Select(pool => pool.Name).ToList();
                    return Task.FromResult<IEnumerable<string>>(appPools);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving app pools");
                throw;
            }
        }

        public Task<IEnumerable<SiteInfo>> GetAllSites()
        {
            try
            {
                using (var serverManager = new ServerManager())
                {
                    var sites = new List<SiteInfo>();
                    
                    foreach (var site in serverManager.Sites)
                    {
                        var bindings = site.Bindings.Select(b => new BindingInfo
                        {
                            Protocol = b.Protocol,
                            BindingInformation = b.BindingInformation,
                            Host = b.Host
                        }).ToList();

                        sites.Add(new SiteInfo
                        {
                            Name = site.Name,
                            Id = site.Id,
                            State = site.State.ToString(),
                            AppPoolName = site.ApplicationDefaults.ApplicationPoolName,
                            Bindings = bindings
                        });
                    }

                    return Task.FromResult<IEnumerable<SiteInfo>>(sites);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving sites");
                throw;
            }
        }

        private bool DoesBindingMatch(Binding binding, string host, int port, string scheme)
        {
            // Check protocol
            if (!string.Equals(binding.Protocol, scheme, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            // Parse binding information (format: IP:Port:Hostname or *:Port:Hostname)
            var bindingParts = binding.BindingInformation.Split(':');
            if (bindingParts.Length != 3)
            {
                return false;
            }

            var bindingHost = bindingParts[2];
            var bindingPortStr = bindingParts[1];

            // Check port
            if (int.TryParse(bindingPortStr, out var bindingPort))
            {
                if (bindingPort != port)
                {
                    return false;
                }
            }

            // Check host - empty binding host means it accepts all hosts
            if (string.IsNullOrEmpty(bindingHost) || bindingHost == "*")
            {
                return true;
            }

            // Exact match or wildcard match
            if (string.Equals(bindingHost, host, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            // Check for wildcard subdomain matching (e.g., *.example.com)
            if (bindingHost.StartsWith("*."))
            {
                var domain = bindingHost.Substring(2);
                if (host.EndsWith(domain, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }

            return false;
        }
    }

    public class SiteInfo
    {
        public string Name { get; set; } = string.Empty;
        public long Id { get; set; }
        public string State { get; set; } = string.Empty;
        public string AppPoolName { get; set; } = string.Empty;
        public List<BindingInfo> Bindings { get; set; } = new List<BindingInfo>();
    }

    public class BindingInfo
    {
        public string Protocol { get; set; } = string.Empty;
        public string BindingInformation { get; set; } = string.Empty;
        public string Host { get; set; } = string.Empty;
    }
}
