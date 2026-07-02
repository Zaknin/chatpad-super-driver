Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AcceptedBranch = 'feature/runtime-bringup-readiness-scaffolding'
$script:AcceptedStartBranch = 'feature/offline-runtime-instrumentation-dynamic-emission-remediation'
$script:AcceptedCommit = 'f49b5cbe9e6bba423cfb59313dbdc9be92c785ca'
$script:AcceptedParent = '38d434e8f7c815f609834f79315600aa73969639'
$script:AcceptedProviderGuid = '{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}'
$script:AcceptedDebugSysSha256 = 'E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'
$script:AcceptedReleaseSysSha256 = 'A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404'

function Get-ChatpadRepoRoot {
    $root = (& git rev-parse --show-toplevel)
    if ($LASTEXITCODE -ne 0 -or -not $root) { throw 'Unable to resolve repository root.' }
    return [string]$root
}

function Invoke-ChatpadGit {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git @Arguments)
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE" }
    return @($output)
}

function Get-ChatpadFileIdentity {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file does not exist: $Path" }
    $item = Get-Item -LiteralPath $Path
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return [pscustomobject]@{
        path = $Path.Replace('\', '/')
        size = [int64]$item.Length
        sha256 = $hash.Hash
        last_write_utc = $item.LastWriteTimeUtc.ToString('o')
    }
}

function Get-ChatpadRuntimeRepoIdentity {
    $root = Get-ChatpadRepoRoot
    Push-Location -LiteralPath $root
    try {
        $branch = @(Invoke-ChatpadGit -Arguments @('branch', '--show-current'))[0]
        $head = @(Invoke-ChatpadGit -Arguments @('rev-parse', 'HEAD'))[0]
        $parent = @(Invoke-ChatpadGit -Arguments @('rev-parse', 'HEAD^'))[0]
        $status = @(Invoke-ChatpadGit -Arguments @('status', '--short'))
        $porcelain = @(Invoke-ChatpadGit -Arguments @('status', '--porcelain=v2'))
        $upstream = ''
        $upstreamOutput = @(& git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null)
        if ($LASTEXITCODE -eq 0 -and $upstreamOutput.Count -gt 0) { $upstream = [string]$upstreamOutput[0] }
        $aheadBehind = ''
        if ($upstream) { $aheadBehind = @(Invoke-ChatpadGit -Arguments @('rev-list', '--left-right', '--count', 'HEAD...@{upstream}'))[0] -replace "`t", '/' }
        return [pscustomobject]@{
            repository_root = $root
            branch = $branch
            head = $head
            parent = $parent
            upstream = $upstream
            ahead_behind = $aheadBehind
            status_short_count = $status.Count
            porcelain_v2_count = $porcelain.Count
            clean = ($status.Count -eq 0 -and $porcelain.Count -eq 0)
        }
    } finally {
        Pop-Location
    }
}

function Assert-ChatpadAcceptedRepoIdentity {
    param(
        [Parameter()][switch]$AllowScaffoldingBranch,
        [Parameter()][switch]$RequireClean = $true
    )
    $identity = Get-ChatpadRuntimeRepoIdentity
    $allowedBranches = @($script:AcceptedStartBranch)
    if ($AllowScaffoldingBranch) { $allowedBranches += $script:AcceptedBranch }
    if ($allowedBranches -notcontains $identity.branch) { throw "Wrong branch: $($identity.branch)" }
    if ($identity.head -ne $script:AcceptedCommit) { throw "Wrong accepted commit: $($identity.head)" }
    if ($identity.parent -ne $script:AcceptedParent) { throw "Wrong accepted parent: $($identity.parent)" }
    if ($RequireClean -and -not $identity.clean) { throw 'Repository is not clean.' }
    return $identity
}

function Read-ChatpadJson {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "JSON file missing: $Path" }
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function New-ChatpadRuntimeResult {
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][bool]$Passed,
        [Parameter()][string]$Reason = '',
        [Parameter()][object]$Data = $null
    )
    [pscustomobject]@{
        check = $Check
        result = $(if ($Passed) { 'PASS' } else { 'FAIL' })
        reason = $Reason
        data = $Data
    }
}

function Assert-ChatpadPlanAuthorization {
    param(
        [Parameter()][switch]$ExecuteAuthorizedRuntimeStep,
        [Parameter()][string]$EvidenceDirectory,
        [Parameter()][string]$TargetInstanceId,
        [Parameter()][string]$ApprovedOperationId
    )
    if (-not $ExecuteAuthorizedRuntimeStep) { throw 'Execution rejected: mutating runtime steps require -ExecuteAuthorizedRuntimeStep.' }
    if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) { throw 'Execution rejected: evidence directory is required.' }
    if ([string]::IsNullOrWhiteSpace($TargetInstanceId)) { throw 'Execution rejected: exact target instance ID is required.' }
    if ([string]::IsNullOrWhiteSpace($ApprovedOperationId)) { throw 'Execution rejected: approved operation ID is required.' }
    return $true
}

function Test-ChatpadTargetSelectionContract {
    param(
        [Parameter(Mandatory)][object[]]$Candidates,
        [Parameter(Mandatory)]$Contract
    )
    if ($Candidates.Count -eq 0) { throw 'No candidate devices found.' }
    if ($Candidates.Count -ne 1) { throw 'More than one unresolved candidate device found.' }
    $candidate = $Candidates[0]
    $required = @('hardware_id','compatible_id','class_guid','instance_id','parent_id','container_id','current_inf','current_service','vendor_id','product_id')
    foreach ($field in $required) {
        if ([string]::IsNullOrWhiteSpace([string]$candidate.$field)) { throw "Target proof is incomplete: $field is missing." }
        if ([string]$candidate.$field -ne [string]$Contract.$field) { throw "Target identity mismatch for $field." }
    }
    if ([string]::IsNullOrWhiteSpace([string]$candidate.friendly_name)) { throw 'Friendly name may be absent, but target proof fields must still pass.' }
    return New-ChatpadRuntimeResult -Check 'target-selection' -Passed $true -Data $candidate
}

function Test-ChatpadRollbackContract {
    param([Parameter(Mandatory)]$State)
    $required = @('instance_id','previous_driver_inf','previous_provider','previous_service','rollback_source','restore_commands','recovery_path')
    foreach ($field in $required) {
        if ($null -eq $State.$field -or [string]::IsNullOrWhiteSpace([string]$State.$field)) { throw "Rollback readiness failed: $field is missing." }
    }
    if (@($State.restore_commands).Count -eq 0) { throw 'Rollback readiness failed: restore commands are missing.' }
    return New-ChatpadRuntimeResult -Check 'rollback-readiness' -Passed $true -Data $State
}

function Test-ChatpadPackageContract {
    param(
        [Parameter(Mandatory)]$Package,
        [Parameter(Mandatory)]$Approved
    )
    if ([string]$Package.architecture -ne [string]$Approved.architecture) { throw 'Package architecture mismatch.' }
    if ([bool]$Approved.signature_required -and -not [bool]$Package.signature_valid) { throw 'Package is unsigned or signature-invalid while signing is required.' }
    if ([string]$Package.sys_sha256 -ne [string]$Approved.sys_sha256) { throw 'SYS hash does not match the approved binary identity.' }
    if ([string]$Package.inf_name -ne [string]$Approved.inf_name) { throw 'INF identity mismatch.' }
    $packageIds = @($Package.hardware_ids | Sort-Object)
    $approvedIds = @($Approved.hardware_ids | Sort-Object)
    if (($packageIds -join "`n") -ne ($approvedIds -join "`n")) { throw 'Package hardware-ID match set differs from the approved target contract.' }
    $unauthorized = @($Package.files | Where-Object { @($Approved.files) -notcontains $_ })
    if ($unauthorized.Count -gt 0) { throw "Package contains unauthorized files: $($unauthorized -join ', ')" }
    return New-ChatpadRuntimeResult -Check 'package-validation' -Passed $true -Data $Package
}

function Test-ChatpadSigningContract {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][ValidateSet('LocalTestCertificate','TrustedInternalCertificate','AttestationOrProduction')]$Method
    )
    if ($Method -eq 'LocalTestCertificate') {
        if (-not [bool]$State.test_signing_expected) { throw 'Local test certificate method requires approved test-signing plan.' }
        if ([bool]$State.secure_boot_enabled) { throw 'Secure Boot must be explicitly planned for local test-signing; current plan is incompatible.' }
    }
    if ([bool]$State.hvci_enabled -and -not [bool]$State.hvci_compatible_signature) { throw 'HVCI is incompatible with the selected signing state.' }
    if ([string]::IsNullOrWhiteSpace([string]$State.certificate_identity_plan)) { throw 'Certificate identity plan is missing.' }
    return New-ChatpadRuntimeResult -Check 'signing-readiness' -Passed $true -Data $State
}

function Test-ChatpadEvidenceDirectoryContract {
    param([Parameter(Mandatory)]$DirectoryState)
    if (-not [bool]$DirectoryState.exists) { throw 'Evidence directory is missing.' }
    if ([bool]$DirectoryState.stale) { throw 'Evidence directory is stale.' }
    if ([bool]$DirectoryState.session_id_reused) { throw 'Runtime session ID is reused.' }
    if ([bool]$DirectoryState.outside_repo_or_approved_root) { throw 'Evidence directory is outside the approved location.' }
    return New-ChatpadRuntimeResult -Check 'evidence-directory' -Passed $true -Data $DirectoryState
}

function Test-ChatpadWppPlanContract {
    param([Parameter(Mandatory)]$Plan)
    if ([string]$Plan.provider_guid -ne $script:AcceptedProviderGuid) { throw 'Trace provider GUID is not the accepted WPP provider.' }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.output_path)) { throw 'WPP output path is missing.' }
    if ([bool]$Plan.reuses_stale_output) { throw 'WPP plan reuses a stale trace output.' }
    return New-ChatpadRuntimeResult -Check 'wpp-plan' -Passed $true -Data $Plan
}

function Test-ChatpadPostTestReconciliationContract {
    param([Parameter(Mandatory)]$State)
    $allowed = @('intended-test-state','restored-baseline')
    if ($allowed -notcontains [string]$State.final_state) { throw 'Post-test state is neither intended test state nor restored baseline.' }
    if (-not [bool]$State.pre_snapshot_present) { throw 'Missing pre-test snapshot.' }
    if (-not [bool]$State.rollback_plan_present) { throw 'Missing rollback plan.' }
    return New-ChatpadRuntimeResult -Check 'post-test-reconciliation' -Passed $true -Data $State
}

function New-ChatpadRenderedCommand {
    param(
        [Parameter(Mandatory)][string]$OperationId,
        [Parameter(Mandatory)][string]$Command,
        [Parameter()][string]$Requires = 'future explicit authorization'
    )
    [pscustomobject]@{
        operation_id = $OperationId
        command = $Command
        execution_state = 'planned-not-executed'
        requires = $Requires
    }
}

Export-ModuleMember -Function *-Chatpad*
