[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$RunnerPath,
 [Parameter(Mandatory)][string]$HelperDirectory,
 [string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadC4Package.psm1') -Force
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $OutputPath){$OutputPath=Join-Path $repo 'artifacts/task-8lc4l2/readiness-input.json'}
$template=Get-Content -LiteralPath (Join-Path $repo 'artifacts/task-8lc2r1/readiness-input.json') -Raw | ConvertFrom-Json
$runner=(Resolve-Path -LiteralPath $RunnerPath).Path
$helper=(Resolve-Path -LiteralPath (Join-Path $HelperDirectory 'ChatpadVirtualXbox.exe')).Path
$base=@($template.Files | Where-Object {$_.Role -notin @('Poc','VirtualBackend','SetupTool') -and $_.Role -notlike 'VirtualFile:*'})
$packageRoot=(Resolve-Path -LiteralPath $HelperDirectory).Path
foreach($required in @('ChatpadVirtualXbox.exe','ChatpadVirtualXbox.dll','ChatpadVirtualXbox.deps.json','ChatpadVirtualXbox.runtimeconfig.json','HIDMaestro.Core.dll')){
 if(-not(Test-Path -LiteralPath (Join-Path $packageRoot $required) -PathType Leaf)){throw "Self-contained broker package is incomplete; required runtime member is missing: $required"}
}
$payloads=New-ChatpadC4PackagePayloadRecords $packageRoot
$files=@($base)+@(New-ChatpadC4PackageRecord 'Poc' $runner)+@(New-ChatpadC4PackageRecord 'VirtualBackend' $helper)+$payloads
$template.Files=$files
$template|Add-Member -NotePropertyName PackageRoot -NotePropertyValue $packageRoot -Force
$template|Add-Member -NotePropertyName Task -NotePropertyValue '8L-C4L2' -Force
$template.Repository=[pscustomobject]@{
 Branch=[string](& git.exe -C $repo branch --show-current)
 Commit=[string](& git.exe -C $repo rev-parse HEAD)
}
if($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($template.Repository.Branch)){throw 'Current Git branch/HEAD query failed.'}
$template.Dependencies.VirtualAssembly=(Join-Path $HelperDirectory 'ChatpadVirtualXbox.dll')
$template.Dependencies.DotnetPath='C:/Dev/tools/dotnet10/dotnet.exe'
if(-not(Test-Path -LiteralPath $template.Dependencies.DotnetPath)){throw 'Pinned .NET 10 runtime host is not available.'}
$template.Files|ForEach-Object {if(-not(Test-Path -LiteralPath $_.Path -PathType Leaf) -or (Get-FileHash -LiteralPath $_.Path).Hash -ine $_.SHA256){throw "Readiness hash check failed: $($_.Role)"}}
$parent=Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath));New-Item -ItemType Directory -Force -Path $parent|Out-Null
$template|ConvertTo-Json -Depth 16|Set-Content -LiteralPath $OutputPath -Encoding utf8
Write-Output "C4 readiness captured for $($template.Repository.Branch) $($template.Repository.Commit); all payload hashes re-read."
