# KustoHawk: note client sur le consentement de l'application

## Résumé

Ce document est destiné aux clients qui demandent :

- ce que fait l'application KustoHawk dans leur tenant
- quels sont les risques et l'impact d'accepter l'application
- quels sont les prérequis licences
- quels rôles sont nécessaires à chaque étape

L'objectif est de fournir une réponse claire, exploitable pendant l'onboarding, sans devoir relire toute la documentation technique du projet.

## 1. Ce que fait l'application

KustoHawk est un outil de triage SOC qui interroge les données de sécurité d'un tenant Microsoft pour :

- lancer des requêtes Advanced Hunting
- récupérer des informations de contexte sur un device ou un compte
- générer un rapport exploitable par un analyste SOC

Concrètement, l'outil peut :

- investiguer un device via son `DeviceId`
- investiguer un compte via son `UserPrincipalName`
- récupérer les alertes liées à l'entité investiguée
- produire des rapports HTML et CSV

L'application n'est pas conçue pour :

- modifier des politiques de sécurité
- créer, supprimer ou modifier des objets Entra ID
- prendre des actions de remédiation automatiques dans les postes, les emails ou les identités

Dans le projet actuel, l'usage prévu est **lecture seule**.

## 2. Quelles permissions l'application demande

### Permission minimale

Le niveau de base du projet correspond à :

- `ThreatHunting.Read.All`

Cette permission permet à l'application de lancer des requêtes de threat hunting et de lire les résultats.

### Permission optionnelle

Le niveau enrichi ajoute :

- `UserAuthenticationMethod.Read.All`

Cette permission permet de lire les méthodes d'authentification des utilisateurs dans le tenant.

### Ce que cela signifie en pratique

#### Avec `Tier1`

L'application peut lire les données de sécurité exposées via les tables Advanced Hunting que le tenant alimente, par exemple :

- événements devices
- événements réseau
- alertes
- journaux Entra / audit / messagerie selon les produits activés

#### Avec `Tier2`

En plus de `Tier1`, l'application peut aussi lire :

- l'inventaire des méthodes d'authentification d'un utilisateur
- par exemple téléphone, Microsoft Authenticator, FIDO2, Windows Hello for Business, Temporary Access Pass

## 3. Quels sont les risques et l'impact d'accepter l'application

### Risque principal

Le principal impact du consentement est de donner à l'application un **accès lecture** à des données de sécurité potentiellement sensibles du tenant.

Cela inclut, selon les produits activés et les permissions accordées :

- événements de sécurité endpoint
- données d'identité et de connexion
- journaux d'audit
- événements de messagerie et de cloud apps
- éventuellement les méthodes d'authentification utilisateur si `Tier2` est accepté

### Ce que le client doit comprendre avant d'accepter

Le client doit considérer que l'application pourra consulter :

- des informations de détection et d'investigation SOC
- des journaux d'activité de comptes
- des métadonnées de sécurité sur devices et utilisateurs

L'application ne doit pas être approuvée si :

- le client ne souhaite pas qu'un partenaire MSSP lise ces données
- le client ne comprend pas pourquoi ces permissions sont demandées
- le client ne souhaite pas autoriser la lecture des méthodes MFA dans le cadre `Tier2`

### Différence de sensibilité entre `Tier1` et `Tier2`

- `Tier1` : accès lecture aux données de hunting et aux résultats d'investigation
- `Tier2` : accès lecture supplémentaire aux méthodes d'authentification des utilisateurs

Pour un onboarding MSSP standard, `Tier1` est la baseline recommandée. `Tier2` doit être un choix explicite du client.

## 4. Ce que l'application ne fait pas

Dans son état actuel, le projet ne cherche pas à :

- écrire dans le tenant
- créer ou modifier des objets Entra
- changer des configurations Defender
- déclencher des actions automatiques de remédiation

Le client doit néanmoins vérifier les permissions demandées au moment du consentement et confirmer qu'elles correspondent bien à ce qui a été convenu contractuellement.

## 5. Prérequis licences Microsoft

### Réponse courte

Oui, il y a des prérequis fonctionnels côté licences et produits activés.

### Ce qu'il faut retenir

Microsoft indique qu'un accès Microsoft Defender XDR nécessite un tenant éligible et recommande généralement :

- `Microsoft 365 E5`
- `Microsoft 365 E5 Security`
- `A5`
- `A5 Security`
- ou une combinaison équivalente donnant accès aux services supportés

En pratique, pour KustoHawk, le vrai prérequis est double :

1. le client doit disposer de Microsoft Defender XDR / Advanced Hunting
2. les workloads utilisés par les requêtes doivent réellement être actifs dans le tenant

### Produits ou données souvent nécessaires

Selon les requêtes activées dans le projet :

- Microsoft Defender for Endpoint
- Microsoft Defender XDR Advanced Hunting
- journaux Entra ID comme `SigninLogs` et `AuditLogs`
- Microsoft Defender for Cloud Apps
- Microsoft Defender for Identity
- Microsoft Sentinel si le périmètre client inclut les données Sentinel

En conséquence :

- un client peut techniquement consentir à l'application
- mais ne pas obtenir de résultats complets si ses workloads ou ses licences ne couvrent pas les tables interrogées

## 6. Rôles nécessaires à chaque étape

### Étape 1 : créer l'application dans le tenant MSSP

Cette étape est côté MSSP, pas côté client.

Rôles typiquement nécessaires dans le tenant MSSP :

- `Application Administrator`
- `Cloud Application Administrator`
- ou un rôle plus privilégié si nécessaire

### Étape 2 : accorder le consentement admin dans le tenant client

Pour les permissions applicatives Microsoft Graph, le rôle le plus sûr à retenir est :

- `Privileged Role Administrator`

Point important :

- `Application Administrator` et `Cloud Application Administrator` peuvent gérer des applications
- mais pour le consentement de permissions **application** Microsoft Graph, Microsoft indique qu'un rôle plus privilégié est requis, typiquement `Privileged Role Administrator`

### Étape 3 : utiliser l'application en mode app-only

Une fois le consentement accordé :

- l'application agit avec les permissions consenties
- il n'y a pas de rôle utilisateur quotidien Defender requis pour l'analyste, car c'est l'identité applicative qui appelle l'API

La vraie condition côté client devient :

- le tenant doit avoir les produits et les données nécessaires
- les permissions demandées doivent avoir été approuvées

### Étape 4 : utilisation en mode utilisateur délégué

Si le projet est utilisé en authentification interactive `User` :

- l'utilisateur doit avoir les permissions API déléguées nécessaires
- et des rôles de lecture dans Defender XDR / Entra selon les données ciblées

Microsoft indique notamment, selon les scénarios, des rôles comme :

- `Security Reader`
- `Security Administrator`
- `Security Operator`
- `Global Reader`

Pour l'Advanced Hunting API en contexte utilisateur, Microsoft précise aussi :

- l'utilisateur doit avoir le rôle `View Data`
- et l'accès aux devices selon les device groups

### Étape 5 : activer ou utiliser les données dans le portail Defender

Pour simplement accéder aux fonctionnalités Defender XDR et Advanced Hunting dans le portail, Microsoft cite notamment :

- `Global Administrator`
- `Security Administrator`
- `Security Operator`
- `Global Reader`
- `Security Reader`

L'accès réel peut aussi dépendre :

- du RBAC Microsoft Defender for Endpoint
- de la configuration des device groups
- des permissions propres à Exchange / Cloud Apps / autres workloads

## 7. Réponse standard à donner au client

Tu peux utiliser la formulation suivante :

> L'application KustoHawk est utilisée par le MSSP pour lancer des requêtes de triage et d'investigation dans les données de sécurité Microsoft du tenant. En baseline, elle demande uniquement une permission de lecture de threat hunting (`ThreatHunting.Read.All`). En option, si validé explicitement, elle peut aussi lire l'inventaire des méthodes d'authentification utilisateur (`UserAuthenticationMethod.Read.All`). L'usage prévu est en lecture seule, pour produire des rapports d'investigation SOC. L'acceptation de l'application donne donc au MSSP un accès lecture à des données de sécurité potentiellement sensibles du tenant, sans but de modification de configuration ni d'action de remédiation automatique.

## 8. Références officielles Microsoft

- Grant admin consent:
  https://learn.microsoft.com/entra/identity/enterprise-apps/grant-admin-consent
- Overview of user and admin consent:
  https://learn.microsoft.com/entra/identity/enterprise-apps/user-admin-consent-overview
- Cloud Application Administrator:
  https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#cloud-application-administrator
- Application Administrator:
  https://learn.microsoft.com/entra/identity/role-based-access-control/permissions-reference#application-administrator
- Microsoft Graph permissions reference:
  https://learn.microsoft.com/graph/permissions-reference#all-permissions
- Microsoft Defender XDR Advanced hunting API:
  https://learn.microsoft.com/defender-xdr/api-advanced-hunting#permissions
- Advanced hunting access requirements:
  https://learn.microsoft.com/defender-xdr/advanced-hunting-overview#get-access
- Turn on Microsoft Defender XDR:
  https://learn.microsoft.com/defender-xdr/m365d-enable
