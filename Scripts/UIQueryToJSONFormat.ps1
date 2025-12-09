$Query = "let Upn = '{UserPrincipalName}';
let TimeFrame = {TimeFrame};
Anomalies
| where Entities has Upn or UserPrincipalName =~ Upn'"
$Output = $Query -replace '\r','\r' -replace '\n','\n'
Write-Output $Output