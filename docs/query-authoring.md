# KustoHawk: ecriture d'une nouvelle query

## Resume

Ce guide explique comment partir d'une requete KQL testee dans Advanced Hunting pour creer une nouvelle entree compatible avec KustoHawk.

Le workflow recommande par le projet est :

1. tester la requete dans Advanced Hunting
2. la sauvegarder dans un fichier texte
3. utiliser [UIQueryToJSONFormat.ps1](/home/hugo/codex-gpt/KustoHawk/Scripts/UIQueryToJSONFormat.ps1)
4. coller le bloc JSON genere dans le bon fichier de `Resources/`

## 1. Les 4 cles JSON

Chaque entree KustoHawk suit ce format :

```json
{
  "Name": "Tampering attempts",
  "Query": "let Device = \u0027{DeviceId}\u0027;\r\nlet TimeFrame = {TimeFrame};\r\nDeviceEvents\r\n| where Timestamp \u003e ago(TimeFrame)\r\n| where DeviceId =~ Device\r\n| where ActionType == \u0027TamperingAttempt\u0027",
  "Source": "https://example.com/source",
  "ResultCount": 0
},
```

Role de chaque cle :

- `Name` : nom lisible de la detection ou du triage
- `Query` : requete KQL stockee sous forme de chaine JSON sur une seule ligne
- `Source` : origine de la requete, article, repo ou reference
- `ResultCount` : initialise a `0` lors de la creation

## 2. Regles d'une KQL valide pour le projet

Une query KustoHawk doit respecter les conventions suivantes :

- etre testee dans Advanced Hunting avant ajout au projet
- utiliser les placeholders du projet et non des valeurs hardcodees
- rester generique et reutilisable
- conserver une fenetre temporelle parametrable
- cibler clairement un use case `device` ou `identity`

### Placeholders attendus

- `Device` :
  - `let Device = '{DeviceId}';`
  - `let TimeFrame = {TimeFrame};`
- `Identity` :
  - `let Upn = '{UserPrincipalName}';`
  - `let TimeFrame = {TimeFrame};`

### Filtres recommandés

Exemples courants cote device :

- `DeviceId =~ Device`

Exemples courants cote identity :

- `UserPrincipalName =~ Upn`
- `AccountUpn =~ Upn`
- `RawEventData.UserId =~ Upn`
- `Caller =~ Upn`

### Regles importantes

- ne pas hardcoder un `DeviceId`
- ne pas hardcoder un UPN utilisateur
- ne pas figer une fenetre de temps si la requete est censee etre reutilisable
- si la requete depend de `externaldata(...)`, documenter cette dependance
- si la requete utilise plusieurs fenetres temporelles, verifier manuellement la normalisation

## 3. Choisir le bon fichier

Ajouter la query dans :

- [DeviceQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/DeviceQueries.json) pour les tables device et endpoint
- [IdentityQueries.json](/home/hugo/codex-gpt/KustoHawk/Resources/IdentityQueries.json) pour les tables identity, Entra, Azure, Exchange ou Cloud App

Regle pratique :

- si la query pivote autour de `DeviceId`, elle est presque toujours `Device`
- si elle pivote autour d'un utilisateur, d'un UPN ou d'un audit cloud, elle est presque toujours `Identity`

## 4. Utiliser le script officiel

Le script [UIQueryToJSONFormat.ps1](/home/hugo/codex-gpt/KustoHawk/Scripts/UIQueryToJSONFormat.ps1) est maintenant le workflow officiel de preparation des nouvelles queries.

### Entree attendue

Une requete KQL dans un fichier texte, par exemple `my-query.txt`.

### Exemple device

```powershell
.\Scripts\UIQueryToJSONFormat.ps1 `
  -QueryPath .\my-device-query.txt `
  -QueryType Device `
  -Name "Tampering attempts" `
  -Source "https://github.com/Bert-JanP/Hunting-Queries-Detection-Rules/blob/main/DFIR/Defender%20For%20Endpoint/MDE%20-%20ListMaliciousActivities.md"
```

### Exemple identity

```powershell
.\Scripts\UIQueryToJSONFormat.ps1 `
  -QueryPath .\my-identity-query.txt `
  -QueryType Identity `
  -Name "User risk events" `
  -Source "https://github.com/Bert-JanP/Hunting-Queries-Detection-Rules/blob/main/Azure%20Active%20Directory/PotentialAiTMPhishing.md"
```

### Ce que retourne le script

- le fichier cible recommande
- la query normalisee avec placeholders
- la version oneliner
- le bloc JSON final pret a coller

## 5. Procedure manuelle de secours

Si une requete est trop complexe pour etre parfaitement normalisee automatiquement :

1. tester la requete dans Advanced Hunting
2. remplacer manuellement les valeurs specifiques par :
   - `{DeviceId}`
   - `{UserPrincipalName}`
   - `{TimeFrame}`
3. ajouter la variable `let Device` ou `let Upn`
4. ajouter `let TimeFrame = {TimeFrame};` si necessaire
5. lancer [UIQueryToJSONFormat.ps1](/home/hugo/codex-gpt/KustoHawk/Scripts/UIQueryToJSONFormat.ps1)
6. verifier le bloc JSON final

## 6. Checklist avant pull request

- la query est testee dans Advanced Hunting
- le type `Device` ou `Identity` est correct
- `Name` est clair
- `Source` est renseignee
- `ResultCount` est a `0`
- les placeholders du projet sont bien utilises
- le JSON final est valide
- toute dependance a une table ou une source externe est comprise
