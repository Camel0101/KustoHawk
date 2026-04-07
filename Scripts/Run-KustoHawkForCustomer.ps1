<#
.SYNOPSIS
    Wrapper for MSSP-style multi-tenant execution of KustoHawk.

.DESCRIPTION
    Resolves a customer entry from a JSON tenant registry and forwards the request to KustoHawk.ps1
    with the recommended ServicePrincipalCertificate mode.
#>

param (
    [Parameter(Mandatory = $true)][string]$CustomerName,
    [Parameter(Mandatory = $false)][string]$ConfigPath = ".\Resources\CustomerTenants.sample.json",
    [Parameter(Mandatory = $false)][string]$DeviceId,
    [Parameter(Mandatory = $false)][Alias('upn')][string]$UserPrincipalName,
    [Parameter(Mandatory = $false)][string]$TimeFrame = "7d",
    [Parameter(Mandatory = $false)][string]$AuthenticationMethod = "ServicePrincipalCertificate",
    [Parameter(Mandatory = $false)][ValidateSet("Tier1", "Tier2", "Tier3")][string]$AuthenticationTier,
    [Parameter(Mandatory = $false)][string]$CertificateThumbprint,
    [Parameter(Mandatory = $false)][switch]$VerboseOutput,
    [Parameter(Mandatory = $false)][switch]$Export,
    [Parameter(Mandatory = $false)][switch]$IncludeSampleSet,
    [Parameter(Mandatory = $false)][string]$ReportRootPath
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$entryScript = Join-Path -Path $projectRoot -ChildPath 'KustoHawk.ps1'

if (-not (Test-Path -Path $entryScript)) {
    throw "KustoHawk.ps1 was not found at '$entryScript'."
}

$forwardParams = @{
    CustomerName         = $CustomerName
    ConfigPath           = $ConfigPath
    AuthenticationMethod = $AuthenticationMethod
    TimeFrame            = $TimeFrame
}

if ($PSBoundParameters.ContainsKey('AuthenticationTier')) { $forwardParams.AuthenticationTier = $AuthenticationTier }
if ($PSBoundParameters.ContainsKey('CertificateThumbprint')) { $forwardParams.CertificateThumbprint = $CertificateThumbprint }
if ($PSBoundParameters.ContainsKey('DeviceId')) { $forwardParams.DeviceId = $DeviceId }
if ($PSBoundParameters.ContainsKey('UserPrincipalName')) { $forwardParams.UserPrincipalName = $UserPrincipalName }
if ($PSBoundParameters.ContainsKey('ReportRootPath')) { $forwardParams.ReportRootPath = $ReportRootPath }
if ($VerboseOutput) { $forwardParams.VerboseOutput = $true }
if ($Export) { $forwardParams.Export = $true }
if ($IncludeSampleSet) { $forwardParams.IncludeSampleSet = $true }

& $entryScript @forwardParams
