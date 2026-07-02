[CmdletBinding()]
param(
    [string]$ImplementationCommit='',
    [string]$OutputPath=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((&git rev-parse --show-toplevel).Trim())
if(-not$ImplementationCommit){$ImplementationCommit=(&git rev-parse HEAD).Trim()}
Import-Module (Join-Path $PSScriptRoot 'ExactInstance\ChatpadExactInstance.OfflineSuite.psm1') -Force
$result=Invoke-ChatpadExactInstanceOfflineSuite -ImplementationCommit $ImplementationCommit
$json=$result|ConvertTo-Json -Depth 50
if($OutputPath){
    $full=[IO.Path]::GetFullPath((Join-Path $root $OutputPath))
    if(-not$full.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'OutputPath must remain inside the repository.'}
    $parent=Split-Path -Parent $full
    if(-not(Test-Path -LiteralPath $parent)){[IO.Directory]::CreateDirectory($parent)|Out-Null}
    [IO.File]::WriteAllText($full,$json+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
}
$json
if($result.result-ne'PASS'){exit 1}
