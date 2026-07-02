[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SessionId,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [switch]$PlanOnly = $true,
    [switch]$ExecuteAuthorizedRuntimeStep,
    [string]$TargetInstanceId,
    [string]$ApprovedOperationId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

if ($ExecuteAuthorizedRuntimeStep) {
    Assert-ChatpadPlanAuthorization -ExecuteAuthorizedRuntimeStep -EvidenceDirectory $EvidenceDirectory -TargetInstanceId $TargetInstanceId -ApprovedOperationId $ApprovedOperationId | Out-Null
    throw 'Evidence directory creation is reserved for the supervised runtime session.'
}
[pscustomobject]@{
    result = 'PLANNED_NOT_EXECUTED'
    session_id = $SessionId
    evidence_directory = $EvidenceDirectory
    required_checks = @('directory absent before session', 'session ID unique', 'path under approved evidence root', 'write test before mutation')
} | ConvertTo-Json -Depth 5
