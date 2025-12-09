$Query = "let Upn = '{UserPrincipalName}';
let TimeFrame = {TimeFrame};
BehaviorEntities
| where TimeGenerated >ago(TimeFrame)
| where AccountUpn =~ Upn
| join kind=inner (BehaviorInfo) on BehaviorId
| project-reorder TimeGenerated, AccountUpn, Description, AttackTechniques"
$Output = $Query -replace '\r','\r' -replace '\n','\n'
Write-Output $Output