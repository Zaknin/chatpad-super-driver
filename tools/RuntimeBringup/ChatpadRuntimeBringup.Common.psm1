Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ReadinessBranch = 'feature/runtime-bringup-readiness-remediation'
$script:PriorReadinessBranch = 'feature/runtime-bringup-readiness-scaffolding'
$script:AcceptedBaselineCommit = 'f49b5cbe9e6bba423cfb59313dbdc9be92c785ca'
$script:StartingReadinessCommit = 'b9990d287bee6916cc5bb4e6b7f194ee579c7fbb'
$script:AcceptedBaselineParent = '38d434e8f7c815f609834f79315600aa73969639'
$script:AcceptedProviderGuid = '{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}'
$script:AcceptedManifestPath = 'docs/evidence/runtime-instrumentation-implementation-manifest.json'
$script:AcceptedManifestSize = 28088
$script:AcceptedManifestSha256 = '35E97D8529C09F107A35A4024FA715F4CA0172F1890FD7DBB27EFEBD8DAB1088'
$script:AcceptedDebugSysPath = 'artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys'
$script:AcceptedDebugSysSize = 68096
$script:AcceptedDebugSysSha256 = 'E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'
$script:AcceptedReleaseSysPath = 'artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys'
$script:AcceptedReleaseSysSize = 40960
$script:AcceptedReleaseSysSha256 = 'A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404'

$script:KnownStopConditionIds = @(
    'target-identity-ambiguous',
    'current-driver-unidentified',
    'rollback-source-unavailable',
    'repository-or-binary-identity-wrong',
    'signing-identity-wrong',
    'package-validation-failed',
    'windows-rejects-signature',
    'wrong-device-binds',
    'unrelated-device-changed',
    'driver-service-fails-unexpectedly',
    'unexpected-code-integrity-error',
    'unexpected-setupapi-match',
    'device-disappears-without-recovery-path',
    'input-behavior-unstable',
    'unplanned-reboot-required',
    'trace-provider-wrong',
    'runtime-evidence-write-failed',
    'command-differs-from-approved-plan',
    'prerequisite-changed-after-approval',
    'rollback-cannot-be-guaranteed'
)

function Get-ChatpadRuntimeConstants {
    [pscustomobject]@{
        readiness_branch = $script:ReadinessBranch
        prior_readiness_branch = $script:PriorReadinessBranch
        accepted_baseline_commit = $script:AcceptedBaselineCommit
        starting_readiness_commit = $script:StartingReadinessCommit
        accepted_baseline_parent = $script:AcceptedBaselineParent
        accepted_provider_guid = $script:AcceptedProviderGuid
        accepted_manifest_path = $script:AcceptedManifestPath
        accepted_manifest_size = $script:AcceptedManifestSize
        accepted_manifest_sha256 = $script:AcceptedManifestSha256
        accepted_debug_sys_path = $script:AcceptedDebugSysPath
        accepted_debug_sys_size = $script:AcceptedDebugSysSize
        accepted_debug_sys_sha256 = $script:AcceptedDebugSysSha256
        accepted_release_sys_path = $script:AcceptedReleaseSysPath
        accepted_release_sys_size = $script:AcceptedReleaseSysSize
        accepted_release_sys_sha256 = $script:AcceptedReleaseSysSha256
        stop_condition_ids = @($script:KnownStopConditionIds)
    }
}

function Get-ChatpadRepoRoot {
    $root = @(& git rev-parse --show-toplevel)
    if ($LASTEXITCODE -ne 0 -or $root.Count -ne 1 -or [string]::IsNullOrWhiteSpace($root[0])) {
        throw 'Unable to resolve repository root.'
    }
    return [string]$root[0]
}

function Invoke-ChatpadGit {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = @(& git @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
    return @($output)
}

function Read-ChatpadJson {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JSON file missing: $Path"
    }
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Assert-ChatpadFullCommit {
    param(
        [Parameter(Mandatory)][string]$Value,
        [Parameter(Mandatory)][string]$Name
    )
    if ($Value -notmatch '^[0-9a-f]{40}$') {
        throw "$Name must be a full lowercase 40-character commit hash."
    }
}

function Assert-ChatpadScalar {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$Name,
        [switch]$AllowQuotes,
        [switch]$AllowWildcards
    )
    if ($Value -is [array]) { throw "$Name must be a scalar value." }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { throw "$Name is required." }
    if ($text.IndexOf([char]0) -ge 0) { throw "$Name contains NUL." }
    if ($text -match "[`r`n]") { throw "$Name contains a line break." }
    if ($text -match '[\u202A-\u202E\u2066-\u2069\u200B\u200C\u200D\uFEFF]') { throw "$Name contains an unsupported Unicode control character." }
    foreach ($ch in $text.ToCharArray()) {
        $code = [int][char]$ch
        if ($code -lt 32 -and $ch -notin @([char]9)) { throw "$Name contains control character U+$($code.ToString('X4'))." }
    }
    if (-not $AllowQuotes -and $text -match '"') { throw "$Name contains an unsupported double quote." }
    if (-not $AllowWildcards -and $text -match '[\*\?]') { throw "$Name must not contain wildcards." }
    if ($Name -in @('Argument','WorkingDirectory','TargetInstanceId') -and $text -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "$Name contains path traversal."
    }
    return $text
}

function Test-ChatpadPathContained {
    param(
        [Parameter(Mandatory)][object]$Root,
        [Parameter(Mandatory)][object]$Candidate,
        [switch]$AllowRoot
    )
    if ($Root -is [array] -or $Candidate -is [array]) { return $false }
    try {
        $rootFull = [IO.Path]::GetFullPath([string]$Root).TrimEnd('\','/')
        $candidateFull = [IO.Path]::GetFullPath([string]$Candidate).TrimEnd('\','/')
    } catch {
        return $false
    }
    if ($AllowRoot -and $candidateFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $candidateFull.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function ConvertTo-ChatpadDisplayArgument {
    param([Parameter(Mandatory)][string]$Value)
    return "'" + ($Value -replace "'", "''") + "'"
}

function New-ChatpadOperationPlan {
    param(
        [Parameter(Mandatory)][object]$OperationId,
        [Parameter(Mandatory)][object]$Executable,
        [Parameter(Mandatory)][object[]]$Arguments,
        [Parameter()][object]$WorkingDirectory = '<APPROVED_RUNTIME_WORKING_DIRECTORY>',
        [Parameter()][object]$TargetInstanceId = '',
        [Parameter()][string[]]$InputArtifactIds = @(),
        [Parameter()][string[]]$PrerequisiteResultIds = @(),
        [Parameter(Mandatory)][string[]]$StopConditionIds,
        [Parameter()][int[]]$ExpectedExitCodes = @(0),
        [Parameter(Mandatory)][ValidateSet('offline-read-only','live-host-read-only','live-device-query','broad-host-mutation','exact-target-mutation','render-only','blocked')]
        [string]$MutationClassification,
        [Parameter()][bool]$RequiresAuthorization = $true,
        [Parameter()][ValidateSet('planned-not-executed','blocked','skipped-by-authorization')]
        [string]$ExecutionStatus = 'planned-not-executed'
    )
    $safeOperationId = Assert-ChatpadScalar $OperationId 'OperationId'
    $safeExecutable = Assert-ChatpadScalar $Executable 'Executable'
    $safeWorkingDirectory = Assert-ChatpadScalar $WorkingDirectory 'WorkingDirectory' -AllowQuotes -AllowWildcards
    $safeArguments = @()
    foreach ($arg in @($Arguments)) {
        $safeArguments += Assert-ChatpadScalar $arg 'Argument' -AllowQuotes -AllowWildcards
    }
    if ($MutationClassification -eq 'exact-target-mutation') {
        $safeTarget = Assert-ChatpadScalar $TargetInstanceId 'TargetInstanceId'
    } elseif (-not [string]::IsNullOrWhiteSpace($TargetInstanceId)) {
        $safeTarget = Assert-ChatpadScalar $TargetInstanceId 'TargetInstanceId'
    } else {
        $safeTarget = ''
    }
    Assert-ChatpadStopConditionIds -StopConditionIds $StopConditionIds | Out-Null
    [pscustomobject]@{
        schema_version = 'chatpad-structured-operation-v1'
        operation_id = $safeOperationId
        executable = $safeExecutable
        arguments = @($safeArguments)
        working_directory = $safeWorkingDirectory
        target_instance_id = $safeTarget
        input_artifact_ids = @($InputArtifactIds)
        prerequisite_result_ids = @($PrerequisiteResultIds)
        stop_condition_ids = @($StopConditionIds)
        expected_exit_codes = @($ExpectedExitCodes)
        mutation_classification = $MutationClassification
        requires_authorization = $RequiresAuthorization
        execution_status = $ExecutionStatus
        command_display = ((ConvertTo-ChatpadDisplayArgument -Value $safeExecutable) + ' ' + (($safeArguments | ForEach-Object { ConvertTo-ChatpadDisplayArgument -Value $_ }) -join ' ')).Trim()
        display_is_execution_evidence = $false
        launch_contract = 'Future execution, if ever authorized, must use System.Diagnostics.ProcessStartInfo.ArgumentList; rendered display text must not be reparsed by a shell.'
    }
}

function Assert-ChatpadStopConditionIds {
    param([Parameter(Mandatory)][string[]]$StopConditionIds)
    if (@($StopConditionIds).Count -eq 0) { throw 'At least one stop-condition ID is required.' }
    foreach ($id in $StopConditionIds) {
        if ($script:KnownStopConditionIds -notcontains $id) { throw "Unknown stop-condition ID: $id" }
    }
    return $true
}

function New-ChatpadRuntimeCheckResult {
    param(
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('PASS','FAIL','BLOCKED')]
        [string]$Result,
        [Parameter()][string]$Reason = '',
        [Parameter()][string[]]$StopConditionIds = @(),
        [Parameter()][object]$Data = $null
    )
    if ($Result -ne 'PASS') { Assert-ChatpadStopConditionIds -StopConditionIds $StopConditionIds | Out-Null }
    [pscustomobject]@{
        schema_version = 'chatpad-runtime-check-result-v2'
        check = $Check
        result = $Result
        reason = $Reason
        stop_condition_ids = @($StopConditionIds)
        data = $Data
    }
}

function Get-ChatpadFileIdentity {
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$RejectReparsePoint
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file does not exist: $Path" }
    $item = Get-Item -LiteralPath $Path -Force
    if ($RejectReparsePoint -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw "Reparse point is not allowed: $Path"
    }
    $hash = Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256
    [pscustomobject]@{
        path = $Path.Replace('\', '/')
        full_name = $item.FullName
        size = [int64]$item.Length
        sha256 = $hash.Hash
        attributes = [string]$item.Attributes
        last_write_utc = $item.LastWriteTimeUtc.ToString('o')
    }
}

function Get-ChatpadPeIdentity {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
    if ($bytes.Length -lt 0x100 -or [Text.Encoding]::ASCII.GetString($bytes, 0, 2) -ne 'MZ') { throw "Not an MZ executable: $Path" }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    if ($peOffset -lt 0 -or $peOffset + 0x18 -ge $bytes.Length) { throw "Invalid PE header offset: $Path" }
    if ([Text.Encoding]::ASCII.GetString($bytes, $peOffset, 4) -ne "PE`0`0") { throw "Missing PE signature: $Path" }
    $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    $optionalOffset = $peOffset + 0x18
    $magic = [BitConverter]::ToUInt16($bytes, $optionalOffset)
    $subsystem = [BitConverter]::ToUInt16($bytes, $optionalOffset + 68)
    $certSize = [BitConverter]::ToUInt32($bytes, $optionalOffset + 112 + (4 * 8) + 4)
    [pscustomobject]@{
        machine = ('0x{0:X4}' -f $machine)
        machine_name = $(if ($machine -eq 0x8664) { 'x64' } else { 'unexpected' })
        optional_header_magic = ('0x{0:X4}' -f $magic)
        subsystem = $subsystem
        subsystem_name = $(if ($subsystem -eq 1) { 'Native' } else { 'unexpected' })
        authenticode_state = $(if ($certSize -eq 0) { 'Unsigned' } else { 'EmbeddedSignaturePresent' })
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
        $untracked = @(Invoke-ChatpadGit -Arguments @('ls-files', '--others', '--exclude-standard'))
        $staged = @(Invoke-ChatpadGit -Arguments @('diff', '--cached', '--name-only'))
        $unstaged = @(Invoke-ChatpadGit -Arguments @('diff', '--name-only'))
        $upstream = ''
        $upstreamOutput = @(& git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null)
        if ($LASTEXITCODE -eq 0 -and $upstreamOutput.Count -gt 0) { $upstream = [string]$upstreamOutput[0] }
        $aheadBehind = ''
        if ($upstream) { $aheadBehind = @(Invoke-ChatpadGit -Arguments @('rev-list', '--left-right', '--count', 'HEAD...@{upstream}'))[0] -replace "`t", '/' }
        [pscustomobject]@{
            repository_root = $root
            branch = $branch
            head = $head
            parent = $parent
            upstream = $upstream
            ahead_behind = $aheadBehind
            status_short_count = $status.Count
            porcelain_v2_count = $porcelain.Count
            staged_count = $staged.Count
            unstaged_count = $unstaged.Count
            untracked_nonignored_count = $untracked.Count
            clean = ($status.Count -eq 0 -and $porcelain.Count -eq 0 -and $staged.Count -eq 0 -and $unstaged.Count -eq 0 -and $untracked.Count -eq 0)
        }
    } finally {
        Pop-Location
    }
}

function Test-ChatpadRepositoryIdentityObject {
    param([Parameter(Mandatory)]$State)
    $failures = @()
    foreach ($name in @('approved_readiness_commit','accepted_baseline_commit','current_head')) {
        try { Assert-ChatpadFullCommit -Value ([string]$State.$name) -Name $name } catch { $failures += $_.Exception.Message }
    }
    if ([string]$State.current_branch -ne [string]$State.approved_readiness_branch) { $failures += 'Current branch does not match approved readiness branch.' }
    if ([string]$State.current_head -ne [string]$State.approved_readiness_commit) { $failures += 'Current HEAD does not match approved readiness commit.' }
    if ([string]$State.accepted_baseline_commit -ne $script:AcceptedBaselineCommit) { $failures += 'Accepted baseline commit mismatch.' }
    if ([int]$State.staged_count -ne 0) { $failures += 'Index is dirty.' }
    if ([int]$State.unstaged_count -ne 0) { $failures += 'Worktree is dirty.' }
    if ([int]$State.untracked_nonignored_count -ne 0) { $failures += 'Unexpected non-ignored untracked files exist.' }
    if ([bool]$State.detached_head) { $failures += 'Detached HEAD is not allowed.' }
    if ([bool]$State.alternate_repository_root) { $failures += 'Alternate repository root is not approved.' }
    if (-not [bool]$State.accepted_baseline_is_ancestor) { $failures += 'Accepted baseline is not an ancestor of current HEAD.' }
    if ([int]$State.accepted_manifest_size -ne $script:AcceptedManifestSize -or [string]$State.accepted_manifest_sha256 -ne $script:AcceptedManifestSha256) { $failures += 'Accepted manifest identity mismatch.' }
    if ([int]$State.debug_sys_size -ne $script:AcceptedDebugSysSize -or [string]$State.debug_sys_sha256 -ne $script:AcceptedDebugSysSha256) { $failures += 'Debug SYS identity mismatch.' }
    if ([int]$State.release_sys_size -ne $script:AcceptedReleaseSysSize -or [string]$State.release_sys_sha256 -ne $script:AcceptedReleaseSysSha256) { $failures += 'Release SYS identity mismatch.' }
    if ([string]$State.debug_pe_machine -ne 'x64' -or [string]$State.release_pe_machine -ne 'x64') { $failures += 'Unexpected PE machine.' }
    if ([string]$State.debug_pe_subsystem -ne 'Native' -or [string]$State.release_pe_subsystem -ne 'Native') { $failures += 'Unexpected PE subsystem.' }
    if ([string]$State.debug_signature_state -ne 'Unsigned' -or [string]$State.release_signature_state -ne 'Unsigned') { $failures += 'Unexpected signature state.' }
    if ([bool]$State.binary_reparse_point -or [bool]$State.manifest_reparse_point) { $failures += 'Reparse-point identity input is not allowed.' }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'repository-identity' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('repository-or-binary-identity-wrong')
    }
    return New-ChatpadRuntimeCheckResult -Check 'repository-identity' -Result PASS -Data $State
}

function Test-ChatpadCurrentRepositoryIdentity {
    param(
        [Parameter(Mandatory)][string]$ApprovedReadinessCommit,
        [Parameter()][string]$ApprovedReadinessBranch = $script:ReadinessBranch,
        [Parameter()][string]$AcceptedBaselineCommit = $script:AcceptedBaselineCommit,
        [Parameter()][string]$ApprovedRepositoryRoot = 'C:\Dev\chatpad-super-driver'
    )
    Assert-ChatpadFullCommit -Value $ApprovedReadinessCommit -Name 'ApprovedReadinessCommit'
    Assert-ChatpadFullCommit -Value $AcceptedBaselineCommit -Name 'AcceptedBaselineCommit'
    $repo = Get-ChatpadRuntimeRepoIdentity
    $root = $repo.repository_root
    $manifest = Get-ChatpadFileIdentity (Join-Path $root $script:AcceptedManifestPath) -RejectReparsePoint
    $debug = Get-ChatpadFileIdentity (Join-Path $root $script:AcceptedDebugSysPath) -RejectReparsePoint
    $release = Get-ChatpadFileIdentity (Join-Path $root $script:AcceptedReleaseSysPath) -RejectReparsePoint
    $debugPe = Get-ChatpadPeIdentity $debug.full_name
    $releasePe = Get-ChatpadPeIdentity $release.full_name
    & git -C $root merge-base --is-ancestor $AcceptedBaselineCommit HEAD
    $acceptedBaselineIsAncestor = ($LASTEXITCODE -eq 0)
    $state = [pscustomobject]@{
        approved_readiness_branch = $ApprovedReadinessBranch
        approved_readiness_commit = $ApprovedReadinessCommit
        accepted_baseline_commit = $AcceptedBaselineCommit
        current_branch = $repo.branch
        current_head = $repo.head
        current_parent = $repo.parent
        staged_count = $repo.staged_count
        unstaged_count = $repo.unstaged_count
        untracked_nonignored_count = $repo.untracked_nonignored_count
        detached_head = [string]::IsNullOrWhiteSpace($repo.branch)
        alternate_repository_root = -not (([IO.Path]::GetFullPath($root) -replace '^\\\\\?\\','').Equals(([IO.Path]::GetFullPath($ApprovedRepositoryRoot) -replace '^\\\\\?\\',''), [StringComparison]::OrdinalIgnoreCase))
        accepted_baseline_is_ancestor = $acceptedBaselineIsAncestor
        accepted_manifest_size = $manifest.size
        accepted_manifest_sha256 = $manifest.sha256
        debug_sys_size = $debug.size
        debug_sys_sha256 = $debug.sha256
        release_sys_size = $release.size
        release_sys_sha256 = $release.sha256
        debug_pe_machine = $debugPe.machine_name
        release_pe_machine = $releasePe.machine_name
        debug_pe_subsystem = $debugPe.subsystem_name
        release_pe_subsystem = $releasePe.subsystem_name
        debug_signature_state = $debugPe.authenticode_state
        release_signature_state = $releasePe.authenticode_state
        binary_reparse_point = $false
        manifest_reparse_point = $false
        accepted_baseline_path = $script:AcceptedManifestPath
        debug_binary_path = $script:AcceptedDebugSysPath
        release_binary_path = $script:AcceptedReleaseSysPath
    }
    Test-ChatpadRepositoryIdentityObject -State $state
}

function Test-ChatpadTargetSelectionContract {
    param([Parameter(Mandatory)]$Inventory, [Parameter(Mandatory)]$Contract)
    $failures = @()
    if ([string]$Inventory.source_classification -notin @('synthetic','live')) { $failures += 'Inventory source classification is missing or invalid.' }
    if ([string]$Inventory.source_classification -eq 'synthetic' -and [bool]$Inventory.claims_live) { $failures += 'Synthetic inventory is represented as live.' }
    if ([datetime]$Inventory.captured_utc -lt [datetime]$Contract.min_capture_utc) { $failures += 'Inventory is stale.' }
    $candidates = @($Inventory.candidates)
    if ($candidates.Count -eq 0) { $failures += 'No candidate devices found.' }
    if ($candidates.Count -ne 1) { $failures += 'Candidate set is not exactly one unresolved device.' }
    $ids = @($candidates | ForEach-Object { [string]$_.instance_id })
    if (@($ids | Sort-Object -Unique).Count -ne $ids.Count) { $failures += 'Duplicate device instance identity.' }
    if ($candidates.Count -eq 1) {
        $candidate = $candidates[0]
        foreach ($field in @('instance_id','class_guid','class_name','parent_id','container_id','bus_topology','current_inf','current_service','current_provider','vendor_id','product_id')) {
            if ([string]::IsNullOrWhiteSpace([string]$candidate.$field)) { $failures += "Candidate missing $field." }
            elseif ([string]$candidate.$field -ne [string]$Contract.$field) { $failures += "Candidate $field mismatch." }
        }
        $actualHardware = @($candidate.hardware_ids | Sort-Object)
        $expectedHardware = @($Contract.hardware_ids | Sort-Object)
        if (($actualHardware -join "`n") -ne ($expectedHardware -join "`n")) { $failures += 'Hardware-ID set mismatch.' }
        $actualCompatible = @($candidate.compatible_ids | Sort-Object)
        $expectedCompatible = @($Contract.compatible_ids | Sort-Object)
        if (($actualCompatible -join "`n") -ne ($expectedCompatible -join "`n")) { $failures += 'Compatible-ID set mismatch.' }
        if (($actualHardware + $actualCompatible + @($candidate.instance_id)) -match '[\*\?]') { $failures += 'Wildcard identity is not allowed.' }
        if ([string]$candidate.selection_basis -eq 'friendly-name-only') { $failures += 'Friendly-name-only selection is not allowed.' }
    }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'target-selection' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('target-identity-ambiguous')
    }
    return New-ChatpadRuntimeCheckResult -Check 'target-selection' -Result PASS -Data $candidates[0]
}

function Test-ChatpadDriverStateContract {
    param([Parameter(Mandatory)]$State)
    $required = @('instance_id','hardware_ids','compatible_ids','class_guid','class_name','parent_id','container_id','bus_topology','current_inf','original_inf_name','provider','driver_version','driver_date','service','package_identity','recovery_source','driver_stack_identities','service_state','collected_utc','host_id','session_id','field_provenance','source_classification','command_result_id')
    $missing = @()
    foreach ($field in $required) {
        if ($null -eq $State.$field -or ([string]$State.$field).Trim().Length -eq 0) { $missing += $field }
    }
    if ($missing.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'current-driver-state' -Result FAIL -Reason "Missing fields: $($missing -join ', ')" -StopConditionIds @('current-driver-unidentified')
    }
    return New-ChatpadRuntimeCheckResult -Check 'current-driver-state' -Result PASS -Data $State
}

function Test-ChatpadRollbackContract {
    param([Parameter(Mandatory)]$State)
    $driver = Test-ChatpadDriverStateContract -State $State.pre_test_snapshot
    $failures = @()
    if ($driver.result -ne 'PASS') { $failures += 'Pre-test snapshot is incomplete.' }
    foreach ($field in @('target_instance_id','previous_package_identity','previous_provider','previous_version','previous_service','recovery_source_path','recovery_source_sha256','test_package_identity','evidence_directory','session_id','emergency_recovery.safe_mode','emergency_recovery.winre','emergency_recovery.input_device')) {
        $value = $State
        foreach ($part in $field.Split('.')) { if ($null -ne $value) { $value = $value.$part } }
        if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) { $failures += "Missing $field." }
    }
    foreach ($op in @($State.rollback_operations)) {
        if ([string]$op.target_instance_id -ne [string]$State.target_instance_id) { $failures += 'Rollback operation targets a different instance.' }
        if ([string]$op.mutation_classification -notin @('exact-target-mutation','blocked')) { $failures += 'Rollback operation is not exact-target classified.' }
        if (@($op.arguments) -match '[\*\?]') { $failures += 'Rollback operation contains a wildcard.' }
    }
    if (@($State.rollback_operations).Count -eq 0) { $failures += 'Rollback operations are missing.' }
    if ([bool]$State.unplanned_reboot_required) { $failures += 'Unplanned reboot requirement is present.' }
    if ([bool]$State.stale_snapshot) { $failures += 'Rollback snapshot is stale.' }
    if ([string]$State.snapshot_session_id -ne [string]$State.session_id) { $failures += 'Snapshot belongs to another session.' }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'rollback-readiness' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('rollback-source-unavailable','rollback-cannot-be-guaranteed')
    }
    return New-ChatpadRuntimeCheckResult -Check 'rollback-readiness' -Result PASS -Data $State
}

function Read-ChatpadInfModel {
    param([Parameter(Mandatory)][string]$InfPath)
    if (-not (Test-Path -LiteralPath $InfPath -PathType Leaf)) { throw "INF missing: $InfPath" }
    $content = Get-Content -LiteralPath $InfPath -Raw
    if ($content -match '[\u0000]') { throw 'INF contains NUL.' }
    $sections = @{}
    $current = ''
    foreach ($line in ($content -split "`r?`n")) {
        $trim = ($line -replace ';.*$','').Trim()
        if ($trim -eq '') { continue }
        if ($trim -match '^\[(.+)\]$') { $current = $Matches[1]; if (-not $sections.ContainsKey($current)) { $sections[$current] = @() } else { $sections[$current] += '__DUPLICATE_SECTION__' }; continue }
        if ($current) { $sections[$current] += $trim }
    }
    [pscustomobject]@{ path=$InfPath; content=$content; sections=$sections }
}

function Test-ChatpadPackageContract {
    param([Parameter(Mandatory)]$Package)
    $failures = @()
    $root = [string]$Package.package_root
    $inf = [string]$Package.inf_path
    if (-not [IO.Path]::IsPathRooted($root)) { $failures += 'Package root must be absolute.' }
    if (-not [IO.Path]::IsPathRooted($inf)) { $failures += 'INF path must be absolute.' }
    if (-not (Test-ChatpadPathContained -Root $root -Candidate $inf)) { $failures += 'INF path escapes package root.' }
    try { $model = Read-ChatpadInfModel -InfPath $inf } catch { $failures += $_.Exception.Message; $model = $null }
    if ($model) {
        if (@($model.sections.Values | ForEach-Object { @($_) } | Where-Object { $_ -eq '__DUPLICATE_SECTION__' }).Count -gt 0) { $failures += 'Duplicate INF section detected.' }
        foreach ($required in @('Version','Manufacturer','DestinationDirs')) { if (-not $model.sections.ContainsKey($required)) { $failures += "Missing INF section [$required]." } }
        if ($model.sections.ContainsKey('Manufacturer')) {
            foreach ($manufacturerLine in @($model.sections['Manufacturer'])) {
                if ($manufacturerLine -match '^[^=]+=[^,]+$') { $failures += 'Undecorated manufacturer model section is not allowed.' }
            }
        }
        if (-not $model.sections.ContainsKey('Models.NTamd64')) { $failures += 'Decorated x64 model section [Models.NTamd64] is missing.' }
        if ($model.content -notmatch 'Provider\s*=\s*%ChatpadProvider%') { $failures += 'Provider mismatch.' }
        if ($model.content -notmatch 'DriverVer\s*=') { $failures += 'DriverVer missing.' }
        if ($model.content -notmatch 'CatalogFile\s*=') { $failures += 'CatalogFile missing.' }
        if ($model.content -notmatch 'NTamd64') { $failures += 'Architecture decoration NTamd64 missing.' }
        if ($model.content -match 'NTx86|NTarm|NTarm64') { $failures += 'Unexpected alternate architecture section.' }
        if ($model.content -match 'USB\\VID_[^&\s]+&PID_\*|USB\\Class_') { $failures += 'Broad or wildcard hardware binding detected.' }
        if ($model.content -notmatch [regex]::Escape([string]$Package.expected_hardware_id)) { $failures += 'Expected hardware ID missing.' }
        if ($model.content -notmatch [regex]::Escape([string]$Package.expected_service_binary)) { $failures += 'Expected service binary missing.' }
        if ($model.content -notmatch 'KmdfLibraryVersion') { $failures += 'KMDF declaration missing.' }
    }
    $allowed = @($Package.allowed_files)
    $actual = @(Get-ChildItem -LiteralPath $root -File -Recurse | ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\','/') -replace '\\','/' })
    foreach ($file in $actual) {
        if ($allowed -notcontains $file) { $failures += "Unauthorized package file: $file" }
        if ($file -match '(?i)\.(exe|dll|pfx|p12|pem|key|pvk|snk|cer|crt)$') { $failures += "Forbidden package file type: $file" }
        if ($file -match '\.\.') { $failures += "Package path traversal: $file" }
    }
    foreach ($file in $allowed) { if ($actual -notcontains $file) { $failures += "Allowed package file missing: $file" } }
    $sysPath = Join-Path $root ([string]$Package.sys_relative_path)
    if (-not (Test-Path -LiteralPath $sysPath -PathType Leaf)) { $failures += 'SYS file missing.' }
    else {
        $sysHash = (Get-FileHash -LiteralPath $sysPath -Algorithm SHA256).Hash
        if ($sysHash -ne [string]$Package.expected_sys_sha256) { $failures += 'SYS hash mismatch.' }
    }
    if ([bool]$Package.signature_required) {
        if (-not [bool]$Package.cat_present) { $failures += 'CAT is required but absent.' }
        if (-not [bool]$Package.signature_identity_present) { $failures += 'Signature identity is required but absent.' }
    }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'package-validation' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('package-validation-failed')
    }
    return New-ChatpadRuntimeCheckResult -Check 'package-validation' -Result PASS -Data $Package
}

function Test-ChatpadSigningContract {
    param([Parameter(Mandatory)]$State)
    $failures = @()
    foreach ($field in @('method','certificate_thumbprint','subject','issuer','trust_status','private_key_present','eku','valid_from_utc','valid_to_utc','timestamping_plan','sys_signature_state','cat_signature_state','test_signing_state','secure_boot_state','hvci_state','code_integrity_state','credential_scope','evidence_object_id')) {
        if ($null -eq $State.$field -or [string]::IsNullOrWhiteSpace([string]$State.$field)) { $failures += "Missing $field." }
    }
    if ([string]$State.trust_status -ne 'trusted') { $failures += 'Certificate is not trusted.' }
    if (-not [bool]$State.private_key_present) { $failures += 'Private key is missing.' }
    if (@($State.eku) -notcontains 'Code Signing') { $failures += 'Code Signing EKU is missing.' }
    $now = [datetime]$State.validation_time_utc
    if ($now -lt [datetime]$State.valid_from_utc -or $now -gt [datetime]$State.valid_to_utc) { $failures += 'Certificate validity window does not include validation time.' }
    if ([string]$State.sys_signature_state -ne 'signed' -or [string]$State.cat_signature_state -ne 'signed') { $failures += 'SYS and CAT signatures must be signed for selected method.' }
    if ([string]$State.method -eq 'LocalTestCertificate' -and [string]$State.credential_scope -ne 'local-test') { $failures += 'Local test must not use release credentials.' }
    if ([string]$State.method -eq 'LocalTestCertificate' -and [string]$State.test_signing_state -ne 'planned-enabled') { $failures += 'Local test certificate requires planned test-signing state.' }
    if ([string]$State.secure_boot_state -eq 'enabled' -and [string]$State.method -eq 'LocalTestCertificate') { $failures += 'Secure Boot is incompatible with this local test-signing plan.' }
    if ([string]$State.hvci_state -eq 'enabled-incompatible') { $failures += 'HVCI state is incompatible.' }
    if ([string]$State.timestamping_plan -eq 'missing') { $failures += 'Timestamping plan is missing.' }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'signing-readiness' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('signing-identity-wrong','windows-rejects-signature')
    }
    return New-ChatpadRuntimeCheckResult -Check 'signing-readiness' -Result PASS -Data $State
}

function Test-ChatpadHostStateContract {
    param([Parameter(Mandatory)]$State)
    $required = @('os_edition','os_version','os_build','architecture','is_administrator','powershell_version','system_time_utc','timezone','secure_boot','test_signing','code_integrity','hvci','device_guard','boot_configuration_id','wdk_tools','debugging_tools','required_commands','evidence_root_writable','evidence_root_contained','host_id','capture_timestamp_utc','fresh_until_utc','source_classification')
    $missing = @()
    foreach ($field in $required) { if ($null -eq $State.$field -or [string]::IsNullOrWhiteSpace([string]$State.$field)) { $missing += $field } }
    if ([datetime]$State.capture_timestamp_utc -gt [datetime]$State.fresh_until_utc) { $missing += 'Host capture freshness window invalid.' }
    if (-not [bool]$State.evidence_root_writable -or -not [bool]$State.evidence_root_contained) { $missing += 'Evidence root is not ready.' }
    if ($missing.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'host-preflight' -Result FAIL -Reason ($missing -join '; ') -StopConditionIds @('prerequisite-changed-after-approval','runtime-evidence-write-failed')
    }
    return New-ChatpadRuntimeCheckResult -Check 'host-preflight' -Result PASS -Data $State
}

function Test-ChatpadEvidenceDirectoryContract {
    param([Parameter(Mandatory)]$State)
    $failures = @()
    foreach ($field in @('approved_root','evidence_directory','session_id','source_classification')) {
        if ([string]::IsNullOrWhiteSpace([string]$State.$field)) { $failures += "Missing $field." }
    }
    if (-not [IO.Path]::IsPathRooted([string]$State.approved_root) -or -not [IO.Path]::IsPathRooted([string]$State.evidence_directory)) { $failures += 'Evidence paths must be absolute.' }
    if (-not (Test-ChatpadPathContained -Root $State.approved_root -Candidate $State.evidence_directory)) { $failures += 'Evidence directory escapes approved root.' }
    if ([string]$State.evidence_directory -match '\.\.') { $failures += 'Evidence directory contains traversal.' }
    foreach ($flag in @('exists_before_session','stale_session','session_id_reused','has_reparse_point','has_symlink_or_junction','is_unc_path','inside_repository','lock_exists')) {
        if ([bool]$State.$flag) { $failures += "$flag is not allowed." }
    }
    if ([string]$State.session_id -notmatch '^CHATPAD-[0-9]{8}T[0-9]{6}Z-[A-Z0-9]{6,}$') { $failures += 'Session ID format is invalid.' }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'evidence-directory' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('runtime-evidence-write-failed')
    }
    return New-ChatpadRuntimeCheckResult -Check 'evidence-directory' -Result PASS -Data $State
}

function Test-ChatpadWppPlanContract {
    param([Parameter(Mandatory)]$Plan)
    $failures = @()
    if ([string]$Plan.provider_guid -ne $script:AcceptedProviderGuid) { $failures += 'Trace provider GUID is not accepted.' }
    if ([string]$Plan.provider_guid -match '[\*\?]') { $failures += 'Wildcard provider is not allowed.' }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.session_name) -or [bool]$Plan.session_name_reused) { $failures += 'Trace session name is not unique.' }
    if ([bool]$Plan.output_exists -or [bool]$Plan.reuses_stale_output) { $failures += 'Trace output path is stale or already exists.' }
    if (-not [bool]$Plan.output_under_evidence_root) { $failures += 'Trace output escapes evidence root.' }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'wpp-plan' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('trace-provider-wrong','runtime-evidence-write-failed')
    }
    return New-ChatpadRuntimeCheckResult -Check 'wpp-plan' -Result PASS -Data $Plan
}

function Test-ChatpadEventLogPlanContract {
    param([Parameter(Mandatory)]$Plan)
    $failures = @()
    foreach ($channel in @('System','Microsoft-Windows-CodeIntegrity/Operational','Microsoft-Windows-Kernel-PnP/Configuration')) {
        if (@($Plan.required_channels) -notcontains $channel) { $failures += "Required channel missing: $channel" }
    }
    if ([string]$Plan.capture_phase -notin @('baseline','post-test')) { $failures += 'Capture phase must be baseline or post-test.' }
    if (-not [bool]$Plan.session_bound_time_window) { $failures += 'Time window is not session-bound.' }
    if (-not [bool]$Plan.outputs_fresh_and_contained) { $failures += 'Event-log outputs are not fresh and contained.' }
    if ([bool]$Plan.clears_logs -or [bool]$Plan.configures_channels) { $failures += 'Log clearing or channel configuration is forbidden.' }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'event-log-plan' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('runtime-evidence-write-failed')
    }
    return New-ChatpadRuntimeCheckResult -Check 'event-log-plan' -Result PASS -Data $Plan
}

function Test-ChatpadInstallPlanContract {
    param([Parameter(Mandatory)]$Plan)
    $requiredPasses = @('repository_identity','accepted_baseline_identity','package_validation','signing_readiness','host_preflight','target_selection','current_driver_capture','rollback_readiness','evidence_directory')
    $failures = @()
    foreach ($field in $requiredPasses) {
        if ([string]$Plan.$field -ne 'PASS') { $failures += "Prerequisite is not PASS: $field" }
    }
    if (-not [bool]$Plan.exact_instance_binding_available) { $failures += 'Exact-instance binding method is not implemented.' }
    foreach ($op in @($Plan.operations)) {
        if ([string]$op.mutation_classification -eq 'broad-host-mutation' -and [bool]$op.approved_as_target_specific) { $failures += 'Broad operation is incorrectly approved as target-specific.' }
        if (@($op.arguments) -match '[\*\?]') { $failures += 'Install operation contains wildcard.' }
    }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'install-plan' -Result BLOCKED -Reason ($failures -join '; ') -StopConditionIds @('command-differs-from-approved-plan','wrong-device-binds')
    }
    return New-ChatpadRuntimeCheckResult -Check 'install-plan' -Result PASS -Data $Plan
}

function Test-ChatpadPostTestReconciliationContract {
    param([Parameter(Mandatory)]$State)
    $failures = @()
    foreach ($field in @('approved_readiness_identity','accepted_baseline_identity','host_baseline','host_final','target_baseline','target_final','previous_driver','test_driver','service_state','package_state','boot_security_state','trace_state','event_log_evidence','executed_operations','rollback_operations','residual_packages','residual_services','unresolved_deviations','expected_mode')) {
        if ($null -eq $State.$field) { $failures += "Missing $field." }
    }
    $classification = [string]$State.final_classification
    if ($classification -notin @('approved-test-state','fully-restored-baseline','partial-rollback','unexplained-deviation','blocked-missing-evidence')) { $failures += 'Unknown final classification.' }
    if ($classification -in @('partial-rollback','unexplained-deviation','blocked-missing-evidence')) { $failures += "Final classification is not passable: $classification" }
    if ([string]$State.expected_mode -eq 'restored-baseline' -and $classification -ne 'fully-restored-baseline') { $failures += 'Expected restored baseline was not reached.' }
    if ([string]$State.expected_mode -eq 'test-state' -and $classification -ne 'approved-test-state') { $failures += 'Expected approved test state was not reached.' }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'post-test-reconciliation' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('rollback-cannot-be-guaranteed','prerequisite-changed-after-approval')
    }
    return New-ChatpadRuntimeCheckResult -Check 'post-test-reconciliation' -Result PASS -Data $State
}

function Test-ChatpadEvidenceDocumentContract {
    param([Parameter(Mandatory)]$Document)
    $failures = @()
    if ([string]$Document.schema_version -ne 'chatpad-runtime-evidence-schema-v2') { $failures += 'Evidence document schema mismatch.' }
    if ([string]$Document.session.session_id -notmatch '^CHATPAD-|^SYNTHETIC-') { $failures += 'Missing valid session ID.' }
    $artifactIds = @()
    foreach ($artifact in @($Document.artifacts)) {
        if ($artifactIds -contains [string]$artifact.id) { $failures += "Duplicate artifact ID: $($artifact.id)" }
        $artifactIds += [string]$artifact.id
        if ([string]$artifact.relative_path -match '(^/|^[A-Za-z]:|\\\\|\.\.)') { $failures += "Artifact path is not contained: $($artifact.relative_path)" }
        if ([string]$artifact.status -in @('executed','restored')) {
            if ($null -eq $artifact.byte_size -or [int64]$artifact.byte_size -lt 0) { $failures += "Produced artifact lacks size: $($artifact.id)" }
            if ([string]$artifact.sha256 -notmatch '^[A-Fa-f0-9]{64}$') { $failures += "Produced artifact lacks SHA-256: $($artifact.id)" }
        }
        if ([string]$artifact.evidence_classification -eq 'synthetic' -and [string]$Document.session.evidence_classification -eq 'live') { $failures += 'Synthetic artifact cannot satisfy live evidence.' }
    }
    foreach ($op in @($Document.operations)) {
        if ([string]$op.status -eq 'executed' -and $null -eq $op.command_result) { $failures += "Executed operation lacks command result: $($op.operation_id)" }
        if ([string]$op.status -eq 'rolled_back' -and [string]::IsNullOrWhiteSpace([string]$op.rollback_evidence_id)) { $failures += "Rolled-back operation lacks rollback evidence: $($op.operation_id)" }
        if ([string]$op.status -eq 'restored' -and [string]::IsNullOrWhiteSpace([string]$op.final_state_evidence_id)) { $failures += "Restored operation lacks final-state evidence: $($op.operation_id)" }
    }
    if ($failures.Count -gt 0) {
        return New-ChatpadRuntimeCheckResult -Check 'runtime-evidence-schema' -Result FAIL -Reason ($failures -join '; ') -StopConditionIds @('runtime-evidence-write-failed')
    }
    return New-ChatpadRuntimeCheckResult -Check 'runtime-evidence-schema' -Result PASS -Data $Document
}

Export-ModuleMember -Function *-Chatpad*
