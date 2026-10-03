$ErrorActionPreference='Stop'
$module=Join-Path $PSScriptRoot 'ChatpadReadinessArtifacts.psm1'
if(-not(Test-Path $module)){throw 'FAIL: readiness archive module missing'}
Import-Module $module -Force
$taskRoot=Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/archive-tests'
New-Item -ItemType Directory -Path (Join-Path $taskRoot 'input') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $taskRoot 'input/b.txt'),'second')
[IO.File]::WriteAllText((Join-Path $taskRoot 'input/a.txt'),'first')
$script:count=0
function Assert($ok,$name){if(-not $ok){throw "FAIL: $name"};$script:count++}
foreach($name in @('one.zip','two.zip')){
 $destination=Join-Path $taskRoot $name
 if(Test-Path $destination){$destination=Join-Path $taskRoot ([guid]::NewGuid().ToString('N')+'.zip')}
 $hash=New-ChatpadDeterministicArchive (Join-Path $taskRoot 'input') $destination
 if($name -eq 'one.zip'){$one=$destination;$firstHash=$hash}else{$two=$destination}
 Assert ((Get-FileHash $destination).Hash -ceq $hash) 'returned archive hash matches bytes'
}
Assert ($firstHash -ceq (Get-FileHash $two).Hash) 'identical staged bytes produce identical ZIP'
$archive=[IO.Compression.ZipFile]::OpenRead($one)
try{
 Assert (($archive.Entries.FullName -join '|') -ceq 'a.txt|b.txt') 'archive ordering and relative names'
 Assert (@($archive.Entries | Where-Object {$_.LastWriteTime.Year -ne 2000}).Count -eq 0) 'archive timestamps fixed'
}finally{$archive.Dispose()}
$private='USB\VID_045E&PID_028E\PRIVATE_SERIAL'
$escaped=$private.Replace('\','\\')
$protected=Protect-ChatpadEvidenceText ($private+' '+$escaped+' C:\Users\private-profile') @($private,'C:\Users\private-profile')
Assert (-not $protected.Contains('PRIVATE_SERIAL') -and -not $protected.Contains('private-profile')) 'literal and JSON escaped machine identities redacted'
Assert ($protected.Contains('<redacted>')) 'redaction remains explicit'
Assert ((Protect-ChatpadEvidenceText 'public text' @('')) -ceq 'public text') 'empty secrets never erase evidence'
$refused=$false;try{New-ChatpadDeterministicArchive (Join-Path $taskRoot 'input') $one | Out-Null}catch{$refused=$true}
Assert $refused 'immutable archive overwrite refused'
Write-Output "PASS archive/privacy $count/$count"
