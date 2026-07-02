[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidenceDocumentPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$document = Read-ChatpadJson $EvidenceDocumentPath
Test-ChatpadEvidenceDocumentContract -Document $document | ConvertTo-Json -Depth 14
