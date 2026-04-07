# KustoHawk en MSSP multi-tenant

## Résumé

Ce document décrit l'architecture recommandée pour utiliser KustoHawk dans un SOC MSSP à travers plusieurs tenants clients, avec une seule application Entra ID multi-tenant détenue par le MSSP, authentifiée par certificat, et un registre local des clients autorisés.

L'objectif est d'obtenir :

- un accès industrialisable sur plusieurs tenants clients
- un modèle d'authentification stable et non interactif
- une séparation claire des clients, des rapports et des niveaux de permissions

## 1. Architecture recommandée

### Choix cible

Le design recommandé est le suivant :

- une **application Entra ID multi-tenant unique** dans le tenant du MSSP
- une **authentification par certificat**
- un **bastion / runner SOC central** comme mode principal
- un **mode local analyste contrôlé** en second choix
- un **registre JSON des clients** pour piloter le tenant cible et les garde-fous

### Pourquoi ce design

Ce modèle est préférable à une connexion interactive analyste pour un MSSP parce qu'il :

- évite de dépendre d'une session utilisateur pour chaque exécution
- permet de standardiser les permissions et le consentement par client
- simplifie la rotation des credentials
- facilite la journalisation et l'isolation des sorties

### Ce que supporte maintenant le projet

Le script principal supporte désormais :

- `-ConfigPath` pour charger une configuration MSSP externe
- `-CustomerName` pour sélectionner un client depuis le registre
- `-CustomerTenantId` pour cibler explicitement un tenant
- `-AppClientId` et `-AppSecret` pour surcharger la configuration
- `-ReportRootPath` pour isoler les sorties
- un répertoire de sortie par client et par exécution
- un contrôle qui interdit `Tier2` si `allowAuthMethodsRead` est faux pour le client

Un wrapper d'exploitation est fourni :

- [Run-KustoHawkForCustomer.ps1](/home/hugo/codex-gpt/KustoHawk/Scripts/Run-KustoHawkForCustomer.ps1)

Un exemple de registre de clients est fourni :

- [CustomerTenants.sample.json](/home/hugo/codex-gpt/KustoHawk/Resources/CustomerTenants.sample.json)

Une note client-facing dédiée au consentement est fournie :

- [customer-consent-faq.md](/home/hugo/codex-gpt/KustoHawk/docs/customer-consent-faq.md)

## 2. Design d'accès et permissions

### Permissions minimales

Permission de base recommandée :

- `ThreatHunting.Read.All`

Permission optionnelle et sensible :

- `UserAuthenticationMethod.Read.All`

### Recommandation MSSP

- utiliser `Tier1` comme baseline MSSP
- n'activer `Tier2` que pour les clients qui approuvent explicitement la collecte des méthodes d'authentification
- conserver cette autorisation dans le registre client, pas uniquement dans la ligne de commande

### Ce que cela implique

- un client standard reste en `Tier1`
- un client autorisant la lecture des méthodes MFA peut être configuré en `Tier2`
- si un client a `allowAuthMethodsRead: false`, le script refuse un lancement en `Tier2`

## 3. Setup complet côté MSSP

### 3.1 Créer l'application Entra ID MSSP

Dans le tenant du MSSP :

1. Aller dans **Microsoft Entra ID** > **App registrations** > **New registration**
2. Choisir **Accounts in any organizational directory**
3. Créer l'application
4. Noter :
   - `Application (client) ID`
   - tenant propriétaire MSSP

### 3.2 Ajouter les permissions API

Ajouter les permissions Microsoft Graph nécessaires :

- `ThreatHunting.Read.All`
- `UserAuthenticationMethod.Read.All` seulement si vous supportez `Tier2`

Le consentement admin est requis pour ces permissions.

### 3.3 Configurer le certificat

Recommandations :

- certificat dédié à KustoHawk MSSP
- stockage du certificat privé sur le runner SOC ou dans un coffre de secrets
- rotation documentée
- pas de secret applicatif en production si vous pouvez l'éviter

### 3.4 Préparer l'environnement d'exécution

Sur le runner SOC ou le poste analyste :

```powershell
Install-Module Microsoft.Graph.Security -Scope CurrentUser
```

Déployer ensuite :

- le dépôt KustoHawk
- le certificat dans `Cert:\CurrentUser\My` ou `Cert:\LocalMachine\My`
- le fichier de configuration JSON MSSP

## 4. Setup complet côté client

### 4.1 Consentement admin

Chaque client doit approuver l'application MSSP dans son propre tenant.

Deux approches possibles :

- ouvrir le lien d'admin consent fourni par le MSSP
- ou faire le consentement depuis le portail Entra côté client

### 4.2 Validation après consentement

Pour chaque client :

- vérifier que le service principal de l'app existe dans le tenant client
- vérifier que les permissions attendues ont bien été accordées
- exécuter un test simple d'Advanced Hunting

### 4.3 Vérifier les prérequis fonctionnels

Le client doit disposer, selon les requêtes utilisées, des données suivantes :

- Advanced Hunting Defender XDR
- tables Entra / Audit / SigninLogs si triage identity
- éventuellement Microsoft Sentinel si le périmètre MSSP le prévoit

## 5. Registre des clients MSSP

### Format recommandé

Le registre fourni en exemple utilise cette structure :

```json
{
  "app": {
    "clientId": "11111111-1111-1111-1111-111111111111",
    "defaultCertificateThumbprint": "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    "defaultSecret": "",
    "reportRootPath": "Reports"
  },
  "customers": [
    {
      "name": "contoso",
      "tenantId": "22222222-2222-2222-2222-222222222222",
      "authenticationTier": "Tier1",
      "allowedModes": ["device", "identity", "both"],
      "allowAuthMethodsRead": false,
      "reportSubdirectory": "contoso",
      "notes": "Baseline MSSP customer"
    }
  ]
}
```

### Signification des champs

- `app.clientId` : application MSSP centralisée
- `app.defaultCertificateThumbprint` : certificat utilisé par défaut
- `app.defaultSecret` : uniquement pour les environnements qui utilisent encore un secret
- `app.reportRootPath` : racine de stockage des rapports
- `customers[].name` : identifiant humain du client
- `customers[].tenantId` : tenant cible
- `customers[].authenticationTier` : tier par défaut du client
- `customers[].allowedModes` : modes autorisés
- `customers[].allowAuthMethodsRead` : garde-fou Tier2
- `customers[].reportSubdirectory` : sous-répertoire dédié

## 6. Commandes d'exploitation

### Lancement direct avec le script principal

```powershell
.\KustoHawk.ps1 `
  -CustomerName contoso `
  -ConfigPath .\Resources\CustomerTenants.sample.json `
  -AuthenticationMethod ServicePrincipalCertificate `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca
```

### Lancement via le wrapper MSSP

```powershell
.\Scripts\Run-KustoHawkForCustomer.ps1 `
  -CustomerName contoso `
  -ConfigPath .\Resources\CustomerTenants.sample.json `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca
```

### Triage identity

```powershell
.\Scripts\Run-KustoHawkForCustomer.ps1 `
  -CustomerName fabrikam `
  -ConfigPath .\Resources\CustomerTenants.sample.json `
  -UserPrincipalName analyst@fabrikam.com `
  -AuthenticationTier Tier2
```

### Triage combiné

```powershell
.\Scripts\Run-KustoHawkForCustomer.ps1 `
  -CustomerName contoso `
  -ConfigPath .\Resources\CustomerTenants.sample.json `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca `
  -UserPrincipalName analyst@contoso.com `
  -Export `
  -IncludeSampleSet
```

## 7. Sorties et séparation des clients

Les sorties sont isolées par client et par exécution.

Format par défaut :

```text
Reports/<customer>/<timestamp>/
```

Ce dossier contient :

- les rapports HTML
- les CSV exportés

Ce design facilite :

- la séparation client
- la conservation de preuves
- la journalisation d'un run précis

## 8. Runbook d'onboarding client

Pour chaque nouveau client MSSP :

1. créer ou réutiliser l'app MSSP multi-tenant
2. faire approuver l'app par admin consent dans le tenant client
3. valider l'accès Advanced Hunting
4. créer l'entrée client dans le registre JSON
5. définir le tier autorisé
6. valider un run device et un run identity si le périmètre le prévoit

## 9. Recommandations sécurité

- privilégier le certificat au secret
- limiter `Tier2` aux clients qui l'acceptent
- centraliser l'exécution sur un bastion SOC
- contrôler l'usage local par les analystes
- journaliser chaque exécution hors de l'outil si nécessaire
- revoir régulièrement la liste des clients et les tiers autorisés

## 10. Limites

- l'outil reste un script PowerShell monolithique
- le registre client est aujourd'hui un fichier JSON local, pas une base de configuration centralisée
- la journalisation d'exécution complète n'est pas encore exportée dans un fichier dédié
- la valeur `ResultCount` continue d'être réécrite dans les fichiers JSON de requêtes lors des runs

## 11. Références officielles

- Microsoft Defender XDR partner context :
  https://learn.microsoft.com/defender-xdr/api-access#partner-context
- Multi-tenant app for Defender XDR APIs :
  https://learn.microsoft.com/defender-xdr/api-partner-access#create-the-multi-tenant-app
- Microsoft Graph permissions reference :
  https://learn.microsoft.com/graph/permissions-reference#all-permissions
- Multi-tenant applications in Entra ID :
  https://learn.microsoft.com/entra/identity-platform/howto-convert-app-to-be-multi-tenant
