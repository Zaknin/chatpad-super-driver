[CmdletBinding(DefaultParameterSetName='Status')]
param(
 [Parameter(ParameterSetName='Status')][switch]$Status,
 [Parameter(Mandatory,ParameterSetName='Capture')][switch]$CaptureBaseline,
 [Parameter(Mandatory,ParameterSetName='Bind')][switch]$BindWinUsb,
 [Parameter(Mandatory,ParameterSetName='Restore')][switch]$RestoreXbox,
 [Parameter(Mandatory,ParameterSetName='Verify')][switch]$Verify,
 [string]$InstanceId, [string]$BaselinePath,
 [string]$OutputDirectory=(Join-Path $PSScriptRoot '../artifacts/task-8lc2/binding/baseline'),
 [string]$CandidateInf=(Join-Path $PSScriptRoot '../artifacts/task-8lc2/binding/package/ChatpadWholeDeviceWinUSB.inf'),
 [ValidateSet('Xbox','WinUSB')][string]$ExpectedState='Xbox',
 [Parameter(ParameterSetName='Bind')][Parameter(ParameterSetName='Restore')][switch]$Execute,
 [string]$Authorization,[string]$BaselineSha256,[string]$FixturePath
)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadBinding/ChatpadBinding.psm1') -Force
try {
 if($Execute){Assert-ChatpadExecutionGate $Authorization $BaselinePath $BaselineSha256 $FixturePath}
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
