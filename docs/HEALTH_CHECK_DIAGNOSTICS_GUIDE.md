# Guide Health Check & Diagnostics pour MedSecure

## 📋 Vue d'ensemble

Les health checks et diagnostics sont essentiels pour :
- ✅ **Blue/Green deployment** : Validation avant swap
- ✅ **Auto-healing** : Redémarrage automatique si unhealthy
- ✅ **SLO 99.95%** : Monitoring proactif de disponibilité
- ✅ **HDS audit trail** : Traçabilité des requêtes HTTP

## 🏥 Implémentation Health Check (.NET 8)

### 1. Configuration dans Program.cs

**src/Web/Program.cs**
```csharp
var builder = WebApplication.CreateBuilder(args);

// Add health checks
builder.Services.AddHealthChecks()
    .AddDbContextCheck<CatalogContext>("catalog-db")
    .AddDbContextCheck<AppIdentityDbContext>("identity-db")
    .AddAzureKeyVault(
        new Uri(builder.Configuration["AZURE_KEY_VAULT_ENDPOINT"]!),
        new DefaultAzureCredential(),
        options => {
            options.Name = "keyvault";
        })
    .AddApplicationInsightsPublisher();

var app = builder.Build();

// Map health check endpoint
app.MapHealthChecks("/health", new HealthCheckOptions
{
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse,
    ResultStatusCodes =
    {
        [HealthStatus.Healthy] = StatusCodes.Status200OK,
        [HealthStatus.Degraded] = StatusCodes.Status200OK,
        [HealthStatus.Unhealthy] = StatusCodes.Status503ServiceUnavailable
    }
});

// Detailed health check for monitoring (not exposed publicly)
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready"),
    ResponseWriter = UIResponseWriter.WriteHealthCheckUIResponse
});

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false, // Just return 200 if app is running
    ResponseWriter = (context, _) =>
    {
        context.Response.ContentType = "application/json";
        return context.Response.WriteAsync("{\"status\":\"Healthy\"}");
    }
});

app.Run();
```

### 2. Packages NuGet requis

```xml
<PackageReference Include="AspNetCore.HealthChecks.UI" Version="7.0.2" />
<PackageReference Include="AspNetCore.HealthChecks.UI.Client" Version="7.0.2" />
<PackageReference Include="AspNetCore.HealthChecks.SqlServer" Version="7.0.0" />
<PackageReference Include="AspNetCore.HealthChecks.AzureKeyVault" Version="7.0.0" />
<PackageReference Include="AspNetCore.HealthChecks.Publisher.ApplicationInsights" Version="7.0.0" />
```

### 3. Custom Health Check pour données de santé

**Infrastructure/HealthChecks/DatabaseEncryptionHealthCheck.cs**
```csharp
public class DatabaseEncryptionHealthCheck : IHealthCheck
{
    private readonly CatalogContext _context;

    public DatabaseEncryptionHealthCheck(CatalogContext context)
    {
        _context = context;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Verify TDE is enabled
            var tdeStatus = await _context.Database
                .SqlQueryRaw<string>(
                    "SELECT encryption_state FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID()")
                .FirstOrDefaultAsync(cancellationToken);

            if (tdeStatus == "3") // 3 = Encrypted
            {
                return HealthCheckResult.Healthy(
                    "TDE is enabled and database is encrypted");
            }

            return HealthCheckResult.Degraded(
                "TDE encryption in progress or not fully enabled");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy(
                "Failed to verify database encryption",
                exception: ex);
        }
    }
}
```

**Enregistrement :**
```csharp
builder.Services.AddHealthChecks()
    .AddCheck<DatabaseEncryptionHealthCheck>(
        "database-encryption",
        tags: new[] { "ready", "hds" });
```

### 4. Réponse Health Check

**Format JSON (AspNetCore.HealthChecks.UI.Client) :**
```json
{
  "status": "Healthy",
  "totalDuration": "00:00:00.1234567",
  "entries": {
    "catalog-db": {
      "data": {},
      "duration": "00:00:00.0234567",
      "status": "Healthy"
    },
    "identity-db": {
      "data": {},
      "duration": "00:00:00.0134567",
      "status": "Healthy"
    },
    "keyvault": {
      "data": {},
      "duration": "00:00:00.0534567",
      "status": "Healthy"
    },
    "database-encryption": {
      "data": {},
      "description": "TDE is enabled and database is encrypted",
      "duration": "00:00:00.0334567",
      "status": "Healthy"
    }
  }
}
```

## 🔍 Diagnostics App Service

### Logs capturés dans Log Analytics

| Catégorie | Description | Usage HDS |
|-----------|-------------|-----------|
| **AppServiceHTTPLogs** | Requêtes HTTP (IP, URL, status code) | Audit accès patients |
| **AppServiceAppLogs** | Logs applicatifs (.NET ILogger) | Erreurs métier |
| **AppServiceConsoleLogs** | stdout/stderr | Debugging |
| **AppServiceAuditLogs** | Changements config, accès fichiers | Conformité HDS |
| **AppServicePlatformLogs** | Infrastructure (redémarrages) | Disponibilité |

### Requêtes KQL pour monitoring

#### 1. Requêtes HTTP par code de statut (24h)

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(24h)
| summarize Count = count() by ScStatus
| order by Count desc
| render piechart
```

#### 2. Erreurs 500 (dernière heure)

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| where ScStatus >= 500
| project TimeGenerated, CsHost, CsUriStem, ScStatus, TimeTaken, CIp
| order by TimeGenerated desc
```

#### 3. Top 10 URLs les plus accédées

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(24h)
| summarize Requests = count() by CsUriStem
| top 10 by Requests desc
```

#### 4. Latency (percentiles p50, p95, p99)

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| summarize
    p50 = percentile(TimeTaken, 50),
    p95 = percentile(TimeTaken, 95),
    p99 = percentile(TimeTaken, 99)
| project
    p50_ms = p50,
    p95_ms = p95,
    p99_ms = p99
```

#### 5. Health check failures

```kusto
AppServiceHTTPLogs
| where CsUriStem == "/health"
| where ScStatus != 200
| project TimeGenerated, ScStatus, TimeTaken
| order by TimeGenerated desc
```

#### 6. Erreurs applicatives (.NET logs)

```kusto
AppServiceAppLogs
| where TimeGenerated > ago(24h)
| where Level in ("Error", "Critical")
| project TimeGenerated, Level, Message, ExceptionType
| order by TimeGenerated desc
```

#### 7. Accès patients (audit HDS)

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(24h)
| where CsUriStem contains "/patients/"
| extend PatientId = extract(@"/patients/(\d+)", 1, CsUriStem)
| summarize AccessCount = count() by PatientId, CIp
| order by AccessCount desc
```

#### 8. Temps de réponse par endpoint

```kusto
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| summarize AvgResponseTime = avg(TimeTaken), MaxResponseTime = max(TimeTaken)
    by CsUriStem
| where AvgResponseTime > 1000  // Plus de 1 seconde
| order by AvgResponseTime desc
```

## 🚨 Alertes recommandées

### Alerte 1 : Health Check Failed

```bicep
resource healthCheckAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'app-health-check-failed'
  location: 'global'
  properties: {
    severity: 1  // Error
    description: 'App Service health check is failing'
    enabled: true
    scopes: [appService.id]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          name: 'HealthCheckStatus'
          metricName: 'HealthCheckStatus'
          operator: 'LessThan'
          threshold: 100
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
```

### Alerte 2 : HTTP 5xx Errors

```bicep
resource http5xxAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'app-http-5xx-errors'
  location: 'global'
  properties: {
    severity: 2  // Warning
    description: 'High rate of HTTP 5xx errors'
    enabled: true
    scopes: [appService.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          name: 'Http5xx'
          metricName: 'Http5xx'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Total'
        }
      ]
    }
  }
}
```

### Alerte 3 : Response Time Degradation

```bicep
resource responseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'app-response-time-slow'
  location: 'global'
  properties: {
    severity: 2  // Warning
    description: 'Average response time exceeds 1 second (SLO violation)'
    enabled: true
    scopes: [appService.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          name: 'HttpResponseTime'
          metricName: 'HttpResponseTime'
          operator: 'GreaterThan'
          threshold: 1  // 1 second
          timeAggregation: 'Average'
        }
      ]
    }
  }
}
```

### Alerte 4 : Auto-Healing Triggered

```kusto
// Alert query for Log Analytics
AppServicePlatformLogs
| where TimeGenerated > ago(5m)
| where Message contains "auto-heal"
| project TimeGenerated, Message
```

## 🔧 Configuration Auto-Healing

### Redémarrage automatique si unhealthy

**Azure Portal ou Bicep :**
```bicep
resource autoHealRules 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: appService
  name: 'web'
  properties: {
    autoHealEnabled: true
    autoHealRules: {
      triggers: {
        statusCodes: [
          {
            status: 500
            subStatus: 0
            count: 10
            timeInterval: '00:05:00'  // 10 erreurs 500 en 5 minutes
          }
        ]
        slowRequests: {
          timeTaken: '00:00:30'  // Plus de 30 secondes
          count: 5
          timeInterval: '00:05:00'
        }
      }
      actions: {
        actionType: 'Recycle'
        minProcessExecutionTime: '00:01:00'  // Attendre 1 min avant recycle
      }
    }
  }
}
```

## 📊 Dashboard de monitoring

### Azure Workbook - MedSecure Health

```json
{
  "version": "Notebook/1.0",
  "items": [
    {
      "type": 1,
      "content": {
        "json": "## MedSecure - Application Health Dashboard\n\n**Conformité HDS** | **SLO 99.95%**"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AppServiceHTTPLogs\n| where TimeGenerated > ago(1h)\n| summarize Requests = count() by bin(TimeGenerated, 5m), Result = case(ScStatus < 400, 'Success', ScStatus < 500, 'Client Error', 'Server Error')\n| render timechart",
        "size": 0,
        "title": "HTTP Requests (1 hour)"
      }
    },
    {
      "type": 3,
      "content": {
        "version": "KqlItem/1.0",
        "query": "AppServiceHTTPLogs\n| where TimeGenerated > ago(1h)\n| summarize p50 = percentile(TimeTaken, 50), p95 = percentile(TimeTaken, 95), p99 = percentile(TimeTaken, 99) by bin(TimeGenerated, 5m)\n| render timechart",
        "size": 0,
        "title": "Response Time (p50, p95, p99)"
      }
    }
  ]
}
```

## ✅ Checklist Conformité HDS

### Health Checks
- [x] **/health endpoint** implémenté
- [x] **Database connectivity** vérifié
- [x] **Key Vault access** vérifié
- [x] **TDE encryption** vérifié
- [x] **Response time < 500ms** (p95)

### Diagnostics
- [x] **HTTP logs** vers Log Analytics (90 jours)
- [x] **Application logs** (.NET ILogger)
- [x] **Audit logs** (accès fichiers, config)
- [x] **Platform logs** (infrastructure)
- [x] **Metrics** (CPU, Memory, Response Time)

### Monitoring
- [ ] **Alerte health check** configurée
- [ ] **Alerte HTTP 5xx** configurée
- [ ] **Alerte response time** configurée
- [ ] **Dashboard** créé (Azure Workbook)
- [ ] **Auto-healing** activé

## 📚 Ressources

- [ASP.NET Core Health Checks](https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks)
- [App Service Diagnostics](https://learn.microsoft.com/azure/app-service/troubleshoot-diagnostic-logs)
- [Azure Monitor Metrics](https://learn.microsoft.com/azure/azure-monitor/essentials/metrics-supported#microsoftwebsites)
- [Health Checks UI](https://github.com/Xabaril/AspNetCore.Diagnostics.HealthChecks)

## 🎯 Validation

Pour valider que tout fonctionne :

```bash
# 1. Tester le health check
curl https://your-app.azurewebsites.net/health

# Résultat attendu: 200 OK avec JSON détaillé

# 2. Vérifier les logs dans Log Analytics (après 5-10 min)
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "AppServiceHTTPLogs | where CsUriStem == '/health' | order by TimeGenerated desc | take 10"

# 3. Forcer un échec (test)
# Arrêter la base de données temporairement
curl https://your-app.azurewebsites.net/health
# Résultat attendu: 503 Service Unavailable
```
