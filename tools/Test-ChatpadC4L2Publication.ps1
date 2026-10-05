[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'ChatpadC4L2Publication.psm1') -Force

$good=@([pscustomobject]@{Verified=$true;SidecarCommittedLast=$true},[pscustomobject]@{Verified=$true;SidecarCommittedLast=$true})
if(-not (Test-ChatpadC4L2PublicationReceipts $good)){throw 'All verified payload receipts should pass.'}
if(Test-ChatpadC4L2PublicationReceipts @([pscustomobject]@{Verified=$false;SidecarCommittedLast=$true})){throw 'A receipt with failed payload readback must fail.'}
if(Test-ChatpadC4L2PublicationReceipts @([pscustomobject]@{Verified=$true;SidecarCommittedLast=$false})){throw 'A receipt without a final sidecar must fail.'}
if(Test-ChatpadC4L2PublicationReceipts @([pscustomobject]@{Verified=$true})){throw 'A receipt missing sidecar status must fail.'}
if(Test-ChatpadC4L2PublicationReceipts @()){throw 'An empty receipt set must fail.'}
Write-Output 'C4L2 atomic publication receipt regressions: 5/5 PASS'

$live=[pscustomobject]@{
    Schema=1;Task='8L-C4L2';Result='PASS';Source='USER_PROVIDED_LIVE_LOGS'
    ServiceInstallation='PASS';ServiceLifecycle='PASS';IPCAuthentication='PASS'
    IPCAuthenticationScope='Authorized account accepted live; wrong-SID and local-pipe policy cases covered offline.'
    NormalUserRuntime='PASS';XInput='PASS';Chatpad='PASS';Rumble='PASS'
    Reconnect='PASS';GracefulCleanup='PASS';ClientCrashCleanup='PASS';NextLaunchRecovery='PASS'
    ServiceProcessCrashRecovery='NOT_TESTED'
    AcceptedLimitation='A hard ChatpadBridge process crash cannot stop physical rumble immediately; next-launch zero-rumble recovery passed.'
    Evidence=@(
        [pscustomobject]@{Id='broker-install-repair';Result='PASS';Observed='User reported elevated InstallBroker and RepairBroker success; service Running and Automatic.'},
        [pscustomobject]@{Id='normal-user-runtime-input';Result='PASS';Observed='Normal-user bridge reached RUNNING, created the virtual Xbox, and produced Chatpad input.'},
        [pscustomobject]@{Id='xinput-rumble';Result='PASS';Observed='One XInput slot was found and the physical controller vibrated after SetState.'},
        [pscustomobject]@{Id='hot-unplug-reconnect';Result='PASS';Observed='Device removal was deferred, reconnect reopened WinUSB, and input resumed.'},
        [pscustomobject]@{Id='client-crash-cleanup';Result='PASS';Observed='After exact package process termination the virtual node was absent and service remained running.'},
        [pscustomobject]@{Id='unclean-restart-recovery';Result='PASS';Observed='Next run recovered zero rumble, recreated the virtual Xbox, resumed Chatpad input, and shut down cleanly.'}
    )
}
if(-not (Test-ChatpadC4L2LiveQualification $live)){throw 'Complete live qualification evidence should pass.'}
$summary=New-ChatpadC4L2QualificationSummary -Qualification $live -LiveQualificationSHA256 ('A'*64)
if($summary.Result -cne 'PASS' -or $summary.ServiceInstallation -cne 'PASS' -or $summary.ServiceLifecycle -cne 'PASS' -or $summary.NormalUserRuntime -cne 'PASS' -or $summary.XInput -cne 'PASS' -or $summary.Chatpad -cne 'PASS' -or $summary.Rumble -cne 'PASS' -or $summary.Reconnect -cne 'PASS' -or $summary.CrashRecovery.ClientCrashCleanup -cne 'PASS' -or $summary.CrashRecovery.NextLaunchRecovery -cne 'PASS' -or $summary.CrashRecovery.ServiceProcessCrashRecovery -cne 'NOT_TESTED'){throw 'Published qualification summary must carry each evidenced live result and preserve the untested service-crash status.'}
$incomplete=$live.PSObject.Copy();$incomplete.NormalUserRuntime='UNTESTED'
if(Test-ChatpadC4L2LiveQualification $incomplete){throw 'Incomplete normal-user runtime evidence must fail.'}
$unsupportedCrashPass=$live.PSObject.Copy();$unsupportedCrashPass.ServiceProcessCrashRecovery='PASS'
if(Test-ChatpadC4L2LiveQualification $unsupportedCrashPass){throw 'Service crash recovery must not pass without its own evidence record.'}
Write-Output 'C4L2 live qualification manifest regressions: 4/4 PASS'
