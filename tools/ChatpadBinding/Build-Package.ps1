[CmdletBinding()]
param([string]$OutputPath = (Join-Path $PSScriptRoot '../../artifacts/task-8lc2/binding/package'))
$ErrorActionPreference = 'Stop'
$output = [IO.Path]::GetFullPath($OutputPath)
$artifacts = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../artifacts')) + [IO.Path]::DirectorySeparatorChar
if (-not $output.StartsWith($artifacts, [StringComparison]::OrdinalIgnoreCase)) { throw 'Package output must be under ignored repository artifacts.' }
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'ChatpadWholeDeviceWinUSB.inf') -Destination $output
$kit = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin/10.0.26100.0'
$verify = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/Tools/10.0.26100.0/x64/InfVerif.exe'
$catalog = Join-Path $kit 'x86/Inf2Cat.exe'
if (-not (Test-Path -LiteralPath $verify) -or -not (Test-Path -LiteralPath $catalog)) { throw 'Pinned WDK InfVerif/Inf2Cat unavailable.' }
& $verify /u (Join-Path $output 'ChatpadWholeDeviceWinUSB.inf') *> (Join-Path $output '../infverif.txt')
if ($LASTEXITCODE -ne 0) { throw "InfVerif failed: $LASTEXITCODE" }
& $catalog "/driver:$output" /os:10_CO_X64 /uselocaltime *> (Join-Path $output '../inf2cat.txt')
if ($LASTEXITCODE -ne 0) { throw "Inf2Cat failed: $LASTEXITCODE" }
Get-ChildItem -LiteralPath $output -File | ForEach-Object { [pscustomobject]@{ Name=$_.Name; SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash; Signature=(Get-AuthenticodeSignature -LiteralPath $_.FullName).Status.ToString() } } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output '../package.json') -Encoding utf8
Write-Output 'PASS: unsigned INF/catalog prepared offline; no staging/signing/trust/binding.'
