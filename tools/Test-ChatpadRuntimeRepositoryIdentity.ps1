[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ApprovedReadinessCommit,
    [string]$ApprovedReadinessBranch = 'feature/runtime-bringup-readiness-remediation',
    [string]$AcceptedBaselineCommit = 'f49b5cbe9e6bba423cfb59313dbdc9be92c785ca',
    [string]$ApprovedRepositoryRoot = 'C:\Dev\chatpad-super-driver'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

Test-ChatpadCurrentRepositoryIdentity `
    -ApprovedReadinessCommit $ApprovedReadinessCommit `
    -ApprovedReadinessBranch $ApprovedReadinessBranch `
    -AcceptedBaselineCommit $AcceptedBaselineCommit `
    -ApprovedRepositoryRoot $ApprovedRepositoryRoot |
    ConvertTo-Json -Depth 12
