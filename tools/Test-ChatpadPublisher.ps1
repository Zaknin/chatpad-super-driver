$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Publish-ChatpadArtifact.psm1') -Force
$temp=Join-Path $PSScriptRoot ('../artifacts/task-8lc2/publisher-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force (Join-Path $temp 'source'),(Join-Path $temp 'destination') | Out-Null
$source=Join-Path $temp 'source/probe.txt';[IO.File]::WriteAllText($source,'offline publication fixture')
$result=Publish-ChatpadArtifact $source (Join-Path $temp 'destination') 'probe.txt'
$count=0
function Assert($condition,$name){if(-not $condition){throw "FAIL: $name"};$script:count++}
Assert $result.Verified 'independent verification result'
Assert ((Get-FileHash $source).Hash -eq (Get-FileHash $result.Path).Hash) 'final SHA equals source'
Assert (Test-Path -LiteralPath ($result.Path+'.sha256')) 'completion marker exists'
Assert (-not (Test-Path -LiteralPath ($result.Path+'.part'))) 'no payload partial after commit'
Assert ((Get-Content -LiteralPath ($result.Path+'.sha256') -Raw).StartsWith($result.SHA256+'  probe.txt')) 'marker identifies exact payload hash'
$failed=$false;try{Publish-ChatpadArtifact $source (Join-Path $temp 'destination') '../escape.txt' | Out-Null}catch{$failed=$true}
Assert $failed 'path escape refused'
$failed=$false;try{Publish-ChatpadArtifact $source (Join-Path $temp 'destination') 'probe.txt' | Out-Null}catch{$failed=$true}
Assert $failed 'completion overwrite refused'
$parseErrors=$null;$parseTokens=$null
$taskAst=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'Publish-ChatpadC2.ps1'),[ref]$parseTokens,[ref]$parseErrors)
$gitFunction=$taskAst.Find({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Git'},$true)
. ([scriptblock]::Create($gitFunction.Extent.Text))
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$expectedCommit=(& git.exe -C (Join-Path $PSScriptRoot '..') rev-parse HEAD)
$helperCommit=@(Git @('rev-parse','HEAD'))
Assert ($helperCommit.Count -eq 1 -and $helperCommit[0] -ceq $expectedCommit) 'task publisher invokes native Git despite function name'
$result | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $temp 'receipt.json')
Write-Output "PASS publisher $count/$count"
