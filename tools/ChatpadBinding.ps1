[CmdletBinding(DefaultParameterSetName='Status')]
param(
 [Parameter(ParameterSetName='Status')][switch]$Status,
 [Parameter(Mandatory,ParameterSetName='Capture')][switch]$CaptureBaseline,
 [Parameter(Mandatory,ParameterSetName='Bind')][switch]$BindWinUsb,
 [Parameter(Mandatory,ParameterSetName='Restore')][switch]$RestoreXbox,
 [Parameter(Mandatory,ParameterSetName='Verify')][switch]$Verify,
 [Parameter(Mandatory,ParameterSetName='PlanTransition')][switch]$PlanWinUsbTransition,
 [Parameter(Mandatory,ParameterSetName='PlanRestore')][switch]$PlanRestoreXbox,
 [Parameter(Mandatory,ParameterSetName='Restorable')][switch]$VerifyRestorable,
 [Parameter(Mandatory,ParameterSetName='Preflight')][switch]$PreflightC3,
 [string]$ReadinessPath,
 [switch]$RestoreExtension,
 [string]$JsonPath,
 [string]$InstanceId, [string]$BaselinePath,
 [string]$OutputDirectory,
 [string]$CandidateInf,
 [ValidateSet('Xbox','WinUSB')][string]$ExpectedState='Xbox',
 [Parameter(ParameterSetName='Bind')][Parameter(ParameterSetName='Restore')][switch]$Execute,
 [string]$Authorization,[string]$BaselineSha256,[string]$FixturePath
)
$ErrorActionPreference='Stop'
if(-not $ReadinessPath){$ReadinessPath=Join-Path $PSScriptRoot '../artifacts/task-8lc2r1/readiness-input.json'}
if(-not $OutputDirectory){$OutputDirectory=Join-Path $PSScriptRoot '../artifacts/task-8lc2/binding/baseline'}
if(-not $CandidateInf){$CandidateInf=Join-Path $PSScriptRoot '../artifacts/task-8lc2/binding/package/ChatpadWholeDeviceWinUSB.inf'}
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/ChatpadBinding.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Planning.psm1') -Force
try {
 if($PSCmdlet.ParameterSetName -in @('PlanTransition','PlanRestore','Restorable','Preflight')){
  if($Execute -or $FixturePath){throw 'Read-only C3 preparation uses actual source files; execution/fixtures refused.'}
  $readiness=Get-Content -LiteralPath $ReadinessPath -Raw | ConvertFrom-Json
  if($PSCmdlet.ParameterSetName -eq 'Restorable'){Assert-ChatpadRestorable $readiness -RestoreExtension:$RestoreExtension;$report=[pscustomobject]@{Result='PASS';ReadOnly=$true;BaseRestorable=$true;OptionalExtension=$RestoreExtension.IsPresent;PhysicalRollback='UNTESTED'}}
  elseif($PSCmdlet.ParameterSetName -eq 'PlanRestore'){$captured=$null;if($BaselinePath){$captured=(Get-Content $BaselinePath -Raw | ConvertFrom-Json).State.Target};$report=New-ChatpadRestorePlan $captured $readiness -RestoreExtension:$RestoreExtension}
  else {
   $state=$null;try{$state=Get-ChatpadBindingState $InstanceId}catch{$state=[pscustomobject]@{Target=$null;ClassLowerFilters=@();ClassUpperFilters=@();CaptureError=$_.Exception.Message}}
   $candidateLines=@(if($state.PSObject.Properties['Candidates']){$state.Candidates})
   $inventory=@(Get-ChatpadExtensionInventory -CandidateLines $candidateLines)
   if($PSCmdlet.ParameterSetName -eq 'PlanTransition'){$report=New-ChatpadTransitionPlan $state $inventory $readiness}
   else{
    # Input records describe source identities, never fresh live state. Revalidate
    # Git, effective CI and candidate selection at command invocation.
    $currentBranch=[string](& git.exe -C (Join-Path $PSScriptRoot '..') branch --show-current)
    if($LASTEXITCODE -ne 0){throw 'Current Git branch query failed; preflight cannot verify source identity.'}
    $currentCommit=[string](& git.exe -C (Join-Path $PSScriptRoot '..') rev-parse HEAD)
    if($LASTEXITCODE -ne 0){throw 'Current Git HEAD query failed; preflight cannot verify source identity.'}
    $currentRepository=[pscustomobject]@{Branch=$currentBranch;Commit=$currentCommit}
    $readiness.Security=Get-ChatpadCurrentSecurity
    try{$signatures=Test-ChatpadCurrentSignatures $readiness;$readiness.Microsoft.SourceSignatureVerified=$signatures.MicrosoftSourceSignatureVerified}catch{$readiness.Microsoft.SourceSignatureVerified=$false;$readiness.Trust.NormalWindowsInstallExpected=$false;$readiness.Trust.Reason=$_.Exception.Message}
    try{$readiness.Dependencies=Get-ChatpadCurrentBackend $readiness}catch{$readiness.Dependencies.Available=$false;$readiness.Dependencies.Reason=$_.Exception.Message}
    $readiness.Microsoft.CandidateVerified=$false
    if($state.Target){try{Assert-ChatpadRestorable $readiness;if(-not ('Chatpad.Binding.ExactDevice' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ChatpadBinding/ExactDevice.cs')};$m=$readiness.Microsoft;$readiness.Microsoft.CandidateVerified=[Chatpad.Binding.ExactDevice]::InspectCandidate($state.Target.InstanceId,$m.InfPath,$m.Section,$m.Provider,$m.Version)}catch{}}
    $report=New-ChatpadC3Preflight $state $inventory $readiness -CurrentRepository $currentRepository
   }
  }
  $json=$report | ConvertTo-Json -Depth 14
  if($JsonPath){$json | Set-Content -LiteralPath $JsonPath -Encoding utf8}
  Write-Output $json
  if($report.PSObject.Properties['Result'] -and $report.Result -eq 'BLOCKED'){Write-Output 'BLOCKED: C3 must not start.';exit 2}
  exit 0
 }
 if($Execute){
  if($FixturePath){throw 'Fixtures can never execute live actions.'}
  $recovery=Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json
  if($recovery.Schema -ne 2){throw 'Use a C3 schema2 baseline with complete recovery sources; old C2 binding-only execution is superseded.'}
  if($BaselineSha256 -and (Get-FileHash -LiteralPath $BaselinePath).Hash -ine $BaselineSha256){throw 'Baseline hash mismatch.'}
  Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/C3Execution.psm1') -Force
  $operation=if($RestoreXbox){'Restore'}else{'Bind'}
  Invoke-ChatpadC3BindingAction $operation $recovery -Execute | ConvertTo-Json
  exit 0
 }
 $state=if($FixturePath){Get-Content -LiteralPath $FixturePath -Raw | ConvertFrom-Json}else{Get-ChatpadBindingState $InstanceId}
 if($FixturePath){Select-ChatpadTarget @($state.Target) $InstanceId | Out-Null}
 switch($PSCmdlet.ParameterSetName){
  'Status' { $state | ConvertTo-Json -Depth 12; exit 0 }
  'Capture' { if($FixturePath){throw 'Cannot capture a fixture as live baseline.'}; Save-ChatpadBaseline $state $OutputDirectory | ConvertTo-Json; exit 0 }
  'Verify' {
   $recognized=Get-ChatpadRecognizedState $state
   $match=$recognized -eq $ExpectedState
   if($BaselinePath){$baseline=Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json; Assert-ChatpadBaseline $baseline $BaselinePath; $match=$match -and $state.Target.InstanceId -ieq $baseline.State.Target.InstanceId -and $state.Target.ContainerId -ieq $baseline.State.Target.ContainerId
    if($ExpectedState -eq 'Xbox'){
     $match=$match -and $state.Target.Version -eq $baseline.State.Target.Version -and $state.Target.Section -eq $baseline.State.Target.Section -and ((@($state.Target.LowerFilters)-join '|') -eq (@($baseline.State.Target.LowerFilters)-join '|')) -and ((@($state.Target.UpperFilters)-join '|') -eq (@($baseline.State.Target.UpperFilters)-join '|')) -and ((@($state.ClassLowerFilters)-join '|') -eq (@($baseline.State.ClassLowerFilters)-join '|')) -and ((@($state.ClassUpperFilters)-join '|') -eq (@($baseline.State.ClassUpperFilters)-join '|')) -and (Get-FileHash -LiteralPath $baseline.InstalledImage.Path).Hash -eq $baseline.InstalledImage.SHA256
     $match=$match -and @($state.Extensions).Count -eq 1 -and $state.Extensions[0].SHA256 -eq $baseline.State.Extensions[0].SHA256
     foreach($name in @('xusb22','ChatpadFilter','vhf')){$match=$match -and (($state.Stack -join '\n') -match ('(?i)\b'+[regex]::Escape($name)+'\b'))}
    }
   }
   [pscustomobject]@{Expected=$ExpectedState; Actual=$recognized; Passed=$match; LiveTransportAcceptance='UNTESTED'} | ConvertTo-Json
   if($match){exit 0}else{exit 2}
  }
  default {
   if(-not $BaselinePath){throw 'Captured -BaselinePath required.'}
   $baseline=Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json
   $operation=if($BindWinUsb){'BindWinUsb'}else{'RestoreXbox'}
   $plan=New-ChatpadBindingPlan $operation $state $baseline $BaselinePath $CandidateInf
   $plan | ConvertTo-Json -Depth 6
   if(@($plan.Blockers).Count){exit 2}
   if(-not $Execute){exit 0}
   # Re-read immediately before invocation. Exact native helper enumerates only
   # this single INF and checks one matching captured driver node on this instance.
   $fresh=Get-ChatpadBindingState $plan.InstanceId
   $checked=New-ChatpadBindingPlan $operation $fresh $baseline $BaselinePath $CandidateInf
   if(@($checked.Blockers).Count -or $checked.InfSHA256 -ne $plan.InfSHA256){throw 'Pre-invocation state/package drift.'}
   if(-not ('Chatpad.Binding.ExactDevice' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'ChatpadBinding/ExactDevice.cs')}
   try{$needReboot=[Chatpad.Binding.ExactDevice]::Install($plan.InstanceId,$plan.Inf,$plan.Section,$plan.Provider,$plan.Version)}catch{Write-Error $_ -ErrorAction Continue; exit 4}
   if($needReboot){Write-Output 'BLOCKED: native installation requests reboot; no restart/reboot performed.'; exit 5}
   $after=Get-ChatpadBindingState $plan.InstanceId
   $expected=if($BindWinUsb){'WinUSB'}else{'Xbox'}
   if((Get-ChatpadRecognizedState $after) -ne $expected){Write-Output 'FAILED: exact binding postcondition mismatch; stop and collect evidence.'; exit 4}
   Write-Output 'PASS: exact function binding verified. Physical input/rollback acceptance remains operator-test required.'; exit 0
  }
 }
}catch{Write-Error $_ -ErrorAction Continue; exit 3}
