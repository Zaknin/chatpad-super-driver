[CmdletBinding()]
param([switch]$AllowScaffoldingBranch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$identity = Assert-ChatpadAcceptedRepoIdentity -AllowScaffoldingBranch:$AllowScaffoldingBranch -RequireClean:$false
$root = Get-ChatpadRepoRoot
$debug = Get-ChatpadFileIdentity (Join-Path $root 'artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys')
$release = Get-ChatpadFileIdentity (Join-Path $root 'artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys')
[pscustomobject]@{
    schema_version = 'chatpad-runtime-repository-identity-v1'
    result = 'PASS'
    repository = $identity
    debug_binary = $debug
    release_binary = $release
    accepted_manifest = Get-ChatpadFileIdentity (Join-Path $root 'docs/evidence/runtime-instrumentation-implementation-manifest.json')
} | ConvertTo-Json -Depth 8
