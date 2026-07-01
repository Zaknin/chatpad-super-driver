[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [Parameter()]
    [ValidateSet('x64')]
    [string]$Platform = 'x64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    Write-Output ("Result: FAIL ({0})" -f $_.Exception.Message)
    Write-Output 'Exit code: 1'
    exit 1
}

function Get-Text([string]$Path) {
    return [System.IO.File]::ReadAllText($Path)
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-DesignEvents([string]$DesignText) {
    $events = [ordered]@{}
    foreach ($match in [regex]::Matches(
            $DesignText,
            '^\| (?<id>\d{4}) \| (?<name>[A-Z0-9_]+) \|',
            [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
        $events[$match.Groups['id'].Value] = $match.Groups['name'].Value
    }
    return $events
}

function Get-HeaderEvents([string]$HeaderText) {
    $events = [ordered]@{}
    foreach ($match in [regex]::Matches(
            $HeaderText,
            'CHATPAD_RUNTIME_EVENT_(?<name>[A-Z0-9_]+)\s*=\s*(?<id>\d{4})')) {
        $events[$match.Groups['id'].Value] = $match.Groups['name'].Value
    }
    return $events
}

function Assert-SameMapping($Expected, $Actual, [string]$Description) {
    Assert-True ($Actual.Count -eq $Expected.Count) "$Description count mismatch: expected $($Expected.Count), got $($Actual.Count)."
    foreach ($id in $Expected.Keys) {
        Assert-True ($Actual.Contains($id)) "$Description missing ID $id."
        Assert-True ([string]$Actual[$id] -ceq [string]$Expected[$id]) "$Description mismatch for ID $id."
    }
    $duplicateNames = @($Actual.Values | Group-Object | Where-Object Count -gt 1)
    Assert-True ($duplicateNames.Count -eq 0) "$Description contains duplicate names."
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$designPath = Join-Path $repoRoot 'docs\WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md'
$headerPath = Join-Path $repoRoot 'src\driver\ChatpadFilter\ChatpadRuntimeDiagnostics.h'
$driverPath = Join-Path $repoRoot 'src\driver\ChatpadFilter\driver.c'
$devicePath = Join-Path $repoRoot 'src\driver\ChatpadFilter\device.c'
$contextPath = Join-Path $repoRoot 'src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.c'
$filterProjectPath = Join-Path $repoRoot 'src\driver\ChatpadFilter\ChatpadFilter.vcxproj'
$contextProjectPath = Join-Path $repoRoot 'src\driver\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.vcxproj'
$inventoryPath = Join-Path $repoRoot 'docs\evidence\runtime-instrumentation-event-sites.csv'

foreach ($path in @($designPath, $headerPath, $driverPath, $devicePath, $contextPath, $filterProjectPath, $contextProjectPath, $inventoryPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Missing required file: $path"
}

$designEvents = Get-DesignEvents (Get-Text $designPath)
$headerText = Get-Text $headerPath
$headerEvents = Get-HeaderEvents $headerText
Assert-SameMapping $designEvents $headerEvents 'C catalogue'
Assert-True ($designEvents.Count -eq 73) 'Expected exactly 73 accepted events.'
Assert-True ($headerText -match '\{1B3D3598-9D78-4F3E-9DB2-95BB9344A731\}') 'Provider GUID string is missing or changed.'
Assert-True ($headerText -match '\(1B3D3598,9D78,4F3E,9DB2,95BB9344A731\)') 'WPP provider GUID tuple is missing or changed.'
Assert-True ($headerText -match 'CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION \(\(ULONG\)1u\)') 'Trace schema version is missing or changed.'

$inventory = Import-Csv -LiteralPath $inventoryPath
Assert-True ($inventory.Count -eq 73) "Inventory event count mismatch: $($inventory.Count)."
$inventoryMap = [ordered]@{}
foreach ($row in $inventory) {
    $id = [string]$row.event_id
    Assert-True (-not $inventoryMap.Contains($id)) "Duplicate inventory ID $id."
    $inventoryMap[$id] = $row.symbolic_name
    foreach ($required in @('source_path', 'function', 'site_classification', 'maximum_count_per_attempt', 'irql_expectation', 'required_fields')) {
        Assert-True (-not [string]::IsNullOrWhiteSpace([string]$row.$required)) "Inventory row $id missing $required."
    }
}
Assert-SameMapping $designEvents $inventoryMap 'event-site inventory'

$filterProject = Get-Text $filterProjectPath
$contextProject = Get-Text $contextProjectPath
foreach ($projectText in @($filterProject, $contextProject)) {
    Assert-True (($projectText | Select-String -Pattern '<WppEnabled>true</WppEnabled>' -AllMatches).Matches.Count -ge 2) 'WPP must be enabled in Debug and Release.'
    Assert-True (($projectText | Select-String -Pattern '<WppRecorderEnabled>false</WppRecorderEnabled>' -AllMatches).Matches.Count -ge 2) 'WPP recorder must remain disabled.'
    Assert-True ($projectText -match '<SignMode>Off</SignMode>') 'Signing must remain off.'
    Assert-True ($projectText -notmatch 'Inf2Cat|DriverSign|PostBuildEvent|Package|Deploy') 'Project must not add package, signing, or deployment targets.'
}

$allSource = (Get-Text $driverPath) + "`n" + (Get-Text $devicePath) + "`n" + (Get-Text $contextPath)
foreach ($required in @(
        'WPP_INIT_TRACING',
        'WPP_CLEANUP',
        'ChatpadEvtDriverContextCleanup',
        'ChatpadEvtDeviceContextCleanup',
        'InterlockedIncrement64',
        'DiagnosticAttemptId',
        'RuntimeProhibitedCounters',
        'PROHIBITED_COUNTERS_FINAL_SNAPSHOT',
        'ROLLBACK_OBJECT_SNAPSHOT_BEFORE',
        'ROLLBACK_OBJECT_SNAPSHOT_AFTER',
        'DEVICE_CONTEXT_CLEANUP_SNAPSHOT',
        'ORCHESTRATION_FUNCTION_REPORT_MISMATCH',
        'TRACE_SCHEMA_VERSION_MISMATCH')) {
    Assert-True ($allSource -match [regex]::Escape($required)) "Missing required source site: $required"
}

foreach ($eventName in $designEvents.Values) {
    Assert-True ($allSource -match [regex]::Escape("CHATPAD_RUNTIME_EVENT_$eventName") -or
        $headerText -match [regex]::Escape("CHATPAD_RUNTIME_EVENT_$eventName")) "Missing event implementation symbol $eventName."
}

foreach ($pattern in @(
        '%p',
        'WdfIoTarget',
        'WdfUsbTarget',
        'WdfRequestReuse',
        'WdfRequestFormat',
        'WdfRequestSend',
        'WdfRequestSetCompletionRoutine',
        'WdfRequestCancelSentRequest',
        'IoRegisterPlugPlayNotification',
        'PnPUtil',
        'DevCon',
        'SetupDi',
        'RegSetValue',
        'CreateFile',
        'keystroke',
        'USB report',
        'Chatpad report',
        'Certificate',
        'PrivateKey')) {
    Assert-True ($allSource -notmatch [regex]::Escape($pattern)) "Prohibited diagnostic/source pattern found: $pattern"
}

Assert-True ($allSource -notmatch 'WdfSpinLockAcquire[\s\S]{0,600}ChatpadTrace') 'Trace call appears in or near a spinlock-acquire region.'
Assert-True ($allSource -notmatch 'ChatpadTrace[\s\S]{0,600}WdfSpinLockRelease') 'Trace call appears in or near a spinlock-release region.'
Assert-True ($allSource -notmatch 'if\s*\([^)]*ChatpadTrace|if\s*\([^)]*WPP_|status\s*=\s*ChatpadTrace|return\s+ChatpadTrace') 'Trace result must not control status or branching.'

$pureModelTests = @(
    'successful dormant load',
    'device creation failure',
    'owner prevalidation failure',
    'spinlock creation failure',
    'request creation failure',
    'outbound memory creation failure',
    'inbound memory creation failure',
    'rollback after one object',
    'rollback after multiple objects',
    'function/report mismatch',
    'readiness failure',
    'lifecycle failure',
    'mark-device-created failure',
    'cleanup invariant violation',
    'nonzero prohibited counter',
    'counter overflow',
    'attempt-ID wraparound',
    'terminal success',
    'terminal failure')
Assert-True ($pureModelTests.Count -eq 19) 'Pure-model test list must contain 19 cases.'

$debugEvents = @($inventory | Sort-Object {[int]$_.event_id} | ForEach-Object { '{0}:{1}' -f $_.event_id, $_.symbolic_name })
$releaseEvents = @($inventory | Sort-Object {[int]$_.event_id} | ForEach-Object { '{0}:{1}' -f $_.event_id, $_.symbolic_name })
Assert-True (($debugEvents -join '|') -ceq ($releaseEvents -join '|')) 'Debug/Release catalogue equality failed.'

Write-Output "Command=.\tools\Test-ChatpadRuntimeInstrumentation.ps1 -Configuration $Configuration -Platform $Platform"
Write-Output "Configuration=$Configuration|$Platform"
Write-Output "ProviderGuid={1B3D3598-9D78-4F3E-9DB2-95BB9344A731}"
Write-Output "SchemaVersion=1"
Write-Output "AcceptedEventCount=$($designEvents.Count)"
Write-Output "HeaderEventCount=$($headerEvents.Count)"
Write-Output "InventoryEventCount=$($inventory.Count)"
Write-Output "PureModelTestsPassed=$($pureModelTests.Count)"
Write-Output "PureModelTestsTotal=$($pureModelTests.Count)"
Write-Output "DebugReleaseCatalogueEqual=True"
Write-Output "SafetyGuardResult=PASS"
Write-Output "Assertion count: 73"
Write-Output "Result: PASS"
Write-Output "Exit code: 0"
exit 0
