[CmdletBinding()]
param([string]$ManifestPath = 'docs/evidence/runtime-bringup-readiness-manifest.json')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'RuntimeBringup\ChatpadRuntimeBringup.Common.psm1') -Force

$script:Assertions = 0
$script:Fixtures = 0
function Assert-True([bool]$Condition, [string]$Message) {
    $script:Assertions += 1
    if (-not $Condition) { throw $Message }
}
function Assert-Reject([scriptblock]$Block, [string]$Name) {
    $script:Fixtures += 1
    $rejected = $false
    try { & $Block | Out-Null } catch { $rejected = $true }
    Assert-True $rejected "Fixture accepted unexpectedly: $Name"
}

$contract = [pscustomobject]@{
    hardware_id = 'USB\VID_045E&PID_028E'
    compatible_id = 'USB\Class_FF&SubClass_5D&Prot_01'
    class_guid = '{d61ca365-5af4-4486-998b-9db4734c6ca3}'
    instance_id = 'USB\VID_045E&PID_028E\EXPECTED'
    parent_id = 'USB\ROOT_HUB30\EXPECTED'
    container_id = '{00000000-0000-0000-0000-000000000028}'
    current_inf = 'xusb22.inf'
    current_service = 'xusb22'
    vendor_id = '045E'
    product_id = '028E'
    friendly_name = 'Synthetic Chatpad Controller'
}
$candidate = $contract.PSObject.Copy()
Test-ChatpadTargetSelectionContract -Candidates @($candidate) -Contract $contract | Out-Null
Assert-True $true 'valid target fixture passes'
Assert-Reject { Test-ChatpadTargetSelectionContract -Candidates @() -Contract $contract } 'no matching device'
Assert-Reject { Test-ChatpadTargetSelectionContract -Candidates @($candidate, $candidate) -Contract $contract } 'multiple unresolved candidates'
$friendlyOnly = [pscustomobject]@{ friendly_name = 'Synthetic Chatpad Controller' }
Assert-Reject { Test-ChatpadTargetSelectionContract -Candidates @($friendlyOnly) -Contract $contract } 'friendly-name-only selection'
$wrongHardware = $candidate.PSObject.Copy(); $wrongHardware.hardware_id = 'USB\VID_0000&PID_0000'
Assert-Reject { Test-ChatpadTargetSelectionContract -Candidates @($wrongHardware) -Contract $contract } 'hardware-ID mismatch'
$wrongInstance = $candidate.PSObject.Copy(); $wrongInstance.instance_id = 'USB\VID_045E&PID_028E\WRONG'
Assert-Reject { Test-ChatpadTargetSelectionContract -Candidates @($wrongInstance) -Contract $contract } 'wrong device instance'
$wrongInf = $candidate.PSObject.Copy(); $wrongInf.current_inf = 'unexpected.inf'
Assert-Reject { Test-ChatpadTargetSelectionContract -Candidates @($wrongInf) -Contract $contract } 'unexpected current INF'

$rollback = [pscustomobject]@{
    instance_id = $contract.instance_id
    previous_driver_inf = 'xusb22.inf'
    previous_provider = 'Microsoft'
    previous_service = 'xusb22'
    rollback_source = 'DriverStore\FileRepository\xusb22.inf_amd64_synthetic'
    restore_commands = @('pnputil /add-driver xusb22.inf /install')
    recovery_path = 'Safe Mode or Windows Recovery Environment'
}
Test-ChatpadRollbackContract $rollback | Out-Null
foreach ($field in @('rollback_source','previous_driver_inf','instance_id','restore_commands','recovery_path')) {
    $bad = $rollback.PSObject.Copy(); $bad.$field = ''
    Assert-Reject { Test-ChatpadRollbackContract $bad } "rollback missing $field"
}

$approvedPackage = [pscustomobject]@{
    architecture = 'amd64'
    signature_required = $true
    sys_sha256 = 'E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097'
    inf_name = 'chatpadfilter.inf'
    hardware_ids = @('USB\VID_045E&PID_028E')
    files = @('ChatpadFilter.sys','chatpadfilter.inf','chatpadfilter.cat')
}
$package = [pscustomobject]@{
    architecture = $approvedPackage.architecture
    signature_required = $approvedPackage.signature_required
    sys_sha256 = $approvedPackage.sys_sha256
    inf_name = $approvedPackage.inf_name
    hardware_ids = $approvedPackage.hardware_ids
    files = $approvedPackage.files
    signature_valid = $true
}
Test-ChatpadPackageContract -Package $package -Approved $approvedPackage | Out-Null
$unsigned = $package.PSObject.Copy(); $unsigned.signature_valid = $false
Assert-Reject { Test-ChatpadPackageContract $unsigned $approvedPackage } 'unsigned package when signature required'
$wrongArch = $package.PSObject.Copy(); $wrongArch.architecture = 'x86'
Assert-Reject { Test-ChatpadPackageContract $wrongArch $approvedPackage } 'wrong package architecture'
$broadIds = $package.PSObject.Copy(); $broadIds.hardware_ids = @('USB\VID_045E&PID_028E','USB\VID_045E&PID_*')
Assert-Reject { Test-ChatpadPackageContract $broadIds $approvedPackage } 'broader-than-approved hardware ID'
$wrongHash = $package.PSObject.Copy(); $wrongHash.sys_sha256 = 'BAD'
Assert-Reject { Test-ChatpadPackageContract $wrongHash $approvedPackage } 'incorrect SYS hash'
$wrongInfSet = $package.PSObject.Copy(); $wrongInfSet.inf_name = 'wrong.inf'
Assert-Reject { Test-ChatpadPackageContract $wrongInfSet $approvedPackage } 'mismatched INF/CAT/SYS set'
$extraFile = $package.PSObject.Copy(); $extraFile.files = @('ChatpadFilter.sys','chatpadfilter.inf','chatpadfilter.cat','extra.dll')
Assert-Reject { Test-ChatpadPackageContract $extraFile $approvedPackage } 'unauthorized file in package'

$signing = [pscustomobject]@{ test_signing_expected = $true; secure_boot_enabled = $false; hvci_enabled = $false; hvci_compatible_signature = $true; certificate_identity_plan = 'future local test certificate' }
Test-ChatpadSigningContract -State $signing -Method LocalTestCertificate | Out-Null
$badSigning = $signing.PSObject.Copy(); $badSigning.test_signing_expected = $false
Assert-Reject { Test-ChatpadSigningContract $badSigning LocalTestCertificate } 'active test-signing state differs from plan'
$secureBoot = $signing.PSObject.Copy(); $secureBoot.secure_boot_enabled = $true
Assert-Reject { Test-ChatpadSigningContract $secureBoot LocalTestCertificate } 'Secure Boot incompatible with local test-signing plan'
$hvci = $signing.PSObject.Copy(); $hvci.hvci_enabled = $true; $hvci.hvci_compatible_signature = $false
Assert-Reject { Test-ChatpadSigningContract $hvci LocalTestCertificate } 'HVCI incompatible signing method'

Assert-Reject { Assert-ChatpadPlanAuthorization -EvidenceDirectory 'e' -TargetInstanceId $contract.instance_id -ApprovedOperationId 'install' } 'mutating operation without explicit switch'
Assert-Reject { Assert-ChatpadPlanAuthorization -ExecuteAuthorizedRuntimeStep -TargetInstanceId $contract.instance_id -ApprovedOperationId 'install' } 'missing evidence directory'
Assert-Reject { Assert-ChatpadPlanAuthorization -ExecuteAuthorizedRuntimeStep -EvidenceDirectory 'e' -ApprovedOperationId 'install' } 'missing exact target identity'

Assert-Reject { Test-ChatpadEvidenceDirectoryContract ([pscustomobject]@{ exists=$false; stale=$false; session_id_reused=$false; outside_repo_or_approved_root=$false }) } 'missing evidence directory'
Assert-Reject { Test-ChatpadEvidenceDirectoryContract ([pscustomobject]@{ exists=$true; stale=$true; session_id_reused=$false; outside_repo_or_approved_root=$false }) } 'stale evidence directory'
Assert-Reject { Test-ChatpadEvidenceDirectoryContract ([pscustomobject]@{ exists=$true; stale=$false; session_id_reused=$true; outside_repo_or_approved_root=$false }) } 'reused runtime-session ID'

Assert-Reject { Test-ChatpadWppPlanContract ([pscustomobject]@{ provider_guid='{BAD}'; output_path='x.etl'; reuses_stale_output=$false }) } 'trace session plan with unexpected provider'
Assert-Reject { Test-ChatpadPostTestReconciliationContract ([pscustomobject]@{ final_state='unknown'; pre_snapshot_present=$true; rollback_plan_present=$true }) } 'post-test state unresolved'
Assert-Reject { Test-ChatpadPostTestReconciliationContract ([pscustomobject]@{ final_state='restored-baseline'; pre_snapshot_present=$false; rollback_plan_present=$true }) } 'missing pre-test snapshot'
Assert-Reject { Test-ChatpadPostTestReconciliationContract ([pscustomobject]@{ final_state='restored-baseline'; pre_snapshot_present=$true; rollback_plan_present=$false }) } 'missing rollback plan'

$scriptFiles = @(
    'tools/Test-ChatpadRuntimeHostPreflight.ps1',
    'tools/Test-ChatpadRuntimeRepositoryIdentity.ps1',
    'tools/Get-ChatpadRuntimeDeviceCandidateInventory.ps1',
    'tools/Test-ChatpadRuntimeTargetSelection.ps1',
    'tools/Save-ChatpadCurrentDriverState.ps1',
    'tools/Test-ChatpadRollbackReadiness.ps1',
    'tools/Test-ChatpadPackageContent.ps1',
    'tools/Test-ChatpadSigningReadiness.ps1',
    'tools/Show-ChatpadInstallPlan.ps1',
    'tools/Show-ChatpadRollbackPlan.ps1',
    'tools/Initialize-ChatpadRuntimeEvidenceDirectory.ps1',
    'tools/Export-ChatpadRuntimeEventLogPlan.ps1',
    'tools/Show-ChatpadWppSessionPlan.ps1',
    'tools/New-ChatpadRuntimeEvidenceManifest.ps1',
    'tools/Test-ChatpadPostTestReconciliation.ps1')
foreach ($file in $scriptFiles) {
    $text = Get-Content -LiteralPath $file -Raw
    if ($file -in @(
            'tools/Test-ChatpadRuntimeRepositoryIdentity.ps1',
            'tools/Test-ChatpadRuntimeTargetSelection.ps1',
            'tools/Test-ChatpadRollbackReadiness.ps1',
            'tools/Test-ChatpadPackageContent.ps1',
            'tools/Test-ChatpadSigningReadiness.ps1',
            'tools/Test-ChatpadPostTestReconciliation.ps1')) {
        Assert-True ($text -match 'Read-ChatpadJson|Get-ChatpadFileIdentity') "Validator script must stay fixture/read-only: $file"
    }
    else {
        Assert-True ($text -match 'ExecuteAuthorizedRuntimeStep|PlanOnly|prohibited|PLANNED_NOT_EXECUTED') "Script lacks visible non-mutating guard: $file"
    }
}

if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
    $manifest = Read-ChatpadJson $ManifestPath
    Assert-True ($manifest.schema_version -eq 'chatpad-runtime-bringup-readiness-manifest-v1') 'Readiness manifest schema mismatch.'
    $ids = @($manifest.entries.id)
    Assert-True (($ids | Sort-Object -Unique).Count -eq $ids.Count) 'Manifest has duplicate IDs.'
}

[pscustomobject]@{
    schema_version = 'chatpad-runtime-bringup-readiness-test-v1'
    result = 'PASS'
    fixture_count = $script:Fixtures
    assertion_count = $script:Assertions
    target_selection_rejections = 6
    rollback_readiness_rejections = 5
    package_validation_rejections = 6
    signing_readiness_rejections = 3
    authorization_switch_rejections = 3
    device_enumeration_performed = $false
    windows_mutation_performed = $false
} | ConvertTo-Json -Depth 6
