<#
.SYNOPSIS
    Converts a KQL query file into a KustoHawk-compatible JSON block.

.DESCRIPTION
    Reads a KQL query from a text file, applies KustoHawk placeholder conventions for Device or
    Identity queries, converts the query to a JSON-safe one-liner, and prints a ready-to-paste
    JSON block for DeviceQueries.json or IdentityQueries.json.

.PARAMETER QueryPath
    Path to the text file containing the KQL query tested in Advanced Hunting.

.PARAMETER QueryType
    Query family to prepare for the project. Supported values are Device and Identity.

.PARAMETER Name
    Human-readable query name that will be used in the final JSON block.

.PARAMETER Source
    Source URL or reference for the query.

.PARAMETER OutputMode
    Controls the output:
    - JsonBlock: prints only the final JSON block
    - QueryOnly: prints the normalized query and one-liner
    - Both: prints everything

.PARAMETER Help
    Displays usage, arguments, and examples.

.EXAMPLE
    .\Scripts\UIQueryToJSONFormat.ps1 `
      -QueryPath .\my-device-query.txt `
      -QueryType Device `
      -Name "Tampering attempts" `
      -Source "https://example.com/source"

    Converts a device query file into a normalized KustoHawk JSON block.

.EXAMPLE
    .\Scripts\UIQueryToJSONFormat.ps1 `
      -QueryPath .\my-identity-query.txt `
      -QueryType Identity `
      -Name "Successful sign-ins" `
      -Source "https://example.com/source" `
      -OutputMode JsonBlock

    Prints only the final JSON block for an identity query.

.EXAMPLE
    pwsh UIQueryToJSONFormat.ps1 -QueryPath ../Query/Test.txt -QueryType Device  -Name "Tampering attempts"  -Source "https://example.com/source"

    WSL test command example 

.EXAMPLE
    .\Scripts\UIQueryToJSONFormat.ps1 -h

    Displays inline help with arguments and examples.

#>

param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Convert')][string]$QueryPath,
    [Parameter(Mandatory = $true, ParameterSetName = 'Convert')][ValidateSet('Device', 'Identity')][string]$QueryType,
    [Parameter(Mandatory = $true, ParameterSetName = 'Convert')][string]$Name,
    [Parameter(Mandatory = $true, ParameterSetName = 'Convert')][string]$Source,
    [Parameter(Mandatory = $false, ParameterSetName = 'Convert')][ValidateSet('JsonBlock', 'QueryOnly', 'Both')][string]$OutputMode = 'Both',
    [Parameter(Mandatory = $true, ParameterSetName = 'Help')][Alias('h')][switch]$Help
)

$ErrorActionPreference = 'Stop'

function Write-Section {
    param (
        [string]$Title,
        [ConsoleColor]$Color = [ConsoleColor]::Cyan
    )

    $line = ('=' * 78)
    Write-Host ''
    Write-Host $line -ForegroundColor DarkGray
    Write-Host (" {0}" -f $Title) -ForegroundColor $Color
    Write-Host $line -ForegroundColor DarkGray
}

function Write-SubSection {
    param (
        [string]$Title,
        [ConsoleColor]$Color = [ConsoleColor]::Yellow
    )

    $line = ('-' * 56)
    Write-Host ''
    Write-Host $line -ForegroundColor DarkGray
    Write-Host (" {0}" -f $Title) -ForegroundColor $Color
    Write-Host $line -ForegroundColor DarkGray
}

function Write-ContentBlock {
    param (
        [string]$Content
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return
    }

    Write-Host $Content
}

function Write-KeyValueLine {
    param (
        [string]$Label,
        [string]$Value,
        [ConsoleColor]$LabelColor = [ConsoleColor]::Green,
        [ConsoleColor]$ValueColor = [ConsoleColor]::White
    )

    Write-Host ("{0}: " -f $Label) -ForegroundColor $LabelColor -NoNewline
    Write-Host $Value -ForegroundColor $ValueColor
}

function Get-InputQuery {
    param (
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        throw "Query file '$Path' was not found."
    }

    $rawQuery = Get-Content -Raw -Path $Path
    if ([string]::IsNullOrWhiteSpace($rawQuery)) {
        throw "Query file '$Path' is empty."
    }

    return $rawQuery.Trim()
}

function Get-TargetQueryFile {
    param (
        [string]$Type
    )

    switch ($Type) {
        'Device' { return 'Resources/DeviceQueries.json' }
        'Identity' { return 'Resources/IdentityQueries.json' }
        default { throw "Unsupported QueryType '$Type'." }
    }
}

function Ensure-VariableHeader {
    param (
        [string]$Query,
        [string]$HeaderLine
    )

    if ($Query -match [regex]::Escape($HeaderLine)) {
        return $Query
    }

    return "$HeaderLine`r`n$Query"
}

function Replace-FirstAgoLiteralWithTimeFrame {
    param (
        [string]$Query
    )

    $pattern = 'ago\((?!TimeFrame\b|\{TimeFrame\})[0-9]+\s*[dhm]\)'
    $agoMatches = [regex]::Matches($Query, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($agoMatches.Count -eq 0) {
        return [PSCustomObject]@{
            Query    = $Query
            Warnings = @()
        }
    }

    $firstMatch = $agoMatches[0]
    $updatedQuery = $Query.Substring(0, $firstMatch.Index) + 'ago(TimeFrame)' + $Query.Substring($firstMatch.Index + $firstMatch.Length)
    $warnings = @()
    if ($agoMatches.Count -gt 1) {
        $warnings += 'Multiple hardcoded ago() literals were found. Only the first one was converted to ago(TimeFrame); review the remaining time filters manually.'
    }

    return [PSCustomObject]@{
        Query    = $updatedQuery
        Warnings = $warnings
    }
}

function Normalize-DeviceQuery {
    param (
        [string]$Query
    )

    $warnings = @()
    $normalized = $Query

    $normalized = [regex]::Replace($normalized, "DeviceId\s*(==|=~)\s*['""][^'""]+['""]", 'DeviceId =~ Device')
    $normalized = Ensure-VariableHeader -Query $normalized -HeaderLine "let Device = '{DeviceId}';"

    $timeNormalization = Replace-FirstAgoLiteralWithTimeFrame -Query $normalized
    $normalized = $timeNormalization.Query
    $warnings += $timeNormalization.Warnings

    if ($normalized -match 'ago\(TimeFrame\)' -and $normalized -notmatch 'let TimeFrame = \{TimeFrame\};') {
        $normalized = Ensure-VariableHeader -Query $normalized -HeaderLine 'let TimeFrame = {TimeFrame};'
    }

    if ($Query -match "DeviceId\s*(==|=~)\s*['""][^'""]+['""]" -and $normalized -notmatch 'DeviceId =~ Device') {
        $warnings += 'A hardcoded DeviceId may still be present. Review the device filter manually.'
    }

    return [PSCustomObject]@{
        Query    = $normalized
        Warnings = $warnings
    }
}

function Normalize-IdentityQuery {
    param (
        [string]$Query
    )

    $warnings = @()
    $normalized = $Query
    $identityFields = @(
        'UserPrincipalName',
        'AccountUpn',
        'RawEventData\.UserId',
        'Caller',
        'InitiatedByUserPrincipalName',
        'Actor'
    )

    foreach ($field in $identityFields) {
        $replacement = switch ($field) {
            'AccountUpn' { 'AccountUpn =~ Upn' }
            'RawEventData\.UserId' { 'RawEventData.UserId =~ Upn' }
            'Caller' { 'Caller =~ Upn' }
            'InitiatedByUserPrincipalName' { 'InitiatedByUserPrincipalName =~ Upn' }
            'Actor' { 'Actor =~ Upn' }
            default { 'UserPrincipalName =~ Upn' }
        }

        $normalized = [regex]::Replace($normalized, "$field\s*(==|=~)\s*['""][^'""]+['""]", $replacement)
    }

    $normalized = Ensure-VariableHeader -Query $normalized -HeaderLine "let Upn = '{UserPrincipalName}';"

    $timeNormalization = Replace-FirstAgoLiteralWithTimeFrame -Query $normalized
    $normalized = $timeNormalization.Query
    $warnings += $timeNormalization.Warnings

    if ($normalized -match 'ago\(TimeFrame\)' -and $normalized -notmatch 'let TimeFrame = \{TimeFrame\};') {
        $normalized = Ensure-VariableHeader -Query $normalized -HeaderLine 'let TimeFrame = {TimeFrame};'
    }

    if ($Query -match "UserPrincipalName\s*(==|=~)\s*['""][^'""]+['""]|AccountUpn\s*(==|=~)\s*['""][^'""]+['""]|RawEventData\.UserId\s*(==|=~)\s*['""][^'""]+['""]|Caller\s*(==|=~)\s*['""][^'""]+['""]") {
        if ($normalized -notmatch 'Upn') {
            $warnings += 'A hardcoded identity filter may still be present. Review the user filter manually.'
        }
    }

    return [PSCustomObject]@{
        Query    = $normalized
        Warnings = $warnings
    }
}

function Convert-QueryToProjectOneliner {
    param (
        [string]$Query
    )

    $normalizedNewlines = $Query -replace "`r?`n", "`r`n"
    $jsonWrapper = [PSCustomObject]@{ Query = $normalizedNewlines } | ConvertTo-Json -Compress
    if ($jsonWrapper -match '^\{"Query":"(.*)"\}$') {
        return $matches[1]
    }

    throw 'Failed to convert the query to a JSON-safe one-liner.'
}

function New-KustoHawkQueryJsonBlock {
    param (
        [string]$QueryName,
        [string]$NormalizedQuery,
        [string]$QuerySource
    )

    $payload = [ordered]@{
        Name        = $QueryName
        Query       = ($NormalizedQuery -replace "`r?`n", "`r`n")
        Source      = $QuerySource
        ResultCount = 0
    }

    $json = $payload | ConvertTo-Json
    return "$json,"
}

if ($Help) {
    Get-Help $PSCommandPath -Detailed #-Full or -Examples
    exit 0
}

$inputQuery = Get-InputQuery -Path $QueryPath
$targetFile = Get-TargetQueryFile -Type $QueryType

$normalizationResult = switch ($QueryType) {
    'Device' { Normalize-DeviceQuery -Query $inputQuery }
    'Identity' { Normalize-IdentityQuery -Query $inputQuery }
}

$normalizedQuery = $normalizationResult.Query.Trim()
$queryOneliner = Convert-QueryToProjectOneliner -Query $normalizedQuery
$jsonBlock = New-KustoHawkQueryJsonBlock -QueryName $Name -NormalizedQuery $normalizedQuery -QuerySource $Source

Write-Section -Title 'KustoHawk Query Preparation'
Write-KeyValueLine -Label 'Target file' -Value $targetFile
Write-KeyValueLine -Label 'Query type' -Value $QueryType
Write-KeyValueLine -Label 'Query name' -Value $Name
Write-KeyValueLine -Label 'Source' -Value $Source -ValueColor Cyan

if ($normalizationResult.Warnings.Count -gt 0) {
    Write-SubSection -Title 'Warnings' -Color DarkYellow
    foreach ($warning in $normalizationResult.Warnings) {
        Write-Warning $warning
    }
}

switch ($OutputMode) {
    'QueryOnly' {
        Write-SubSection -Title 'Normalized Query' -Color Yellow
        Write-ContentBlock -Content $normalizedQuery
        Write-SubSection -Title 'One-Liner Query' -Color Yellow
        Write-ContentBlock -Content $queryOneliner
    }
    'JsonBlock' {
        Write-SubSection -Title 'JSON Block' -Color Magenta
        Write-ContentBlock -Content $jsonBlock
    }
    default {
        Write-SubSection -Title 'Input Query' -Color Blue
        Write-ContentBlock -Content $inputQuery
        Write-SubSection -Title 'Normalized Query' -Color Yellow
        Write-ContentBlock -Content $normalizedQuery
        Write-SubSection -Title 'One-Liner Query' -Color Yellow
        Write-ContentBlock -Content $queryOneliner
        Write-SubSection -Title 'JSON Block' -Color Magenta
        Write-ContentBlock -Content $jsonBlock
    }
}
