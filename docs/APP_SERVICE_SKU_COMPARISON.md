# Comparaison des SKU Azure App Service pour MedSecure

## 📊 Tableau Comparatif

| Fonctionnalité | B1 (Basic) | S1 (Standard) ⭐ | P1V2 (Premium) |
|----------------|------------|------------------|----------------|
| **Prix mensuel** | ~13€ | ~67€ | ~150€ |
| **Mémoire** | 1.75 GB | 1.75 GB | 3.5 GB |
| **CPU** | 1 core | 1 core | 1 core |
| **Deployment Slots** | ❌ Non | ✅ 5 slots | ✅ 20 slots |
| **Auto-scaling** | ❌ Non | ✅ Oui (10 instances) | ✅ Oui (30 instances) |
| **SLA** | 99.95% | **99.95%** | **99.95%** |
| **Backups automatiques** | ❌ Non | ✅ Oui | ✅ Oui |
| **Custom domains SSL** | ✅ Oui | ✅ Oui | ✅ Oui |
| **Zone redundancy** | ❌ Non | ❌ Non | ✅ Oui |
| **Traffic Manager** | ✅ Oui | ✅ Oui | ✅ Oui |
| **VNet Integration** | ❌ Non | ✅ Oui | ✅ Oui |
| **Private Endpoints** | ❌ Non | ❌ Non | ✅ Oui |

## 🎯 Pourquoi S1 pour MedSecure ?

### ✅ Conformité HDS

**Exigences HDS satisfaites par S1 :**
1. **Deployment Slots** : Nécessaire pour déploiement Blue/Green sans interruption
2. **Auto-scaling** : Gestion de charge pour respecter le SLO 99.95%
3. **Backups automatiques** : Sauvegarde régulière des configurations
4. **VNet Integration** : Isolation réseau pour sécurité renforcée
5. **SLA 99.95%** : Disponibilité garantie

### 🚫 Pourquoi pas B1 (Basic) ?

**Limitations bloquantes :**
- ❌ **Pas de deployment slots** → Impossible de faire du Blue/Green
- ❌ **Pas d'auto-scaling** → Risque de surcharge lors de pics
- ❌ **Pas de backups automatiques** → Non conforme HDS
- ❌ **Pas de VNet integration** → Sécurité limitée

### 💡 Pourquoi pas P1V2 (Premium) ?

**Premium est recommandé si :**
- ✅ Besoin de **Private Endpoints** (isolation réseau totale)
- ✅ Besoin de **Zone Redundancy** (haute disponibilité multi-zones)
- ✅ Plus de **20 deployment slots** nécessaires
- ✅ Charge importante (> 10 instances)

**Pour démarrer, S1 suffit :**
- ✅ Coût optimisé (~67€/mois vs ~150€/mois)
- ✅ Toutes les fonctionnalités HDS essentielles
- ✅ Possibilité de scaler vers Premium plus tard

## 🔄 Évolution recommandée

### Phase 1 : Développement
- **Free/Shared** : Pour tests locaux uniquement
- ⚠️ Ne JAMAIS utiliser en production pour données de santé

### Phase 2 : Staging/QA (actuel)
- **S1 Standard** : Environnement de validation
- ✅ Toutes les fonctionnalités HDS
- ✅ Blue/Green deployment
- ✅ Coût maîtrisé

### Phase 3 : Production MedSecure
- **S1 Standard** → **P1V2 Premium**
- ✅ Private Endpoints (isolation totale)
- ✅ Zone Redundancy (multi-AZ)
- ✅ Meilleure performance (3.5GB RAM)

### Phase 4 : Scale national
- **P2V2/P3V2 Premium**
- ✅ Plus de puissance (7GB/14GB RAM)
- ✅ Auto-scaling jusqu'à 30 instances
- ✅ Support de milliers de cabinets médicaux

## 💰 Estimation des coûts mensuels

| Environnement | SKU | Instances | Coût mensuel estimé |
|---------------|-----|-----------|---------------------|
| **DEV** | B1 | 1 | ~13€ |
| **STAGING** | S1 | 1 | ~67€ |
| **PRODUCTION** | S1 | 2 (HA) | ~134€ |
| **PRODUCTION (future)** | P1V2 | 2 (HA) | ~300€ |

## 🛡️ Configuration Auto-Scaling pour HDS

### Règles de scaling S1 (Standard)

```bicep
// Auto-scaling basé sur CPU
resource autoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: 'cpu-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: appServicePlan.id
    profiles: [
      {
        name: 'Scale based on CPU'
        capacity: {
          minimum: '1'
          maximum: '3'
          default: '1'
        }
        rules: [
          {
            // Scale OUT when CPU > 70% for 5 minutes
            metricTrigger: {
              metricName: 'CpuPercentage'
              operator: 'GreaterThan'
              threshold: 70
              timeAggregation: 'Average'
              timeWindow: 'PT5M'
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            // Scale IN when CPU < 30% for 10 minutes
            metricTrigger: {
              metricName: 'CpuPercentage'
              operator: 'LessThan'
              threshold: 30
              timeAggregation: 'Average'
              timeWindow: 'PT10M'
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
  }
}
```

## 📚 Ressources

- [App Service Pricing](https://azure.microsoft.com/pricing/details/app-service/windows/)
- [App Service Plan Overview](https://learn.microsoft.com/azure/app-service/overview-hosting-plans)
- [Auto-scaling in App Service](https://learn.microsoft.com/azure/app-service/manage-automatic-scaling)
- [Azure SLA for App Service](https://www.microsoft.com/licensing/docs/view/Service-Level-Agreements-SLA-for-Online-Services)

## ✅ Décision pour MedSecure

**SKU choisi : S1 (Standard)**

**Justification :**
1. ✅ Répond à 100% des exigences HDS de base
2. ✅ Support du déploiement Blue/Green (5 slots)
3. ✅ Auto-scaling jusqu'à 10 instances
4. ✅ SLA 99.95% garanti
5. ✅ Coût optimisé pour phase de lancement
6. ✅ Migration vers Premium facile si besoin

**Evolution prévue :** S1 → P1V2 lors du passage à 500+ cabinets médicaux.
