[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadWinUsbTrust.psm1') -Force
$script:count=0
function Assert([bool]$Condition,[string]$Name){if(-not $Condition){throw "FAIL: $Name"};$script:count++}
$good=@{ ExactReviewedInf=$true; InBoxOnly=$true; SignatureIntact=$true; ExactSigner=$true; CatalogAuthenticode=$true; InfMembership=$true; LocalMachineRoot=$true; LocalMachinePublisher=$true; LocalMachineChain=$true; InBoxKernelPolicy=$true; NormalMode=$true }
$decision=Get-ChatpadWinUsbTrustDecision $good
Assert $decision.NormalWindowsInstallExpected 'local trusted INF-only package is expected to install normally'
Assert (-not $decision.PhysicalInstallVerified) 'offline trust never claims actual staging/binding'
foreach($key in @($good.Keys)){$bad=$good.Clone();$bad[$key]=$false;$d=Get-ChatpadWinUsbTrustDecision $bad;Assert (-not $d.NormalWindowsInstallExpected) "missing $key blocks";Assert ($d.Blockers.Count -gt 0) "$key names blocker"}
$e=$good.Clone();$e.KernelCatalogVerification=$false
Assert (Get-ChatpadWinUsbTrustDecision $e).NormalWindowsInstallExpected 'local catalog /kp is separate from Microsoft inbox binary /kp'
$incomplete=@{ExactReviewedInf=$true};Assert (-not (Get-ChatpadWinUsbTrustDecision $incomplete).NormalWindowsInstallExpected) 'missing evidence fails closed'
$temp=Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/trust-tests'
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$file=Join-Path $temp 'fixture.inf';[IO.File]::WriteAllText($file,'fixture')
$h=(Get-FileHash $file -Algorithm SHA256).Hash
Assert (Test-ChatpadArtifactHash $file $h) 'exact hash accepted'
Assert (-not (Test-ChatpadArtifactHash $file ('0'*64))) 'hash mismatch rejected'
[IO.File]::WriteAllText($file,'tampered')
Assert (-not (Test-ChatpadArtifactHash $file $h)) 'tamper rejected'
Assert (-not (Test-ChatpadArtifactHash ($file+'.missing') $h)) 'missing file rejected'
Assert (-not (Test-ChatpadArtifactHash $file 'bad')) 'malformed expected hash rejected'
Write-Output "PASS: $script:count trust/hash checks; no store/driver/device mutation."
