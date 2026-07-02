[CmdletBinding()]
param([switch]$PlanOnly = $true)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

if (-not $PlanOnly) { throw 'Runtime host preflight is inspection-only in this scaffold. Use a future audited live-session script for execution.' }
$os = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$principal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
[pscustomobject]@{
    schema_version = 'chatpad-runtime-host-preflight-v1'
    result = 'PASS'
    mode = 'PlanOnly'
    windows_product = $os.ProductName
    windows_build = ('{0}.{1}' -f $os.CurrentBuildNumber, $os.UBR)
    powershell_version = $PSVersionTable.PSVersion.ToString()
    is_administrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    note = 'No device, driver, signing, trace, service, boot, registry mutation, or hardware operation is performed.'
} | ConvertTo-Json -Depth 5
