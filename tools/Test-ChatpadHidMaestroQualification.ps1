[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadHidMaestroQualification.psm1') -Force
$root=Join-Path $PSScriptRoot '../artifacts/task-8lc2r2/identity-tests'
New-Item -ItemType Directory $root -Force | Out-Null
$fixture=Join-Path $root ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $fixture | Out-Null
$expected=@(foreach($name in @('hidmaestro.inf','hidmaestro.cat','HIDMaestro.dll','hidmaestro_xusb.inf','hidmaestro_xusb.cat','HMXInput.dll')){
 $path=Join-Path $fixture $name
 [IO.File]::WriteAllText($path,'qualified-fixture-'+$name)
 [pscustomobject]@{Name=$name;SHA256=(Get-FileHash $path).Hash}
})
$passed=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw "FAIL: $Name"};$script:passed++}
$valid=Test-ChatpadHidMaestroPackageIdentity $fixture $expected
Check ($valid.Matched -and $valid.Files.Count -eq 6) 'complete exact package identity'
Check (-not $valid.InstallationQualified) 'identity alone never grants installation'
$extra=Join-Path $fixture 'unexpected-driver.dll'
[IO.File]::WriteAllText($extra,'unqualified-extra-payload')
$withExtra=Test-ChatpadHidMaestroPackageIdentity $fixture $expected
Check (-not $withExtra.Matched) 'reject additional package payload'
[IO.File]::Move($extra,(Join-Path $root ('unexpected-'+[guid]::NewGuid().ToString('N')+'.saved')))
foreach($file in $expected){
 $path=Join-Path $fixture $file.Name
 $original=[IO.File]::ReadAllBytes($path)
 [IO.File]::WriteAllText($path,'wrong-version-or-bytes')
 $wrong=Test-ChatpadHidMaestroPackageIdentity $fixture $expected
 Check (-not $wrong.Matched -and @($wrong.Files | Where-Object Status -eq 'MISMATCH').Count -eq 1) ('reject mismatch '+$file.Name)
 [IO.File]::WriteAllBytes($path,$original)
 [IO.File]::Move($path,$path+'.saved')
 $missing=Test-ChatpadHidMaestroPackageIdentity $fixture $expected
 Check (-not $missing.Matched -and @($missing.Files | Where-Object Status -eq 'MISSING').Count -eq 1) ('reject missing '+$file.Name)
 [IO.File]::Move($path+'.saved',$path)
}
$absent=Test-ChatpadHidMaestroPackageIdentity (Join-Path $fixture 'absent-runtime') $expected
Check (-not $absent.Matched -and @($absent.Files | Where-Object Status -eq 'MISSING').Count -eq 6) 'absent runtime'
foreach($bad in @(@(),@([pscustomobject]@{Name='../outside.dll';SHA256=$expected[0].SHA256}),@($expected[0],$expected[0]),@([pscustomobject]@{Name='file.dll';SHA256='bad'}))){
 $rejected=$false
 try{$null=Test-ChatpadHidMaestroPackageIdentity $fixture $bad}catch{$rejected=$true}
 Check $rejected 'malformed identity contract refused'
}
$result=[pscustomobject]@{Suite='hidmaestro-package-identity';Passed=$passed;Failed=0;LiveMutation=$false;FixtureOnly=$true}
$result | ConvertTo-Json | Set-Content (Join-Path $root 'test-summary.json') -Encoding utf8
$result | ConvertTo-Json
