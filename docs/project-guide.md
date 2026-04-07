# KustoHawk: guide du projet

## Résumé

Ce document explique comment KustoHawk est structuré, comment il fonctionne de bout en bout, comment le lancer selon les paramètres disponibles, et comment contribuer en enrichissant les jeux de requêtes.

L'objectif est double :

- comprendre rapidement l'architecture et le flux d'exécution
- disposer d'une référence pratique pour l'utiliser et l'améliorer

## 1. Vue d'ensemble

KustoHawk est un outil de triage d'incident pour Microsoft Defender XDR et Microsoft Sentinel. Son point d'entrée est le script PowerShell [KustoHawk.ps1](/home/hugo/codex-gpt/KustoHawk/KustoHawk.ps1), qui se connecte à Microsoft Graph, exécute des requêtes KQL prédéfinies, puis présente les résultats :

- dans le terminal
- en CSV si `-Export` est activé
- en HTML dans le dossier `Reports/`

Le script peut investiguer :

- un device via `-DeviceId`
- une identité via `-UserPrincipalName`
- les deux dans une même exécution

Le projet repose sur deux idées simples :

- la logique applicative est centralisée dans un seul script
- les requêtes sont externalisées dans des fichiers JSON modifiables

## 2. Structure du dépôt

Le dépôt est volontairement plat. La logique applicative est concentrée à la racine, et les dossiers servent surtout de support.

### Racine

- [KustoHawk.ps1](/home/hugo/codex-gpt/KustoHawk/KustoHawk.ps1) : script principal, cœur du projet
- [README.md](/home/hugo/codex-gpt/KustoHawk/README.md) : documentation courte d'entrée
- [LICENSE](/home/hugo/codex-gpt/KustoHawk/LICENSE) : licence du projet

### Dossiers principaux

- [Resources](/home/hugo/codex-gpt/KustoHawk/Resources) : configuration et catalogue de requêtes
- [Scripts](/home/hugo/codex-gpt/KustoHawk/Scripts) : scripts utilitaires autour du projet
- [Images](/home/hugo/codex-gpt/KustoHawk/Images) : logos, captures et schémas utilisés dans la documentation et les rapports
- [docs](/home/hugo/codex-gpt/KustoHawk/docs) : documentation complémentaire du projet

### Détail par dossier

#### `Resources/`

Ce dossier contient le contenu métier principal consommé par le script :

- [AuthenticationTiers.yaml](/home/hugo/codex-gpt/KustoHawk/Resources/AuthenticationTiers.yaml) : définition des tiers d'authentification et des permissions Graph attendues
- [DeviceQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/DeviceQueries.json) : catalogue des requêtes de triage orientées device
- [IdentityQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/IdentityQueries.json) : catalogue des requêtes orientées identity

#### `Scripts/`

Ce dossier contient des helpers de maintenance :

- [CleanForCommit.ps1](/home/hugo/codex-gpt/KustoHawk/Scripts/CleanForCommit.ps1) : nettoyage avant commit
- [UIQueryToJSONFormat.ps1](/home/hugo/codex-gpt/KustoHawk/Scripts/UIQueryToJSONFormat.ps1) : aide pour transformer une requête KQL en chaîne JSON utilisable par le projet

#### `Images/`

Assets visuels du dépôt :

- logos
- captures de rendu HTML
- schéma `.drawio`

## 3. Architecture interne de `KustoHawk.ps1`

Le script est monolithique, mais il est organisé par responsabilités successives.

### 3.1 Paramètres et bootstrap

Le script expose ses paramètres publics au début du fichier :

- `-DeviceId`
- `-UserPrincipalName` et l'alias `-upn`
- `-AuthenticationMethod`
- `-AuthenticationTier`
- `-TimeFrame`
- `-VerboseOutput`
- `-Export`
- `-IncludeSampleSet`
- `-CertificateThumbprint`

Il définit aussi une configuration locale pour l'authentification service principal :

- `$AppID`
- `$TenantID`
- `$Secret`
- `$DefaultCertificateThumbprint`

### 3.2 Gestion des dépendances et des tiers

Le premier bloc fonctionnel prépare l'environnement :

- `Check-InstalledGraphModules` : vérifie et importe `Microsoft.Graph.Security`, avec tentative d'installation pour l'utilisateur courant
- `Get-TierRoles` : parser YAML de secours
- `Get-AuthenticationTierConfig` : charge un tier depuis `AuthenticationTiers.yaml`
- `Get-EffectiveTierScopes` : calcule les permissions réellement nécessaires
- `Test-AuthMethodsScopeEnabled` : indique si la récupération des méthodes MFA est autorisée

### 3.3 Connexion à Microsoft Graph

Le bloc d'authentification couvre trois modes :

- `Connect-GraphAPI-User`
- `Connect-GraphAPI-ServicePrincipalSecret`
- `Connect-GraphAPI-ServicePrincipalCertificate`
- `Connect-GraphAPI` : routeur principal
- `Resolve-EffectiveTier` : vérifie les permissions réellement disponibles et peut abaisser le tier demandé

### 3.4 Validation des entrées

`ValidateInputParameters` valide les entrées utilisateur :

- `DeviceId` doit être une chaîne hexadécimale de 40 caractères
- `UserPrincipalName` doit correspondre à un format `user@domaine`

### 3.5 Exécution des requêtes KQL

Le moteur de requêtes repose surtout sur :

- `RunKQLQuery` : exécute une requête individuelle via `Start-MgSecurityHuntingQuery`
- `RunQueriesFromFile` : charge un fichier JSON, remplace les placeholders, exécute chaque requête, met à jour `ResultCount`, puis réécrit le JSON

Point important : après une exécution, `DeviceQueries.json` et `IdentityQueries.json` sont modifiés par le script pour persister les nouveaux `ResultCount`.

### 3.6 Enrichissement de contexte

Deux fonctions ajoutent de la vue d'ensemble à l'investigation :

- `Get-EntityInfo` : collecte des informations synthétiques sur le device et/ou le compte
- `GetAlertsForEntity` : récupère les alertes des 30 derniers jours liées à l'entité investiguée

Pour l'identité, `Get-EntityInfo` tente aussi de récupérer les méthodes d'authentification si le tier sélectionné permet le scope `UserAuthenticationMethod.Read.All`.

### 3.7 Rendu console et rapports HTML

Le reste du script est dédié à la restitution :

- `ConvertTo-WrappedConsoleLines`
- `Write-ConsoleDetailsTable`
- `GenerateQueryReport`
- `GenerateMainReportPage`
- `GetLogoBase64`
- `GetReportFooterHtml`

Le résultat final est un rapport HTML principal plus une page détaillée par type d'entité.

## 4. Flux d'exécution de bout en bout

Le flux réel du script est le suivant :

1. affichage de la bannière ASCII et de la version
2. vérification qu'au moins `-DeviceId` ou `-UserPrincipalName` est fourni
3. activation éventuelle du mode verbeux
4. vérification/import du module `Microsoft.Graph.Security`
5. chargement du tier demandé depuis [AuthenticationTiers.yaml](/home/hugo/codex-gpt/KustoHawk/Resources/AuthenticationTiers.yaml)
6. validation des paramètres d'entrée
7. connexion à Microsoft Graph selon `-AuthenticationMethod`
8. vérification des permissions effectives et downgrade automatique du tier si nécessaire
9. collecte des informations d'entité via `Get-EntityInfo`
10. si `DeviceId` est présent :
    - chargement de [DeviceQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/DeviceQueries.json)
    - exécution de toutes les requêtes device
    - génération du rapport HTML device
11. si `UserPrincipalName` est présent :
    - chargement de [IdentityQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/IdentityQueries.json)
    - exécution de toutes les requêtes identity
    - génération du rapport HTML identity
12. récupération des alertes liées à l'entité
13. génération de la page HTML principale dans `Reports/index.html`

### Schéma synthétique

```text
Entrées utilisateur
  -> validation locale
  -> chargement du tier
  -> connexion Graph
  -> vérification des permissions effectives
  -> collecte d'EntityInfo
  -> exécution des requêtes DeviceQueries.json
  -> exécution des requêtes IdentityQueries.json
  -> collecte des alertes
  -> génération CSV optionnelle
  -> génération des rapports HTML
```

### Ce que fait exactement le moteur de requêtes

Pour chaque entrée JSON :

1. le script remplace les placeholders `{DeviceId}`, `{UserPrincipalName}` et `{TimeFrame}`
2. il appelle `Start-MgSecurityHuntingQuery`
3. il reconstruit une table PowerShell à partir des `AdditionalProperties`
4. il peut afficher la table dans le terminal si `-VerboseOutput` est activé
5. il exporte un CSV si `-Export` est activé et si le résultat n'est pas vide
6. il conserve jusqu'à 10 lignes d'échantillon si `-IncludeSampleSet` est activé
7. il met à jour `ResultCount` dans le JSON source

## 5. Configuration avant usage

### 5.1 Module PowerShell requis

Le script a besoin du module PowerShell suivant :

```powershell
Install-Module Microsoft.Graph.Security -Scope CurrentUser
```

Le script peut tenter de l'installer lui-même s'il n'est pas déjà présent.

### 5.2 Ce qu'il faut configurer dans le script

Si vous utilisez `ServicePrincipalSecret` ou `ServicePrincipalCertificate`, il faut remplacer les placeholders dans [KustoHawk.ps1](/home/hugo/codex-gpt/KustoHawk/KustoHawk.ps1) :

```powershell
$AppID = "<AppID>"
$TenantID = "<TentantID>"
$Secret = "<Secret>"
$DefaultCertificateThumbprint = ""
```

#### Mode `User`

- pas de secret applicatif à configurer dans le script
- la connexion interactive dépend des permissions réellement accordées au compte

#### Mode `ServicePrincipalSecret`

- renseigner `AppID`
- renseigner `TenantID`
- renseigner `Secret`

#### Mode `ServicePrincipalCertificate`

- renseigner `AppID`
- renseigner `TenantID`
- fournir `-CertificateThumbprint` ou configurer `$DefaultCertificateThumbprint`
- le certificat doit être présent dans :
  - `Cert:\CurrentUser\My`
  - ou `Cert:\LocalMachine\My`

### 5.3 Tiers d'authentification

Les tiers sont définis dans [AuthenticationTiers.yaml](/home/hugo/codex-gpt/KustoHawk/Resources/AuthenticationTiers.yaml).

État actuel du dépôt :

| Tier | Permissions |
| --- | --- |
| `Tier1` | `ThreatHunting.Read.All` |
| `Tier2` | `ThreatHunting.Read.All`, `UserAuthenticationMethod.Read.All` |
| `Tier3` | `ThreatHunting.Read.All`, `UserAuthenticationMethod.Read.All` |

Points importants :

- `ThreatHunting.Read.All` est le minimum requis pour que le script soit utile
- si le tier demandé n'est pas atteignable, le script tente automatiquement un tier inférieur
- dans l'état actuel du dépôt, `Tier2` et `Tier3` portent les mêmes permissions

## 6. Paramètres et commandes de lancement

### 6.1 Signature générale

```powershell
.\KustoHawk.ps1 [[-DeviceId] <String>] [[-UserPrincipalName] <String>] [-VerboseOutput] [-Export]
        [-IncludeSampleSet] [[-TimeFrame] <String>] [[-CertificateThumbprint] <String>]
        [[-AuthenticationTier] <String>] [-AuthenticationMethod] <String>
```

### 6.2 Paramètres disponibles

| Paramètre | Alias | Rôle | Requis |
| --- | --- | --- | --- |
| `-DeviceId` | `-host` | device à investiguer | non, mais `DeviceId` ou `UserPrincipalName` est obligatoire |
| `-UserPrincipalName` | `-upn` | compte à investiguer | non, mais `DeviceId` ou `UserPrincipalName` est obligatoire |
| `-AuthenticationMethod` | aucun | `User`, `ServicePrincipalSecret`, `ServicePrincipalCertificate` | oui |
| `-AuthenticationTier` | aucun | `Tier1`, `Tier2`, `Tier3` | non, défaut `Tier1` |
| `-TimeFrame` | `-t` | fenêtre d'analyse KQL, par ex. `7d`, `14d`, `24h` | non, défaut `7d` |
| `-VerboseOutput` | `-v` | affiche les résultats détaillés dans le terminal | non |
| `-Export` | `-e` | exporte un CSV par requête non vide | non |
| `-IncludeSampleSet` | `-s` | ajoute jusqu'à 10 lignes d'exemple par requête dans les rapports HTML | non |
| `-CertificateThumbprint` | aucun | thumbprint du certificat pour l'auth cert | non |

### 6.3 Commandes minimales

#### Investigation device seule

```powershell
.\KustoHawk.ps1 `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca `
  -AuthenticationMethod User
```

#### Investigation identity seule

```powershell
.\KustoHawk.ps1 `
  -UserPrincipalName analyst@contoso.com `
  -AuthenticationMethod User
```

#### Investigation combinée

```powershell
.\KustoHawk.ps1 `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca `
  -UserPrincipalName analyst@contoso.com `
  -AuthenticationMethod User
```

### 6.4 Exemples par mode d'authentification

#### Authentification interactive utilisateur

```powershell
.\KustoHawk.ps1 `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca `
  -AuthenticationMethod User `
  -AuthenticationTier Tier1
```

#### Service principal avec secret

```powershell
.\KustoHawk.ps1 `
  -UserPrincipalName analyst@contoso.com `
  -AuthenticationMethod ServicePrincipalSecret `
  -AuthenticationTier Tier2
```

#### Service principal avec certificat

```powershell
.\KustoHawk.ps1 `
  -UserPrincipalName analyst@contoso.com `
  -AuthenticationMethod ServicePrincipalCertificate `
  -CertificateThumbprint ABCDEF1234567890ABCDEF1234567890ABCDEF12 `
  -AuthenticationTier Tier2
```

### 6.5 Exemples selon les options les plus utiles

#### Changer la période d'analyse

```powershell
.\KustoHawk.ps1 `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca `
  -AuthenticationMethod User `
  -TimeFrame 14d
```

#### Exporter les CSV

```powershell
.\KustoHawk.ps1 `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca `
  -AuthenticationMethod User `
  -Export
```

#### Activer les échantillons dans le rapport HTML

```powershell
.\KustoHawk.ps1 `
  -UserPrincipalName analyst@contoso.com `
  -AuthenticationMethod User `
  -IncludeSampleSet
```

#### Afficher les résultats détaillés dans le terminal

```powershell
.\KustoHawk.ps1 `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca `
  -AuthenticationMethod User `
  -VerboseOutput
```

#### Exemple complet

```powershell
.\KustoHawk.ps1 `
  -DeviceId 2694a7cc2225f3b66f7cf8b6388a78b1857fadca `
  -UserPrincipalName analyst@contoso.com `
  -AuthenticationMethod User `
  -AuthenticationTier Tier2 `
  -TimeFrame 14d `
  -Export `
  -IncludeSampleSet `
  -VerboseOutput
```

## 7. Sorties générées

### Sortie terminal

Le terminal affiche :

- la bannière et la version
- la validation des paramètres
- les informations d'entité
- le nombre de résultats par requête
- éventuellement les tables détaillées si `-VerboseOutput` est activé

### Exports CSV

Si `-Export` est activé :

- un fichier CSV est créé par requête non vide
- le nom du fichier est basé sur le champ `Name` de la requête
- les CSV sont écrits dans le répertoire courant

### Rapports HTML

Les rapports sont générés dans `Reports/` :

- `Reports/index.html` : page principale de synthèse
- `Reports/Device-ExecutedQueries-<DeviceId>.html` : page détaillée device si un `DeviceId` est fourni
- `Reports/Identity-ExecutedQueries-<UserPrincipalName>.html` : page détaillée identity si un `UserPrincipalName` est fourni

Ces pages contiennent notamment :

- une synthèse globale
- le nombre de requêtes avec hits
- les informations d'entité
- la liste d'alertes
- le détail des requêtes exécutées
- les échantillons de résultats si `-IncludeSampleSet` est activé

## 8. Focus sur `DeviceQueries.json`

### Rôle du fichier

[DeviceQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/DeviceQueries.json) contient le catalogue des requêtes de triage orientées poste de travail, serveur ou endpoint. Dans l'état actuel du dépôt, il contient 30 requêtes.

### Format d'une entrée

Chaque entrée suit ce contrat :

```json
{
  "Name": "Nom lisible de la requête",
  "Query": "Requête KQL sur une seule ligne avec placeholders",
  "Source": "URL ou référence d'origine",
  "ResultCount": 0
}
```

### Placeholders utilisés

Le script remplace automatiquement dans `Query` :

- `{DeviceId}`
- `{TimeFrame}`
- `{UserPrincipalName}`

Pour le fichier device, les placeholders centraux sont surtout `{DeviceId}` et `{TimeFrame}`.

### Familles de requêtes déjà présentes

Les requêtes du fichier couvrent plusieurs catégories :

- alertes liées au device
- exécution suspecte et scripting, par exemple AMSI, `mshta`, child processes de navigateurs ou d'`explorer.exe`
- persistance et registre, par exemple `Run`, `RunOnce`, `RunMRU`, tâches planifiées
- réseau, par exemple connexions entrantes, beaconing, SMB anormal, connexions LOLBin
- antivirus et sécurité endpoint, par exemple ASR, SmartScreen, tampering, Exploit Guard
- vulnérabilités, par exemple rapprochement avec les CVE exploitées par la CISA
- IOC et threat intel externes, par exemple Abuse.ch, IPsum, TweetFeed, named pipes suspects

### Tables les plus représentées

Les tables les plus fréquemment utilisées dans le dépôt actuel sont :

- `DeviceEvents`
- `DeviceNetworkEvents`
- `DeviceProcessEvents`
- `DeviceFileEvents`
- `DeviceRegistryEvents`
- plus ponctuellement `DeviceTvmSoftwareVulnerabilities` et `DeviceImageLoadEvents`

### Points d'attention

- certaines requêtes appellent des sources externes via `externaldata(...)`
- certaines dépendent de tables Defender for Endpoint avancées
- certaines sont coûteuses ou sensibles à la qualité de télémétrie disponible
- `ResultCount` est mis à jour par le script à chaque exécution

## 9. Focus sur `IdentityQueries.json`

### Rôle du fichier

[IdentityQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/IdentityQueries.json) contient le catalogue des requêtes orientées compte, identité Entra, activités cloud et messagerie. Dans l'état actuel du dépôt, il contient 22 requêtes.

### Format d'une entrée

Le schéma est identique à celui du fichier device :

```json
{
  "Name": "Nom lisible de la requête",
  "Query": "Requête KQL sur une seule ligne avec placeholders",
  "Source": "URL ou référence d'origine",
  "ResultCount": 0
}
```

### Placeholders utilisés

Pour le fichier identity, les placeholders centraux sont :

- `{UserPrincipalName}`
- `{TimeFrame}`

### Familles de requêtes déjà présentes

Les requêtes couvrent surtout :

- risques et sign-ins Entra ID
- anomalies UEBA et comportements anormaux
- audit et persistance cloud
- activités Azure
- abus ou reconnaissance Graph API
- activités Exchange Online et Cloud App Events

Exemples concrets de familles déjà présentes :

- user risk events
- sign-ins depuis un nouveau pays
- nouveaux user agents
- nouvelles applications Entra
- `AuditLogs` sur ajout de permissions Graph ou changements Conditional Access
- activité `AzureHound`
- collecte de mails et règles de boîte aux lettres

### Tables les plus représentées

Dans l'état actuel du dépôt, les tables les plus utilisées sont :

- `SigninLogs`
- `AuditLogs`
- `CloudAppEvents`
- `AzureActivity`
- plus ponctuellement `AADUserRiskEvents`, `Anomalies`, `BehaviorEntities`, `BehaviorInfo`, `GraphAPIAuditEvents`, `AADSignInEventsBeta`

### Points d'attention

- les résultats dépendent de la présence effective des journaux Entra, Azure, Defender for Cloud Apps et M365
- certaines détections supposent une rétention suffisante, souvent 90 jours pour les comparaisons historiques
- la récupération des méthodes d'authentification utilisateur n'est pas dans le JSON : elle est faite séparément par `Get-EntityInfo`

## 10. Comment contribuer

### Principe général

La contribution la plus naturelle consiste à enrichir [DeviceQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/DeviceQueries.json) ou [IdentityQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/IdentityQueries.json).

Le dépôt est conçu pour que les nouvelles détections passent principalement par l'ajout de requêtes plutôt que par une refonte du script principal.

### Contrat minimal d'une nouvelle requête

Chaque entrée doit contenir :

- `Name` : nom métier lisible
- `Query` : KQL en chaîne JSON sur une seule ligne
- `Source` : origine de la détection ou du contenu
- `ResultCount` : compteur de résultats, généralement initialisé à `0`

### Choisir le bon fichier

Ajouter la requête dans :

- `DeviceQueries.json` si la logique cible un device ou des tables endpoint
- `IdentityQueries.json` si la logique cible un compte, de l'audit cloud, Entra, Azure ou Exchange

### Utiliser les bons placeholders

Préférer les variables injectées par le script :

- `{DeviceId}`
- `{UserPrincipalName}`
- `{TimeFrame}`

Cela évite d'avoir des requêtes figées ou difficiles à réutiliser.

### Convertir une requête KQL au bon format

Le projet attend une requête stockée sur une seule ligne JSON. Deux options :

- utiliser [UIQueryToJSONFormat.ps1](/home/hugo/codex-gpt/KustoHawk/Scripts/UIQueryToJSONFormat.ps1)
- reprendre l'exemple déjà documenté dans le `README`

Exemple de transformation :

```powershell
$Query = "let Upn = '{UserPrincipalName}';
let TimeFrame = {TimeFrame};
AADUserRiskEvents
| where TimeGenerated > ago(TimeFrame)
| where UserPrincipalName =~ Upn
| summarize arg_max(TimeGenerated, *) by UserPrincipalName
| project TimeGenerated, UserPrincipalName, RiskState, RiskLevel, RiskDetail, RiskEventType"

$Output = $Query -replace '\r','\r' -replace '\n','\n'
Write-Output $Output
```

### Checklist de contribution

- choisir le bon fichier `DeviceQueries.json` ou `IdentityQueries.json`
- donner un `Name` compréhensible et stable
- utiliser les placeholders standards
- renseigner une `Source` exploitable
- initialiser `ResultCount` à `0`
- vérifier la syntaxe JSON
- tester la requête dans un tenant compatible
- documenter toute dépendance non évidente à une table ou à une source externe

## 11. Limites et points d'attention

- Le projet dépend fortement des permissions Graph et de la qualité des droits accordés au compte ou au service principal.
- L'absence de certaines tables ne bloque pas forcément le script, mais réduit la couverture de détection.
- Plusieurs requêtes utilisent `externaldata(...)` et dépendent donc de sources publiques externes.
- Le script est pratique à lire car centralisé, mais son caractère monolithique rend les évolutions plus délicates qu'un découpage modulaire.
- Les fichiers JSON sont modifiés par le script lui-même via la mise à jour de `ResultCount`. Cela peut produire des diffs Git après usage local.

## 12. Pour aller plus loin

Pour comprendre rapidement le projet, l'ordre de lecture recommandé est :

1. [README.md](/home/hugo/codex-gpt/KustoHawk/README.md)
2. [KustoHawk.ps1](/home/hugo/codex-gpt/KustoHawk/KustoHawk.ps1)
3. [AuthenticationTiers.yaml](/home/hugo/codex-gpt/KustoHawk/Resources/AuthenticationTiers.yaml)
4. [DeviceQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/DeviceQueries.json)
5. [IdentityQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/IdentityQueries.json)

Si l'objectif est de contribuer, commencer par les JSON est généralement le plus productif. Si l'objectif est de changer le comportement du pipeline, il faut ensuite se concentrer sur [KustoHawk.ps1](/home/hugo/codex-gpt/KustoHawk/KustoHawk.ps1).
