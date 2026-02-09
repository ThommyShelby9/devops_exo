using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Metrics;
using System.Diagnostics;

namespace MedSecure.Services;

/// <summary>
/// Telemetry Service for custom Application Insights tracking
/// HDS Article 8.1 - Performance and Availability Monitoring
/// </summary>
public interface ITelemetryService
{
    // Events
    void TrackEvent(string eventName, IDictionary<string, string>? properties = null, IDictionary<string, double>? metrics = null);
    void TrackPatientAccess(string patientId, string action, string userId);
    void TrackMedicalRecordAccess(string recordId, string patientId, string userId);

    // Metrics
    void TrackMetric(string metricName, double value, IDictionary<string, string>? properties = null);
    void TrackResponseTime(string operation, TimeSpan duration);
    void TrackDatabaseQueryTime(string queryType, TimeSpan duration);

    // Dependencies
    void TrackDependency(string dependencyName, string commandName, DateTimeOffset startTime, TimeSpan duration, bool success);

    // Exceptions
    void TrackException(Exception exception, IDictionary<string, string>? properties = null);

    // Requests (usually tracked automatically, but can be manual)
    void TrackRequest(string name, DateTimeOffset startTime, TimeSpan duration, string responseCode, bool success);

    // Traces (logs)
    void TrackTrace(string message, SeverityLevel severityLevel, IDictionary<string, string>? properties = null);

    // Operations (for distributed tracing)
    IOperationHolder<RequestTelemetry> StartOperation(string operationName);
}

public class TelemetryService : ITelemetryService
{
    private readonly TelemetryClient _telemetryClient;
    private readonly ILogger<TelemetryService> _logger;

    public TelemetryService(TelemetryClient telemetryClient, ILogger<TelemetryService> logger)
    {
        _telemetryClient = telemetryClient;
        _logger = logger;
    }

    // ============================================
    // Events (Business events tracking)
    // ============================================

    public void TrackEvent(string eventName, IDictionary<string, string>? properties = null, IDictionary<string, double>? metrics = null)
    {
        try
        {
            _telemetryClient.TrackEvent(eventName, properties, metrics);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to track event: {EventName}", eventName);
        }
    }

    /// <summary>
    /// Track patient data access (HDS Article 4.1 - Audit trail)
    /// </summary>
    public void TrackPatientAccess(string patientId, string action, string userId)
    {
        var properties = new Dictionary<string, string>
        {
            { "PatientId", patientId },
            { "Action", action },
            { "UserId", userId },
            { "Timestamp", DateTime.UtcNow.ToString("o") },
            { "Compliance", "HDS-4.1" },
            { "DataType", "PatientData" }
        };

        TrackEvent("PatientDataAccess", properties);

        // Also log for additional audit trail
        _logger.LogInformation("Patient data accessed: PatientId={PatientId}, Action={Action}, User={UserId}",
            patientId, action, userId);
    }

    /// <summary>
    /// Track medical record access (HDS Article 4.1 - Audit trail)
    /// </summary>
    public void TrackMedicalRecordAccess(string recordId, string patientId, string userId)
    {
        var properties = new Dictionary<string, string>
        {
            { "RecordId", recordId },
            { "PatientId", patientId },
            { "UserId", userId },
            { "Timestamp", DateTime.UtcNow.ToString("o") },
            { "Compliance", "HDS-4.1" },
            { "DataType", "MedicalRecord" }
        };

        TrackEvent("MedicalRecordAccess", properties);

        _logger.LogInformation("Medical record accessed: RecordId={RecordId}, PatientId={PatientId}, User={UserId}",
            recordId, patientId, userId);
    }

    // ============================================
    // Metrics (Custom metrics)
    // ============================================

    public void TrackMetric(string metricName, double value, IDictionary<string, string>? properties = null)
    {
        try
        {
            var metric = _telemetryClient.GetMetric(metricName);
            metric.TrackValue(value);

            if (properties != null)
            {
                _telemetryClient.TrackMetric(metricName, value, properties);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to track metric: {MetricName}", metricName);
        }
    }

    /// <summary>
    /// Track API response time
    /// </summary>
    public void TrackResponseTime(string operation, TimeSpan duration)
    {
        var properties = new Dictionary<string, string>
        {
            { "Operation", operation }
        };

        TrackMetric("ResponseTime", duration.TotalMilliseconds, properties);

        // Alert if response time is slow (HDS Article 8.1)
        if (duration.TotalMilliseconds > 2000)
        {
            _logger.LogWarning("Slow response time: {Operation} took {Duration}ms", operation, duration.TotalMilliseconds);
        }
    }

    /// <summary>
    /// Track database query execution time
    /// </summary>
    public void TrackDatabaseQueryTime(string queryType, TimeSpan duration)
    {
        var properties = new Dictionary<string, string>
        {
            { "QueryType", queryType },
            { "Database", "SQL" }
        };

        TrackMetric("DatabaseQueryDuration", duration.TotalMilliseconds, properties);

        // Alert if query is slow
        if (duration.TotalMilliseconds > 1000)
        {
            _logger.LogWarning("Slow database query: {QueryType} took {Duration}ms", queryType, duration.TotalMilliseconds);
        }
    }

    // ============================================
    // Dependencies (External calls tracking)
    // ============================================

    public void TrackDependency(string dependencyName, string commandName, DateTimeOffset startTime, TimeSpan duration, bool success)
    {
        try
        {
            _telemetryClient.TrackDependency(dependencyName, commandName, startTime, duration, success);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to track dependency: {DependencyName}", dependencyName);
        }
    }

    // ============================================
    // Exceptions (Error tracking)
    // ============================================

    public void TrackException(Exception exception, IDictionary<string, string>? properties = null)
    {
        try
        {
            var exceptionTelemetry = new ExceptionTelemetry(exception)
            {
                SeverityLevel = SeverityLevel.Error
            };

            if (properties != null)
            {
                foreach (var prop in properties)
                {
                    exceptionTelemetry.Properties[prop.Key] = prop.Value;
                }
            }

            // Add HDS compliance tag
            exceptionTelemetry.Properties["Compliance"] = "HDS";

            _telemetryClient.TrackException(exceptionTelemetry);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to track exception");
        }
    }

    // ============================================
    // Requests (HTTP request tracking)
    // ============================================

    public void TrackRequest(string name, DateTimeOffset startTime, TimeSpan duration, string responseCode, bool success)
    {
        try
        {
            _telemetryClient.TrackRequest(name, startTime, duration, responseCode, success);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to track request: {RequestName}", name);
        }
    }

    // ============================================
    // Traces (Logging)
    // ============================================

    public void TrackTrace(string message, SeverityLevel severityLevel, IDictionary<string, string>? properties = null)
    {
        try
        {
            var traceTelemetry = new TraceTelemetry(message, severityLevel);

            if (properties != null)
            {
                foreach (var prop in properties)
                {
                    traceTelemetry.Properties[prop.Key] = prop.Value;
                }
            }

            _telemetryClient.TrackTrace(traceTelemetry);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to track trace: {Message}", message);
        }
    }

    // ============================================
    // Operations (Distributed tracing)
    // ============================================

    public IOperationHolder<RequestTelemetry> StartOperation(string operationName)
    {
        return _telemetryClient.StartOperation<RequestTelemetry>(operationName);
    }
}

/// <summary>
/// Example usage in a controller or service
/// </summary>
public class PatientController
{
    private readonly ITelemetryService _telemetry;
    private readonly ILogger<PatientController> _logger;

    public PatientController(ITelemetryService telemetry, ILogger<PatientController> logger)
    {
        _telemetry = telemetry;
        _logger = logger;
    }

    public async Task<IActionResult> GetPatient(int patientId)
    {
        var stopwatch = Stopwatch.StartNew();

        try
        {
            using var operation = _telemetry.StartOperation("GetPatient");

            // Track patient access (HDS compliance)
            _telemetry.TrackPatientAccess(
                patientId: patientId.ToString(),
                action: "Read",
                userId: User.Identity?.Name ?? "Anonymous"
            );

            // Simulate database call
            var queryStopwatch = Stopwatch.StartNew();
            // var patient = await _patientRepository.GetByIdAsync(patientId);
            queryStopwatch.Stop();

            // Track database query time
            _telemetry.TrackDatabaseQueryTime("GetPatient", queryStopwatch.Elapsed);

            stopwatch.Stop();

            // Track overall response time
            _telemetry.TrackResponseTime("GetPatient", stopwatch.Elapsed);

            // Track custom metric
            _telemetry.TrackMetric("PatientsRetrieved", 1);

            return Ok(/* patient */);
        }
        catch (Exception ex)
        {
            stopwatch.Stop();

            // Track exception
            _telemetry.TrackException(ex, new Dictionary<string, string>
            {
                { "Operation", "GetPatient" },
                { "PatientId", patientId.ToString() }
            });

            _logger.LogError(ex, "Failed to get patient {PatientId}", patientId);

            return StatusCode(500, "Internal server error");
        }
    }

    public async Task<IActionResult> GetMedicalRecords(int patientId, int recordId)
    {
        try
        {
            // Track medical record access (HDS compliance)
            _telemetry.TrackMedicalRecordAccess(
                recordId: recordId.ToString(),
                patientId: patientId.ToString(),
                userId: User.Identity?.Name ?? "Anonymous"
            );

            // Business logic...

            return Ok();
        }
        catch (Exception ex)
        {
            _telemetry.TrackException(ex);
            return StatusCode(500);
        }
    }
}
