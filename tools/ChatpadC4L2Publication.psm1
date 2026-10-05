function Test-ChatpadC4L2PublicationReceipts {
    [CmdletBinding()]
    param([AllowEmptyCollection()][object[]]$Receipts)
    if(-not $Receipts -or $Receipts.Count -eq 0){return $false}
    foreach($receipt in $Receipts){
        if($null -eq $receipt -or
           -not $receipt.PSObject.Properties['Verified'] -or
           -not $receipt.PSObject.Properties['SidecarCommittedLast'] -or
           $receipt.Verified -ne $true -or
           $receipt.SidecarCommittedLast -ne $true){return $false}
    }
    return $true
}

function Test-ChatpadC4L2LiveQualification {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()][object]$Qualification)
    if($null -eq $Qualification){return $false}
    foreach($name in @('Schema','Task','Result','Source','ServiceInstallation','ServiceLifecycle','IPCAuthentication','IPCAuthenticationScope','NormalUserRuntime','XInput','Chatpad','Rumble','Reconnect','GracefulCleanup','ClientCrashCleanup','NextLaunchRecovery','ServiceProcessCrashRecovery','AcceptedLimitation','Evidence')){
        if(-not $Qualification.PSObject.Properties[$name]){return $false}
    }
    if($Qualification.Schema -ne 1 -or $Qualification.Task -cne '8L-C4L2' -or $Qualification.Result -cne 'PASS' -or $Qualification.Source -cne 'USER_PROVIDED_LIVE_LOGS'){return $false}
    foreach($name in @('ServiceInstallation','ServiceLifecycle','IPCAuthentication','NormalUserRuntime','XInput','Chatpad','Rumble','Reconnect','GracefulCleanup','ClientCrashCleanup','NextLaunchRecovery')){
        if($Qualification.$name -cne 'PASS'){return $false}
    }
    if([string]::IsNullOrWhiteSpace([string]$Qualification.IPCAuthenticationScope)){return $false}
    if($Qualification.ServiceProcessCrashRecovery -cnotin @('NOT_TESTED','PASS')){return $false}
    if([string]::IsNullOrWhiteSpace([string]$Qualification.AcceptedLimitation)){return $false}
    $evidence=@($Qualification.Evidence)
    $requiredIds=@('broker-install-repair','normal-user-runtime-input','xinput-rumble','hot-unplug-reconnect','client-crash-cleanup','unclean-restart-recovery')
    foreach($id in $requiredIds){
        $matches=@($evidence|Where-Object {$_.Id -ceq $id -and $_.Result -ceq 'PASS'})
        if($matches.Count -ne 1){return $false}
    }
    if($Qualification.ServiceProcessCrashRecovery -ceq 'PASS'){
        $serviceCrash=@($evidence|Where-Object {$_.Id -ceq 'service-process-crash-recovery' -and $_.Result -ceq 'PASS'})
        if($serviceCrash.Count -ne 1){return $false}
    }
    return $true
}

function New-ChatpadC4L2QualificationSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Qualification,
        [Parameter(Mandatory)][ValidatePattern('^[0-9A-Fa-f]{64}$')][string]$LiveQualificationSHA256
    )
    if(-not (Test-ChatpadC4L2LiveQualification $Qualification)){throw 'C4L2 live qualification record is incomplete or contains unsupported PASS claims.'}
    [ordered]@{
        Result='PASS'
        ServiceInstallation=$Qualification.ServiceInstallation
        ServiceLifecycle=$Qualification.ServiceLifecycle
        IPCAuthentication=$Qualification.IPCAuthentication
        IPCAuthenticationScope=$Qualification.IPCAuthenticationScope
        NormalUserRuntime=$Qualification.NormalUserRuntime
        XInput=$Qualification.XInput
        Chatpad=$Qualification.Chatpad
        Rumble=$Qualification.Rumble
        Reconnect=$Qualification.Reconnect
        GracefulCleanup=$Qualification.GracefulCleanup
        CrashRecovery=[ordered]@{
            ClientCrashCleanup=$Qualification.ClientCrashCleanup
            NextLaunchRecovery=$Qualification.NextLaunchRecovery
            ServiceProcessCrashRecovery=$Qualification.ServiceProcessCrashRecovery
            AcceptedPhysicalRumbleLimitation=$Qualification.AcceptedLimitation
        }
        LiveQualificationSHA256=$LiveQualificationSHA256.ToUpperInvariant()
    }
}

Export-ModuleMember -Function Test-ChatpadC4L2PublicationReceipts,Test-ChatpadC4L2LiveQualification,New-ChatpadC4L2QualificationSummary
