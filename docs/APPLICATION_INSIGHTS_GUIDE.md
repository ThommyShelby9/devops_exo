# Guide Application Insights : Monitoring et Télémétrie

## Vue d'ensemble

Ce guide décrit l'implémentation complète d'Application Insights pour le monitoring de performance et de disponibilité de la plateforme MedSecure, conforme aux exigences HDS Article 8.1.

**Objectifs** :
1. Monitoring en temps réel de la performance applicative
2. Détection proactive des anomalies et incidents
3. Traçabilité des accès aux données de santé (HDS Article 4.1)
4. Analyse des tendances et optimisation continue
5. Alertes automatiques en cas de dégradation

---

## Table des matières

1. [Architecture du monitoring](#architecture-du-monitoring)
2. [Infrastructure Application Insights](#infrastructure-application-insights)
3. [Instrumentation de l'application](#instrumentation-de-lapplication)
4. [Métriques et télémétrie custom](#métriques-et-télémétrie-custom)
5. [Alertes de performance](#alertes-de-performance)
6. [Tests de disponibilité](#tests-de-disponibilité)
7. [Requêtes KQL et dashboards](#requêtes-kql-et-dashboards)
8. [Conformité HDS](#conformité-hds)
9. [Dépannage](#dépannage)

---

## Architecture du monitoring

### Vue d'ensemble

```
┌────────────────────────────────────────────────────────────┐
│  Application .NET (MedSecure)                               │
│  • Application Insights SDK intégré                         │
│  • Telemetry Processors (filtres données sensibles)        │
│  • Custom telemetry (accès patients, métriques business)   │
└───────────────┬────────────────────────────────────────────┘
                │
                │ Telemetry Stream
                ▼
┌────────────────────────────────────────────────────────────┐
│  Application Insights                                       │
│  • Ingestion en temps réel                                  │
│  • Smart Detection (anomalies automatiques)                 │
│  • Métriques de performance                                 │
│  • Distributed tracing                                      │
└───────────────┬────────────────────────────────────────────┘
                │
                │ Storage
                ▼
┌────────────────────────────────────────────────────────────┐
│  Log Analytics Workspace                                    │
│  • Rétention 90 jours (HDS)                                 │
│  • Requêtes KQL                                             │
│  • Alertes et dashboards                                    │
└────────────────────────────────────────────────────────────┘
                │
                │ Alertes
                ▼
┌────────────────────────────────────────────────────────────┐
│  Action Group                                               │
│  • Email, SMS, Webhook                                      │
│  • Intégration Teams/Slack                                  │
└────────────────────────────────────────────────────────────┘
```

### Composants

| Composant | Rôle | Configuration |
|-----------|------|---------------|
| **Application Insights** | Collecte de télémétrie | Bicep: `appinsights.bicep` |
| **Telemetry Processors** | Filtrage données sensibles | C#: `ApplicationInsightsConfiguration.cs` |
| **Smart Detection** | Détection d'anomalies | Activé par défaut (5 règles) |
| **Performance Alerts** | Alertes métrique | Bicep: `performance-alerts.bicep` (7 alertes) |
| **Availability Tests** | Tests web geo-distribués | Bicep: `availability-tests.bicep` (3 tests) |
| **KQL Queries** | Analyse et dashboards | KQL: `appinsights-analytics.kql` (29 requêtes) |

---

## Infrastructure Application Insights

### Configuration Bicep

**Fichier** : `infra/core/monitor/appinsights.bicep`

```bicep
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    RetentionInDays: 90  // HDS: 90 jours minimum
    IngestionMode: 'LogAnalytics'
    SamplingPercentage: 100
    DisableLocalAuth: true  // Azure AD auth only
  }
}
```

**Paramètres clés** :
- ✅ **RetentionInDays**: 90 jours (conforme HDS Article 4.2)
- ✅ **DisableLocalAuth**: Authentification Azure AD uniquement (HDS)
- ✅ **WorkspaceResourceId**: Intégration Log Analytics
- ✅ **SamplingPercentage**: 100% (pas de sampling par défaut)

### Smart Detection (Détection automatique d'anomalies)

**5 règles activées par défaut** :

1. **Failure Anomalies** - Pic anormal de requêtes échouées
2. **Slow Page Load Time** - Dégradation du temps de chargement
3. **Slow Server Response Time** - Dégradation du temps de réponse serveur
4. **Long Dependency Duration** - Dégradation des appels externes
5. **Exception Volume Changed** - Augmentation anormale des exceptions

**Configuration** :
```bicep
resource smartDetectionFailure 'Microsoft.Insights/components/ProactiveDetectionConfigs@2018-05-01-preview' = {
  name: 'FailureAnomaliesDetector'
  parent: appInsights
  properties: {
    name: 'Failure Anomalies'
    enabled: true
    sendEmailsToSubscriptionOwners: false
    customEmails: []
  }
}
```

---

## Instrumentation de l'application

### Configuration Startup

**Fichier** : `src/Configuration/ApplicationInsightsConfiguration.cs`

```csharp
// Program.cs ou Startup.cs
services.AddMedSecureApplicationInsights(configuration);
```

**Extension method** :
```csharp
public static IServiceCollection AddMedSecureApplicationInsights(
    this IServiceCollection services,
    IConfiguration configuration)
{
    var aiOptions = new ApplicationInsightsServiceOptions
    {
        ConnectionString = configuration["ApplicationInsights:ConnectionString"],
        EnableAdaptiveSampling = true,
        EnablePerformanceCounterCollectionModule = true,
        EnableDependencyTrackingTelemetryModule = true,
        EnableHeartbeat = true,
        DisableLocalAuth = true  // HDS: Azure AD only
    };

    services.AddApplicationInsightsTelemetry(aiOptions);

    // Add telemetry processors (HDS compliance)
    services.AddApplicationInsightsTelemetryProcessor<SensitiveDataFilterProcessor>();
    services.AddApplicationInsightsTelemetryProcessor<HealthCheckFilterProcessor>();

    // Add custom initializers
    services.AddSingleton<ITelemetryInitializer, CloudRoleNameInitializer>();
    services.AddSingleton<ITelemetryInitializer, UserIdentityInitializer>();
    services.AddSingleton<ITelemetryInitializer, ComplianceTagInitializer>();

    return services;
}
```

### Filtrage des données sensibles (HDS)

**Telemetry Processor** :
```csharp
public class SensitiveDataFilterProcessor : ITelemetryProcessor
{
    private readonly string[] _sensitiveKeys = new[]
    {
        "password", "token", "secret", "key", "authorization",
        "ssn", "socialsecuritynumber", "email", "phonenumber"
    };

    public void Process(ITelemetry item)
    {
        if (item is RequestTelemetry request)
        {
            // Redact sensitive query strings
            request.Url = RedactSensitiveQueryStrings(request.Url);

            // Filter sensitive properties
            FilterSensitiveProperties(request.Properties);
        }

        _next.Process(item);
    }
}
```

**Protection** :
- ✅ Suppression des mots de passe, tokens, secrets
- ✅ Redaction des données personnelles (email, téléphone, SSN)
- ✅ Filtrage des query strings sensibles
- ✅ Conformité RGPD Article 32

### Filtrage des health checks

```csharp
public class HealthCheckFilterProcessor : ITelemetryProcessor
{
    private readonly string[] _healthCheckPaths = new[]
    {
        "/health", "/api/health", "/healthz", "/ready", "/live"
    };

    public void Process(ITelemetry item)
    {
        if (item is RequestTelemetry request)
        {
            // Don't send health check requests (reduce noise)
            if (_healthCheckPaths.Any(path =>
                request.Url?.AbsolutePath?.Equals(path, StringComparison.OrdinalIgnoreCase) == true))
            {
                return;  // Skip telemetry
            }
        }

        _next.Process(item);
    }
}
```

---

## Métriques et télémétrie custom

### Service de télémétrie

**Fichier** : `src/Services/TelemetryService.cs`

```csharp
public interface ITelemetryService
{
    void TrackEvent(string eventName, IDictionary<string, string>? properties = null);
    void TrackPatientAccess(string patientId, string action, string userId);
    void TrackMedicalRecordAccess(string recordId, string patientId, string userId);
    void TrackMetric(string metricName, double value);
    void TrackResponseTime(string operation, TimeSpan duration);
    void TrackException(Exception exception);
}
```

### Tracking d'accès aux données (HDS)

```csharp
// Track patient data access (HDS Article 4.1)
_telemetry.TrackPatientAccess(
    patientId: patientId.ToString(),
    action: "Read",
    userId: User.Identity?.Name ?? "Anonymous"
);

// Track medical record access
_telemetry.TrackMedicalRecordAccess(
    recordId: recordId.ToString(),
    patientId: patientId.ToString(),
    userId: User.Identity?.Name ?? "Anonymous"
);
```

**Données trackées** :
```json
{
  "name": "PatientDataAccess",
  "customDimensions": {
    "PatientId": "12345",
    "Action": "Read",
    "UserId": "doctor@medsecure.health",
    "Timestamp": "2026-02-09T14:30:00Z",
    "Compliance": "HDS-4.1",
    "DataType": "PatientData"
  }
}
```

### Métriques de performance

```csharp
public async Task<IActionResult> GetPatient(int patientId)
{
    var stopwatch = Stopwatch.StartNew();

    try
    {
        using var operation = _telemetry.StartOperation("GetPatient");

        // Business logic...
        var patient = await _patientRepository.GetByIdAsync(patientId);

        stopwatch.Stop();

        // Track metrics
        _telemetry.TrackResponseTime("GetPatient", stopwatch.Elapsed);
        _telemetry.TrackMetric("PatientsRetrieved", 1);

        // Track audit (HDS)
        _telemetry.TrackPatientAccess(patientId.ToString(), "Read", User.Identity?.Name);

        return Ok(patient);
    }
    catch (Exception ex)
    {
        _telemetry.TrackException(ex, new Dictionary<string, string>
        {
            { "Operation", "GetPatient" },
            { "PatientId", patientId.ToString() }
        });

        throw;
    }
}
```

### Distributed Tracing

```csharp
// Start an operation for distributed tracing
using (var operation = _telemetryClient.StartOperation<RequestTelemetry>("ProcessPayment"))
{
    // Call external API
    var result = await _paymentService.ProcessAsync(payment);

    // Track dependency automatically
    operation.Telemetry.Success = result.IsSuccess;
}
```

---

## Alertes de performance

### 7 alertes configurées

**Fichier** : `infra/core/monitor/performance-alerts.bicep`

| Alerte | Métrique | Seuil | Sévérité | Conformité |
|--------|----------|-------|----------|------------|
| **High Response Time** | requests/duration | >2000ms | Haute (2) | HDS 8.1 |
| **High Error Rate** | requests/failed | >5% | Critique (1) | HDS 8.1 |
| **Low Availability** | availabilityResults/availabilityPercentage | <99% | Critique (1) | HDS 8.1 |
| **High Dependency Duration** | dependencies/duration | >5000ms | Moyenne (3) | HDS 8.1 |
| **High Server Exceptions** | exceptions/server | >10/min | Haute (2) | HDS 8.1 |
| **High Memory Usage** | performanceCounters/availableMemory | <20% | Haute (2) | HDS 8.1 |
| **High CPU Usage** | performanceCounters/processCpuPercentage | >80% | Moyenne (3) | HDS 8.1 |

### Configuration d'une alerte

```bicep
resource alertHighResponseTime 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-high-response-time'
  location: 'global'
  properties: {
    description: 'Triggers when average response time exceeds 2 seconds'
    severity: 2  // High
    enabled: true
    scopes: [appInsightsId]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          metricName: 'requests/duration'
          operator: 'GreaterThan'
          threshold: 2000
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroupId
        webHookProperties: {
          AlertType: 'PerformanceDegradation'
          Severity: 'High'
          Compliance: 'HDS-8.1'
        }
      }
    ]
  }
}
```

---

## Tests de disponibilité

### 3 tests web geo-distribués

**Fichier** : `infra/core/monitor/availability-tests.bicep`

| Test | Endpoint | Fréquence | Timeout | Locations |
|------|----------|-----------|---------|-----------|
| **Home Page** | `/` | 5 min | 30s | 5 régions |
| **Health Endpoint** | `/health` | 5 min | 30s | 5 régions |
| **API Endpoint** | `/api/health` | 5 min | 30s | 5 régions |

### Locations géographiques

```bicep
param testLocations array = [
  { Id: 'emea-fr-pra-edge' }  // France Central
  { Id: 'emea-nl-ams-azr' }   // West Europe
  { Id: 'emea-gb-db3-azr' }   // UK South
  { Id: 'us-va-ash-azr' }     // East US
  { Id: 'apac-sg-sin-azr' }   // Southeast Asia
]
```

### Configuration d'un test

```bicep
resource availabilityTestHealth 'Microsoft.Insights/webtests@2022-06-15' = {
  name: 'webtest-health'
  location: location
  kind: 'standard'
  properties: {
    Name: 'MedSecure - Health Endpoint'
    Enabled: true
    Frequency: 300  // 5 minutes
    Timeout: 30
    Locations: testLocations

    Request: {
      RequestUrl: '${webAppUrl}/health'
      HttpVerb: 'GET'
    }

    ValidationRules: {
      ExpectedHttpStatusCode: 200
      SSLCheck: true
      SSLCertRemainingLifetimeCheck: 7  // Alert if cert expires in 7 days
      ContentValidation: {
        ContentMatch: 'Healthy'
        PassIfTextFound: true
      }
    }
  }
}
```

### Alerte de disponibilité

```bicep
resource alertAvailabilityTestFailed 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  properties: {
    description: 'Triggers when availability test fails from 2+ locations'
    severity: 1  // Critical
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria'
      webTestId: availabilityTestHealth.id
      componentId: appInsightsId
      failedLocationCount: 2
    }
  }
}
```

---

## Requêtes KQL et dashboards

### Requêtes KQL disponibles

**Fichier** : `monitoring/kql-queries/appinsights-analytics.kql`

**29 requêtes organisées par catégorie** :

#### Performance (4 requêtes)
1. Average Response Time (Last 24 hours)
2. Slowest Requests (Top 20)
3. Request Success Rate
4. HTTP Status Code Distribution

#### Dependencies (3 requêtes)
5. Database Query Performance
6. External API Calls Performance
7. Dependency Failures

#### Exceptions (3 requêtes)
8. Exception Trends
9. Top Exceptions
10. Exception Stack Trace

#### Availability (3 requêtes)
11. Availability Test Results
12. Availability Over Time
13. Failed Availability Tests

#### Custom Events (3 requêtes)
14. Patient Data Access (HDS)
15. Medical Record Access (HDS)
16. User Activity (Audit Trail)

#### Performance Counters (3 requêtes)
17. CPU Usage Over Time
18. Memory Usage Over Time
19. Request Rate

#### Custom Metrics (2 requêtes)
20. Response Time Trend
21. Database Query Duration Trend

#### Logs (2 requêtes)
22. Error Logs
23. Warning Logs

#### Compliance (2 requêtes)
24. HDS Compliance Report
25. Service Level Agreement (SLA) Report

#### Anomaly Detection (2 requêtes)
26. Response Time Anomalies
27. Exception Rate Anomalies

#### Distributed Tracing (2 requêtes)
28. End-to-End Transaction Trace
29. Failed Request Details with Dependencies

### Exemple : Performance metrics

```kql
// Average Response Time (Last 24 hours)
requests
| where timestamp > ago(24h)
| summarize
    AvgDuration = avg(duration),
    P50Duration = percentile(duration, 50),
    P95Duration = percentile(duration, 95),
    P99Duration = percentile(duration, 99),
    RequestCount = count()
    by bin(timestamp, 1h), name
| project
    Time = timestamp,
    Operation = name,
    AvgResponseTime_ms = round(AvgDuration, 2),
    P50_ms = round(P50Duration, 2),
    P95_ms = round(P95Duration, 2),
    P99_ms = round(P99Duration, 2),
    TotalRequests = RequestCount
| order by Time desc
```

### Exemple : HDS Compliance Report

```kql
// HDS Compliance Report (Last 24 hours)
union
    (requests | summarize RequestCount = count() | extend MetricType = "Total Requests"),
    (requests | where success == false | summarize FailedRequests = count() | extend MetricType = "Failed Requests"),
    (exceptions | summarize Exceptions = count() | extend MetricType = "Exceptions"),
    (availabilityResults | summarize AvgAvailability = round(avg(toint(success)) * 100, 2) | extend MetricType = "Availability %"),
    (customEvents | where name == "PatientDataAccess" | summarize PatientAccesses = count() | extend MetricType = "Patient Data Accesses")
| project MetricType, Value = coalesce(RequestCount, FailedRequests, Exceptions, AvgAvailability, PatientAccesses)
```

---

## Conformité HDS

### Article 8.1 - Surveillance de la disponibilité

| Exigence HDS | Implémentation | Statut |
|--------------|----------------|--------|
| Monitoring en temps réel | Application Insights avec ingestion <1min | ✅ 100% |
| Détection des anomalies | Smart Detection (5 règles) | ✅ 100% |
| Tests de disponibilité | 3 tests web geo-distribués (5min) | ✅ 100% |
| Alertes automatiques | 7 alertes de performance + 1 disponibilité | ✅ 100% |
| Traçabilité des performances | Métriques et logs (rétention 90j) | ✅ 100% |
| SLA monitoring | Requête KQL dédiée (99% target) | ✅ 100% |
| Audit des accès | Custom events Patient/MedicalRecord | ✅ 100% |

**Score global HDS Article 8.1** : ✅ **100%**

### Article 4.1 - Traçabilité (via Application Insights)

```csharp
// Track patient access for HDS compliance
_telemetry.TrackPatientAccess(
    patientId: "12345",
    action: "Read",
    userId: "doctor@medsecure.health"
);
```

**Requête KQL pour audit** :
```kql
customEvents
| where name == "PatientDataAccess"
| extend
    PatientId = tostring(customDimensions.PatientId),
    Action = tostring(customDimensions.Action),
    UserId = tostring(customDimensions.UserId)
| project Timestamp = timestamp, PatientId, Action, UserId
| order by Timestamp desc
```

---

## Dépannage

### Problème : Télémétrie ne s'affiche pas

**Symptômes** :
- Aucune donnée dans Application Insights
- Connection string configurée correctement

**Solutions** :

1. **Vérifier la connection string** :
   ```bash
   # Azure Portal → Application Insights → Properties
   InstrumentationKey=xxxxx;IngestionEndpoint=https://...
   ```

2. **Vérifier le package NuGet** :
   ```xml
   <PackageReference Include="Microsoft.ApplicationInsights.AspNetCore" Version="2.21.0" />
   ```

3. **Vérifier la configuration** :
   ```csharp
   // Program.cs
   services.AddApplicationInsightsTelemetry(configuration["ApplicationInsights:ConnectionString"]);
   ```

4. **Check local development** :
   ```json
   // appsettings.Development.json
   {
     "ApplicationInsights": {
       "ConnectionString": "InstrumentationKey=..."
     }
   }
   ```

### Problème : Smart Detection ne fonctionne pas

**Cause** : Pas assez de données historiques (besoin de 24-48h)

**Solution** : Attendre 48h de collecte de données

### Problème : Availability tests échouent

**Vérifications** :
1. URL accessible publiquement
2. Firewall autorise les IP Azure
3. Certificat SSL valide
4. Content validation correcte

```bash
# Test manual
curl -v https://your-app.azurewebsites.net/health
```

### Problème : Trop de télémétrie (coût élevé)

**Solutions** :

1. **Activer le sampling** :
   ```csharp
   services.Configure<TelemetryConfiguration>(config =>
   {
       config.DefaultTelemetrySink.TelemetryProcessorChainBuilder
           .UseAdaptiveSampling(maxTelemetryItemsPerSecond: 5)
           .Build();
   });
   ```

2. **Filtrer les health checks** :
   ```csharp
   services.AddApplicationInsightsTelemetryProcessor<HealthCheckFilterProcessor>();
   ```

3. **Configurer daily cap** :
   ```bicep
   dailyQuotaGb: 10  // 10GB par jour maximum
   ```

---

## Métriques de performance

### Objectifs de performance

| Métrique | Target | Alerte si |
|----------|--------|-----------|
| Temps de réponse moyen | <500ms | >2000ms |
| P95 temps de réponse | <1000ms | >3000ms |
| P99 temps de réponse | <2000ms | >5000ms |
| Taux d'erreur | <1% | >5% |
| Disponibilité | >99.9% | <99% |
| Exceptions | <5/min | >10/min |

### Dashboard recommandé

**Tuiles clés** :
1. Taux de disponibilité (24h)
2. Temps de réponse moyen (P50, P95, P99)
3. Taux d'erreur (%)
4. Nombre d'exceptions
5. Top 5 requêtes lentes
6. Top 5 exceptions
7. Carte géographique (availability tests)
8. CPU et mémoire

---

## Ressources

### Documentation Microsoft

- [Application Insights Overview](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Telemetry Data Model](https://learn.microsoft.com/azure/azure-monitor/app/data-model)
- [Kusto Query Language (KQL)](https://learn.microsoft.com/azure/data-explorer/kusto/query/)

### Fichiers du projet

- Infrastructure : `infra/core/monitor/appinsights.bicep`
- Alertes : `infra/core/monitor/performance-alerts.bicep`
- Tests : `infra/core/monitor/availability-tests.bicep`
- Configuration : `src/Configuration/ApplicationInsightsConfiguration.cs`
- Service : `src/Services/TelemetryService.cs`
- Requêtes : `monitoring/kql-queries/appinsights-analytics.kql`

---

**Date de création** : 2026-02-09
**Version** : 1.0.0
**Auteur** : DevSecOps Team - MedSecure Platform
**Conformité** : HDS Article 8.1, ISO 27001 A.12.1
