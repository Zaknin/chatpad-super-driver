[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$RunnerPath,
 [Parameter(Mandatory)][string]$HelperDirectory,
 [string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(-not $OutputPath){$OutputPath=Join-Path $repo 'artifacts/task-8lc4/readiness-input.json'}
$template=Get-Content -LiteralPath (Join-Path $repo 'artifacts/task-8lc2r1/readiness-input.json') -Raw | ConvertFrom-Json
$runner=(Resolve-Path -LiteralPath $RunnerPath).Path
$helper=(Resolve-Path -LiteralPath (Join-Path $HelperDirectory 'ChatpadVirtualXbox.exe')).Path
function New-Record([string]$Role,[string]$Path){
 if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Missing C4 payload: $Path"}
 [pscustomobject]@{Role=$Role;Path=(Resolve-Path -LiteralPath $Path).Path;SHA256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
}
$base=@($template.Files | Where-Object {$_.Role -notin @('Poc','VirtualBackend') -and $_.Role -notlike 'VirtualFile:*'})
$runtime=@(Get-ChildItem -LiteralPath $HelperDirectory -File | Where-Object {$_.Extension -ne '.pdb' -and $_.Name -ne 'HIDMaestro.Core.xml'})
if(@($runtime | Where-Object Name -eq 'HIDMaestro.Core.dll').Count -ne 1){throw 'Pinned HIDMaestro runtime assembly is missing from the runner package.'}
$files=@($base)+@(New-Record 'Poc' $runner)+@(New-Record 'VirtualBackend' $helper)
foreach($file in $runtime){$files+=New-Record ('VirtualFile:'+ $file.Name) $file.FullName}
$template.Files=$files
$template|Add-Member -NotePropertyName Task -NotePropertyValue '8L-C4' -Force
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
