# Pull Request

## 📋 Description

<!-- Décrivez clairement les changements et leur raison d'être -->

## 🏷️ Type de changement

- [ ] ✨ Feature (nouvelle fonctionnalité)
- [ ] 🐛 Bugfix (correction de bug)
- [ ] 🔥 Hotfix (correction urgente production)
- [ ] 🔒 Security (patch de sécurité)
- [ ] ♻️ Refactoring
- [ ] 📝 Documentation
- [ ] ⚡ Performance
- [ ] 🎨 Style/UI
- [ ] 🧪 Tests

## 📌 User Story / Issue

Closes #<!-- numéro de l'issue -->
Related to #<!-- numéros des issues liées -->

## 🔨 Changements effectués

-
-
-

## ✅ Tests effectués

- [ ] Tests unitaires ajoutés/modifiés
- [ ] Tests d'intégration passent
- [ ] Tests manuels effectués
- [ ] Testé en environnement local
- [ ] Tests de régression OK

### Scénarios testés

1.
2.
3.

## 🔐 Checklist sécurité (HDS OBLIGATOIRE)

- [ ] Pas de données sensibles en clair dans le code
- [ ] Chiffrement approprié si données de santé manipulées
- [ ] Audit trail implémenté si accès aux données de santé
- [ ] Validation et sanitization des entrées utilisateur
- [ ] Pas de secrets hardcodés (vérification Gitleaks OK)
- [ ] Authentification/autorisation vérifiée
- [ ] Protection contre SQL injection vérifiée
- [ ] Protection contre XSS vérifiée
- [ ] Logs de sécurité appropriés (sans données sensibles)

## 📸 Screenshots / Logs

<!-- Si applicable, ajoutez des captures d'écran ou logs -->

## 💥 Impact

- [ ] Breaking change (nécessite migration ou communication)
- [ ] Modification de base de données (migration EF requise)
- [ ] Modification de configuration (appsettings.json)
- [ ] Impact sur les performances (positif/négatif)
- [ ] Changement d'API (endpoint modifié/supprimé)
- [ ] Modification des dépendances (NuGet packages)

### Description de l'impact

<!-- Détaillez l'impact si applicable -->

## 📚 Documentation

- [ ] README.md mis à jour
- [ ] Documentation technique mise à jour
- [ ] XML comments ajoutés/mis à jour
- [ ] CHANGELOG.md mis à jour
- [ ] Migration guide créé (si breaking change)

## 👥 Reviewers

<!-- Mentionnez les reviewers spécifiques si nécessaire -->

**Requis** :
- [ ] Code review technique
- [ ] Security review (si changement sensible)

**Mentionner** :
- @security-team (si changement sécurité/données de santé)
- @devops-team (si changement infrastructure/pipeline)
- @dpo (si changement RGPD)

## 📊 Métriques

**Taille du changement** :
- Fichiers modifiés :
- Lignes ajoutées :
- Lignes supprimées :

**Complexité** : <!-- Basse / Moyenne / Haute -->

## 🧪 Résultats des checks automatiques

<!-- Ces checks doivent passer avant merge -->

- [ ] ✅ Build réussi
- [ ] ✅ Tests unitaires passent
- [ ] ✅ SonarCloud - Aucun bug/vulnérabilité
- [ ] ✅ Gitleaks - Aucun secret détecté
- [ ] ✅ Code coverage >= 80%
- [ ] ✅ dotnet format - Code formaté

## 📝 Notes additionnelles

<!-- Informations supplémentaires pour les reviewers -->

### Points d'attention

-
-

### Dépendances

<!-- Cette PR dépend de... -->

### Prochaines étapes

<!-- Travail à faire après ce PR -->

---

## ✅ Checklist finale (avant d'envoyer en review)

**Auteur** :
- [ ] J'ai testé localement tous les scénarios
- [ ] J'ai relu mon propre code (auto-review)
- [ ] J'ai vérifié qu'aucun fichier non pertinent n'est inclus
- [ ] J'ai mis à jour la documentation pertinente
- [ ] J'ai ajouté des tests pour mes changements
- [ ] Ma branche est à jour avec la branche cible
- [ ] Les commits suivent la convention (Conventional Commits)
- [ ] J'ai supprimé les `console.log` / code de debug

**Conformité HDS** :
- [ ] Aucune donnée de santé en clair
- [ ] Audit trail implémenté si nécessaire
- [ ] Validation RGPD OK

---

**Merci pour votre contribution à MedSecure ! 🏥**
