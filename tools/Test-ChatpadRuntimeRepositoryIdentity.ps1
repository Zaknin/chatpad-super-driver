[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CurrentReadinessImplementationCommit,
    [Parameter(Mandatory)]
    [string]$CurrentReadinessFinalizationCommit,
    [string]$ApprovedReadinessBranch = 'feature/runtime-bringup-stop-linkage-final-remediation',
    [string]$ApprovedRepositoryRoot = 'C:\Dev\chatpad-super-driver'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

Test-ChatpadCurrentRepositoryIdentity `
    -CurrentReadinessImplementationCommit $CurrentReadinessImplementationCommit `
    -CurrentReadinessFinalizationCommit $CurrentReadinessFinalizationCommit `
    -ApprovedBranch $ApprovedReadinessBranch `
    -ApprovedRepositoryRoot $ApprovedRepositoryRoot |
    ConvertTo-Json -Depth 12
