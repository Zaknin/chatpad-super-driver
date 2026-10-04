[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadHidMaestroPackage.psm1') -Force
$passed=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw ('FAIL '+$Name)};$script:passed++}
$evidence=[ordered]@{ExactPayload=$true;UnmodifiedDlls=$true;CatalogsValid=$true;ExactSigner=$true;AllMembers=$true;TrustedRoot=$true;TrustedPublisher=$true;SigningKey=$true;CertificateValid=$true;CodeSigningEku=$true;NoDuplicateCertificates=$true;MachineChain=$true;NormalWindows=$true;Hvci=$true;InboxKernelPolicy=$true}
$decision=Get-ChatpadHidMaestroTrustDecision $evidence
Check $decision.InstallExpected 'all exact offline gates'
Check (-not $decision.RuntimeQualified) 'offline trust does not prove UMDF load'
foreach($name in @($evidence.Keys)){
 $copy=[ordered]@{};foreach($key in $evidence.Keys){$copy[$key]=$evidence[$key]};$copy[$name]=$false
 $blocked=Get-ChatpadHidMaestroTrustDecision $copy
 Check (-not $blocked.InstallExpected -and $blocked.Blockers.Count -eq 1) ('reject '+$name)
}
$absent=Get-ChatpadHidMaestroTrustDecision @{}
Check (-not $absent.InstallExpected -and $absent.Blockers.Count -eq $evidence.Count) 'missing evidence fails closed'
$malformed=[ordered]@{};foreach($key in $evidence.Keys){$malformed[$key]='true'}
Check (-not (Get-ChatpadHidMaestroTrustDecision $malformed).InstallExpected) 'strings cannot stand in for verified booleans'
$fixture="[Manufacturer]`n%ManufacturerName% = Standard,NTamd64`n[Standard.NTamd64]`nroot-model=Install,root\HIDMaestro`n"
$bytes=ConvertTo-ChatpadHidMaestroInf $fixture
Check ($bytes[0] -eq 255 -and $bytes[1] -eq 254) 'supported UTF16LE BOM'
$text=[Text.Encoding]::Unicode.GetString($bytes,2,$bytes.Length-2)
Check ($text.Contains('Standard,NTamd64.10.0...17134') -and $text.Contains('[Standard.NTamd64.10.0...17134]')) 'DIRID13 minimum supported OS decoration'
Check ($text.Contains('root-model=Install,root\HIDMaestro')) 'functional model preserved'
$rejected=$false;try{$null=ConvertTo-ChatpadHidMaestroInf '[Unexpected]'}catch{$rejected=$true}
Check $rejected 'unexpected source INF contract refused'
$security=[pscustomobject]@{CapturedUtc='old';QuerySucceeded=$true;TestSigning=$false;Hvci=$true;SecureBoot=$false;SecureBootQuery='queried';Mutation=$false}
$later=[pscustomobject]@{CapturedUtc='new';QuerySucceeded=$true;TestSigning=$false;Hvci=$true;SecureBoot=$false;SecureBootQuery='queried';Mutation=$false}
Check (Test-ChatpadHidMaestroSecurityInvariant $security $later) 'timestamps are provenance, not security state'
$later.Hvci=$false
Check (-not (Test-ChatpadHidMaestroSecurityInvariant $security $later)) 'HVCI change refused'
$later.Hvci=$true;$later.SecureBoot=$true
Check (-not (Test-ChatpadHidMaestroSecurityInvariant $security $later)) 'SecureBoot change refused'
Check (Test-ChatpadHidMaestroCleanupIds @('ROOT\VID_045E&PID_028E&IG_00\HM_0123456789ABCDEF','SWD\HIDMAESTRO\HM_0123456789ABCDEF')) 'exact virtual-only cleanup scope'
Check (-not (Test-ChatpadHidMaestroCleanupIds @('USB\VID_045E&PID_028E\physical','SWD\HIDMAESTRO\HM_0123456789ABCDEF'))) 'physical cleanup refused'
Check (-not (Test-ChatpadHidMaestroCleanupIds @('ROOT\VID_045E&PID_028E&IG_00\HM_0123456789ABCDEF','SWD\HIDMAESTRO\HM_1123456789ABCDEF'))) 'different owner tokens refused'
$qualification=[pscustomobject]@{result='PASS';umdfHealthy=$true;adapterInitialized=$true;cleanupPassed=$true;observations=@(1..8 | ForEach-Object {[pscustomobject]@{Observation=[pscustomobject]@{Matched=$true}}})}
$invariants=[pscustomobject]@{Result='PASS';PhysicalUnchanged=$true;SecurityUnchanged=$true;TrustUnchanged=$true;GameInputServiceUnchanged=$true;MetadataClean=$true;NoStaleDevice=$true}
Check (Test-ChatpadHidMaestroRuntimeQualification $qualification $invariants) 'C3 accepts complete isolated qualification'
$qualification.umdfHealthy=$false
Check (-not (Test-ChatpadHidMaestroRuntimeQualification $qualification $invariants)) 'C3 rejects staged-only runtime'
$qualification.umdfHealthy=$true;$qualification.observations[0].Observation.Matched=$false
Check (-not (Test-ChatpadHidMaestroRuntimeQualification $qualification $invariants)) 'C3 rejects failed state roundtrip'
$qualification.observations[0].Observation.Matched=$true;$invariants.NoStaleDevice=$false
Check (-not (Test-ChatpadHidMaestroRuntimeQualification $qualification $invariants)) 'C3 rejects stale virtual device'
$report=[pscustomobject]@{Suite='local-hidmaestro-package';Passed=$passed;Failed=0;LiveMutation=$false}
$root=Join-Path $PSScriptRoot '../artifacts/task-8lc2r3'
New-Item -ItemType Directory $root -Force | Out-Null
$report | ConvertTo-Json | Set-Content (Join-Path $root 'package-test-summary.json') -Encoding utf8
$report | ConvertTo-Json
