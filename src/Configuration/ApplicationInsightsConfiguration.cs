using Microsoft.ApplicationInsights.AspNetCore.Extensions;
using Microsoft.ApplicationInsights.Extensibility;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;

namespace MedSecure.Configuration;

/// <summary>
/// Application Insights Configuration
/// HDS Article 8.1 - Application Performance Monitoring
/// </summary>
public static class ApplicationInsightsConfiguration
{
    /// <summary>
    /// Configure Application Insights with HDS-compliant settings
    /// </summary>
    public static IServiceCollection AddMedSecureApplicationInsights(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Application Insights options
        var aiOptions = new ApplicationInsightsServiceOptions
        {
            // Connection string from Key Vault or configuration
            ConnectionString = configuration["ApplicationInsights:ConnectionString"],

            // Enable adaptive sampling (reduces telemetry volume while keeping representative data)
            EnableAdaptiveSampling = true,

            // Enable performance counter collection
            EnablePerformanceCounterCollectionModule = true,

            // Enable event counter collection (.NET Core metrics)
            EnableEventCounterCollectionModule = true,

            // Enable dependency tracking
            EnableDependencyTrackingTelemetryModule = true,

            // Enable app services heartbeat (health check)
            EnableHeartbeat = true,

            // Enable Azure Instance Metadata
            EnableAzureInstanceMetadataTelemetryModule = true,

            // Enable request tracking
            EnableRequestTrackingTelemetryModule = true,

            // Disable developer mode (production setting)
            DeveloperMode = false,

            // Enable debug logging for troubleshooting (disable in production)
            EnableDebugLogger = false,

            // Enable authentication tracking
            EnableAuthenticationTrackingJavaScript = true
        };

        // Add Application Insights telemetry
        services.AddApplicationInsightsTelemetry(aiOptions);

        // Configure telemetry processors
        services.AddApplicationInsightsTelemetryProcessor<SensitiveDataFilterProcessor>();
        services.AddApplicationInsightsTelemetryProcessor<HealthCheckFilterProcessor>();

        // Configure adaptive sampling (HDS: balance between cost and observability)
        services.ConfigureTelemetryModule<Microsoft.ApplicationInsights.Extensibility.PerfCounterCollector.QuickPulse.QuickPulseTelemetryModule>(
            (module, _) =>
            {
                module.AuthenticationApiKey = configuration["ApplicationInsights:QuickPulseApiKey"];
            });

        // Add custom telemetry initializers
        services.AddSingleton<ITelemetryInitializer, CloudRoleNameInitializer>();
        services.AddSingleton<ITelemetryInitializer, UserIdentityInitializer>();
        services.AddSingleton<ITelemetryInitializer, ComplianceTagInitializer>();

        return services;
    }
}

/// <summary>
/// Filter sensitive data from telemetry (HDS compliance)
/// </summary>
public class SensitiveDataFilterProcessor : ITelemetryProcessor
{
    private readonly ITelemetryProcessor _next;
    private readonly string[] _sensitiveKeys = new[]
    {
        "password",
        "token",
        "secret",
        "key",
        "authorization",
        "ssn",
        "socialsecuritynumber",
        "email",
        "phonenumber"
    };

    public SensitiveDataFilterProcessor(ITelemetryProcessor next)
    {
        _next = next;
    }

    public void Process(ITelemetry item)
    {
        // Filter sensitive data from requests
        if (item is RequestTelemetry request)
        {
            FilterSensitiveProperties(request.Properties);

            // Redact sensitive query strings
            if (request.Url != null)
            {
                request.Url = RedactSensitiveQueryStrings(request.Url);
            }
        }

        // Filter sensitive data from dependencies
        if (item is DependencyTelemetry dependency)
        {
            FilterSensitiveProperties(dependency.Properties);
        }

        // Filter sensitive data from traces
        if (item is TraceTelemetry trace)
        {
            FilterSensitiveProperties(trace.Properties);
        }

        // Filter sensitive data from exceptions
        if (item is ExceptionTelemetry exception)
        {
            FilterSensitiveProperties(exception.Properties);
        }

        _next.Process(item);
    }

    private void FilterSensitiveProperties(IDictionary<string, string> properties)
    {
        foreach (var key in properties.Keys.ToList())
        {
            if (_sensitiveKeys.Any(s => key.IndexOf(s, StringComparison.OrdinalIgnoreCase) >= 0))
            {
                properties[key] = "[REDACTED]";
            }
        }
    }

    private Uri RedactSensitiveQueryStrings(Uri url)
    {
        var query = System.Web.HttpUtility.ParseQueryString(url.Query);

        foreach (var key in query.AllKeys.ToList())
        {
            if (key != null && _sensitiveKeys.Any(s => key.IndexOf(s, StringComparison.OrdinalIgnoreCase) >= 0))
            {
                query[key] = "[REDACTED]";
            }
        }

        var builder = new UriBuilder(url)
        {
            Query = query.ToString()
        };

        return builder.Uri;
    }
}

/// <summary>
/// Filter health check requests from telemetry (reduce noise)
/// </summary>
public class HealthCheckFilterProcessor : ITelemetryProcessor
{
    private readonly ITelemetryProcessor _next;
    private readonly string[] _healthCheckPaths = new[] { "/health", "/api/health", "/healthz", "/ready", "/live" };

    public HealthCheckFilterProcessor(ITelemetryProcessor next)
    {
        _next = next;
    }

    public void Process(ITelemetry item)
    {
        // Filter out health check requests (they're noisy and tracked separately)
        if (item is RequestTelemetry request)
        {
            if (_healthCheckPaths.Any(path => request.Url?.AbsolutePath?.Equals(path, StringComparison.OrdinalIgnoreCase) == true))
            {
                // Don't send health check requests to Application Insights
                return;
            }
        }

        _next.Process(item);
    }
}

/// <summary>
/// Add cloud role name to telemetry (for distributed tracing)
/// </summary>
public class CloudRoleNameInitializer : ITelemetryInitializer
{
    public void Initialize(ITelemetry telemetry)
    {
        telemetry.Context.Cloud.RoleName = "MedSecure-WebApp";
        telemetry.Context.Cloud.RoleInstance = Environment.MachineName;
    }
}

/// <summary>
/// Add user identity to telemetry (for HDS audit trail)
/// </summary>
public class UserIdentityInitializer : ITelemetryInitializer
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public UserIdentityInitializer(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public void Initialize(ITelemetry telemetry)
    {
        var httpContext = _httpContextAccessor.HttpContext;
        if (httpContext?.User?.Identity?.IsAuthenticated == true)
        {
            // Track authenticated user (for HDS Article 4.1 - traceability)
            telemetry.Context.User.AuthenticatedUserId = httpContext.User.Identity.Name;

            // Add user role for audit purposes
            if (httpContext.User.Claims.Any())
            {
                var roles = string.Join(",", httpContext.User.Claims
                    .Where(c => c.Type == System.Security.Claims.ClaimTypes.Role)
                    .Select(c => c.Value));

                if (!string.IsNullOrEmpty(roles))
                {
                    telemetry.Context.GlobalProperties["UserRoles"] = roles;
                }
            }
        }
    }
}

/// <summary>
/// Add compliance tags to telemetry
/// </summary>
public class ComplianceTagInitializer : ITelemetryInitializer
{
    public void Initialize(ITelemetry telemetry)
    {
        telemetry.Context.GlobalProperties["Compliance"] = "HDS";
        telemetry.Context.GlobalProperties["Environment"] = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Production";
        telemetry.Context.GlobalProperties["Version"] = typeof(Program).Assembly.GetName().Version?.ToString() ?? "1.0.0";
    }
}
