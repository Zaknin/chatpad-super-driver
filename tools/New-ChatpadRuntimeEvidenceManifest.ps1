[CmdletBinding()]
param(
    [string]$EvidenceRoot = '<EVIDENCE_DIRECTORY>',
    [string]$SessionId = '<SESSION_ID>',
    [switch]$PlanOnly = $true,
    [switch]$ExecuteAuthorizedRuntimeStep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($ExecuteAuthorizedRuntimeStep) { throw 'Runtime evidence manifest generation for live sessions is not implemented in this preparation scaffold.' }
[pscustomobject]@{
    schema_version = 'chatpad-runtime-evidence-manifest-v1'
    session_id = $SessionId
    evidence_root = $EvidenceRoot
    result = 'PLANNED_NOT_EXECUTED'
    required_entry_fields = @('id','relative_path','size','sha256','state','producer','created_utc','session_id','result','dependencies')
    state_values = @('planned-not-executed','executed','skipped-by-authorization','blocked-by-prerequisite','failed','rolled-back','restored')
} | ConvertTo-Json -Depth 5
