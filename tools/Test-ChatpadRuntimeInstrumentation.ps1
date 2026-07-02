[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',

    [Parameter()]
    [ValidateSet('x64')]
    [string]$Platform = 'x64',

    [Parameter()]
    [switch]$RegenerateEventSiteEvidence
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Text([string]$Path) {
    return [System.IO.File]::ReadAllText($Path)
}

function Get-DesignEvents([string]$Text) {
    $events = @{}
    foreach ($match in [regex]::Matches(
        $Text,
        '(?m)^\|\s*(?<id>\d{4})\s*\|\s*(?<name>[A-Z0-9_]+)\s*\|')) {
        $events[$match.Groups['id'].Value] = $match.Groups['name'].Value
    }
    return $events
}

function Get-HeaderEvents([string]$Text) {
    $events = @{}
    foreach ($match in [regex]::Matches(
        $Text,
        '(?m)^\s*CHATPAD_RUNTIME_EVENT_(?<name>[A-Z0-9_]+)\s*=\s*(?<id>\d{4})')) {
        $events[$match.Groups['id'].Value] = $match.Groups['name'].Value
    }
    return $events
}

function Assert-SameMapping($Expected, $Actual, [string]$Description) {
    Assert-True ($Expected.Count -eq $Actual.Count) "$Description count mismatch."
    foreach ($key in $Expected.Keys) {
        Assert-True $Actual.Contains($key) "$Description is missing semantic ID $key."
        Assert-True ($Expected[$key] -ceq $Actual[$key]) "$Description name mismatch for $key."
    }
}

function Get-FunctionBody {
    param([string]$Text, [string]$FunctionName)
    $signature = [regex]::Match(
        $Text,
        '(?m)^\s*' + [regex]::Escape($FunctionName) + '\s*\(')
    if (-not $signature.Success) { return $null }
    $open = $Text.IndexOf('{', $signature.Index + $signature.Length)
    if ($open -lt 0) { return $null }
    $depth = 0
    for ($index = $open; $index -lt $Text.Length; ++$index) {
        if ($Text[$index] -eq '{') { $depth += 1 }
        elseif ($Text[$index] -eq '}') {
            $depth -= 1
            if ($depth -eq 0) {
                return $Text.Substring($open, $index - $open + 1)
            }
        }
    }
    return $null
}

function Get-TraceInvocations([string]$Text) {
    $calls = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($Text, '(?m)\bChatpadTrace\s*\(')) {
        $start = $match.Index
        $open = $Text.IndexOf('(', $start)
        $depth = 0
        $inString = $false
        $escape = $false
        for ($index = $open; $index -lt $Text.Length; ++$index) {
            $character = $Text[$index]
            if ($inString) {
                if ($escape) { $escape = $false; continue }
                if ($character -eq '\') { $escape = $true; continue }
                if ($character -eq '"') { $inString = $false }
                continue
            }
            if ($character -eq '"') { $inString = $true; continue }
            if ($character -eq '(') { $depth += 1 }
            elseif ($character -eq ')') {
                $depth -= 1
                if ($depth -eq 0) {
                    $calls.Add($Text.Substring($start, $index - $start + 1))
                    break
                }
            }
        }
    }
    return @($calls)
}

function Get-Sha256Text([string]$Text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString(
            $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
        )).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Get-LineNumber([string]$Text, [int]$Index) {
    if ($Index -le 0) { return 1 }
    return ([regex]::Matches($Text.Substring(0, $Index), "\n").Count + 1)
}

function Get-FunctionRanges([string]$Text) {
    $ranges = [System.Collections.Generic.List[object]]::new()
    foreach ($match in [regex]::Matches(
            $Text,
            '(?m)^(?<name>(?:Chatpad|DriverEntry)[A-Za-z0-9_]*)\s*\(')) {
        $open = $Text.IndexOf('{', $match.Index + $match.Length)
        if ($open -lt 0) { continue }
        $semicolon = $Text.IndexOf(';', $match.Index + $match.Length)
        if ($semicolon -ge 0 -and $semicolon -lt $open) { continue }
        $depth = 0
        for ($index = $open; $index -lt $Text.Length; ++$index) {
            if ($Text[$index] -eq '{') { $depth += 1 }
            elseif ($Text[$index] -eq '}') {
                $depth -= 1
                if ($depth -eq 0) {
                    $ranges.Add([pscustomobject]@{
                        name = $match.Groups['name'].Value
                        start = $match.Index
                        end = $index
                    })
                    break
                }
            }
        }
    }
    return @($ranges)
}

function Get-InvocationRecords {
    param(
        [string]$Text,
        [string]$SourcePath,
        [string[]]$EmitterNames)

    $records = [System.Collections.Generic.List[object]]::new()
    $functionRanges = @(Get-FunctionRanges $Text)
    $emitterPattern = ($EmitterNames | ForEach-Object { [regex]::Escape($_) }) -join '|'
    foreach ($match in [regex]::Matches(
            $Text,
            '\b(?<emitter>' + $emitterPattern + ')\s*\(')) {
        $open = $Text.IndexOf('(', $match.Index)
        $depth = 0
        $inString = $false
        $escape = $false
        for ($index = $open; $index -lt $Text.Length; ++$index) {
            $character = $Text[$index]
            if ($inString) {
                if ($escape) { $escape = $false; continue }
                if ($character -eq '\') { $escape = $true; continue }
                if ($character -eq '"') { $inString = $false }
                continue
            }
            if ($character -eq '"') { $inString = $true; continue }
            if ($character -eq '(') { $depth += 1 }
            elseif ($character -eq ')') {
                $depth -= 1
                if ($depth -eq 0) {
                    $callText = $Text.Substring($match.Index, $index - $match.Index + 1)
                    $function = @($functionRanges | Where-Object {
                        $_.start -le $match.Index -and $_.end -ge $index
                    } | Select-Object -First 1)
                    if ($function.Count -eq 0) { break }
                    $records.Add([pscustomobject]@{
                        source_path = $SourcePath
                        function = [string]$function[0].name
                        emitter = $match.Groups['emitter'].Value
                        start_index = $match.Index
                        source_line = Get-LineNumber $Text $match.Index
                        call_text = $callText
                        normalized_call = ([regex]::Replace($callText, '\s+', ' ')).Trim()
                        event_names = @([regex]::Matches(
                            $callText,
                            'CHATPAD_RUNTIME_EVENT_(?<name>[A-Z0-9_]+)') |
                            ForEach-Object { $_.Groups['name'].Value } |
                            Sort-Object -Unique)
                    })
                    break
                }
            }
        }
    }
    return @($records)
}

function Get-EventFamily([int]$EventId) {
    $family = switch ([int]([math]::Floor($EventId / 100))) {
        10 { 'driver-entry' }
        11 { 'device-add' }
        12 { 'owner' }
        13 { 'orchestration' }
        14 { 'readiness' }
        15 { 'lifecycle' }
        16 { 'cleanup-rollback' }
        17 { 'prohibited-counter' }
        18 { 'invariant' }
        19 { 'terminal' }
        default { throw "Unknown event family for $EventId." }
    }
    return $family
}

function Get-EmissionMap {
    param(
        [hashtable]$Sources,
        [hashtable]$EventsById,
        [hashtable]$IdsByName)

    $approvedEmitters = @(
        'ChatpadTrace',
        'ChatpadTraceDeviceEvent',
        'ChatpadTraceDeviceSnapshot',
        'ChatpadKmdfTraceOwnerEvent',
        'ChatpadKmdfTraceOwnerSnapshot')
    $allInvocations = [System.Collections.Generic.List[object]]::new()
    foreach ($sourcePath in ($Sources.Keys | Sort-Object)) {
        foreach ($record in (Get-InvocationRecords `
                $Sources[$sourcePath] $sourcePath $approvedEmitters)) {
            $allInvocations.Add($record)
        }
    }

    $directWpp = @($allInvocations | Where-Object emitter -ceq 'ChatpadTrace')
    $approvedHelperFunctions = @(
        'ChatpadTraceDeviceEvent',
        'ChatpadTraceDeviceSnapshot',
        'ChatpadTracePreContextTerminal',
        'ChatpadKmdfTraceOwnerEvent',
        'ChatpadKmdfTraceOwnerSnapshot')
    $unexplainedDirectWpp = @($directWpp | Where-Object {
        $_.event_names.Count -eq 0 -and $approvedHelperFunctions -cnotcontains $_.function
    })

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($invocation in $allInvocations) {
        if ($invocation.event_names.Count -eq 0) { continue }
        $physicalSiteId = '{0}:{1}:{2}' -f
            $invocation.source_path,
            $invocation.source_line,
            $invocation.emitter
        $traceFlagMatch = [regex]::Match(
            $invocation.call_text,
            'CHATPAD_TRACE_[A-Z0-9_]+')
        $traceFlag = if ($traceFlagMatch.Success) { $traceFlagMatch.Value } else { '' }
        $discriminator = ''
        if ($invocation.event_names -contains 'ORCHESTRATION_STAGE_ENTERED' -or
            $invocation.event_names -contains 'ORCHESTRATION_STAGE_COMPLETED') {
            $prefix = $Sources[$invocation.source_path].Substring(
                0,
                $invocation.start_index)
            $stageMatches = @([regex]::Matches(
                $prefix,
                'CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_[A-Z0-9_]+'))
            if ($stageMatches.Count -ne 0) {
                $discriminator = $stageMatches[-1].Value
            }
        }

        $wppSite = $null
        if ($invocation.emitter -ceq 'ChatpadTrace') {
            $wppSite = $invocation
        } else {
            $resolvedWppFlag = $traceFlag
            if ($invocation.emitter -ceq 'ChatpadTraceDeviceEvent' -and
                $traceFlag -notin @(
                    'CHATPAD_TRACE_OWNER','CHATPAD_TRACE_ORCHESTRATION',
                    'CHATPAD_TRACE_READINESS','CHATPAD_TRACE_LIFECYCLE',
                    'CHATPAD_TRACE_CLEANUP','CHATPAD_TRACE_INVARIANT')) {
                $resolvedWppFlag = 'CHATPAD_TRACE_TERMINAL'
            } elseif ($invocation.emitter -ceq 'ChatpadTraceDeviceSnapshot' -and
                $traceFlag -notin @(
                    'CHATPAD_TRACE_OWNER','CHATPAD_TRACE_ORCHESTRATION',
                    'CHATPAD_TRACE_READINESS','CHATPAD_TRACE_CLEANUP')) {
                $resolvedWppFlag = 'CHATPAD_TRACE_TERMINAL'
            } elseif ($invocation.emitter -ceq 'ChatpadKmdfTraceOwnerEvent' -and
                $traceFlag -notin @('CHATPAD_TRACE_CLEANUP','CHATPAD_TRACE_INVARIANT')) {
                $resolvedWppFlag = 'CHATPAD_TRACE_ORCHESTRATION'
            } elseif ($invocation.emitter -ceq 'ChatpadKmdfTraceOwnerSnapshot' -and
                $traceFlag -cne 'CHATPAD_TRACE_CLEANUP') {
                $resolvedWppFlag = 'CHATPAD_TRACE_ORCHESTRATION'
            }
            $candidates = @($directWpp | Where-Object {
                $_.source_path -ceq $invocation.source_path -and
                $_.function -ceq $invocation.emitter -and
                ($resolvedWppFlag.Length -eq 0 -or $_.call_text -match [regex]::Escape($resolvedWppFlag))
            })
            Assert-True ($candidates.Count -eq 1) "Helper $($invocation.emitter) does not resolve to one WPP site for $traceFlag."
            $wppSite = $candidates[0]
        }

        foreach ($eventName in $invocation.event_names) {
            Assert-True $IdsByName.ContainsKey($eventName) "Production emission uses unknown event $eventName."
            $eventId = [int]$IdsByName[$eventName]
            $rows.Add([pscustomobject][ordered]@{
                schema_version = '2'
                event_id = [string]$eventId
                symbolic_name = $eventName
                family = Get-EventFamily $eventId
                source_path = $invocation.source_path
                function = $invocation.function
                source_line = [string]$invocation.source_line
                source_locator = $invocation.normalized_call
                source_locator_sha256 = Get-Sha256Text $invocation.normalized_call
                emission_kind = $(if ($invocation.emitter -ceq 'ChatpadTrace') { 'direct-wpp' } else { 'helper-mediated' })
                emitter = $invocation.emitter
                helper_chain = $(if ($invocation.emitter -ceq 'ChatpadTrace') { 'ChatpadTrace' } else { "$($invocation.emitter)>ChatpadTrace" })
                wpp_source_path = $wppSite.source_path
                wpp_function = $wppSite.function
                wpp_line = [string]$wppSite.source_line
                wpp_locator_sha256 = Get-Sha256Text $wppSite.normalized_call
                physical_site_id = $physicalSiteId
                shared_physical_site = 'false'
                discriminator = $discriminator
            })
        }
    }

    $sharedIds = @($rows | Group-Object physical_site_id |
        Where-Object { @($_.Group.event_id | Sort-Object -Unique).Count -gt 1 } |
        ForEach-Object { $_.Name })
    foreach ($row in $rows) {
        if ($sharedIds -ccontains $row.physical_site_id) {
            $row.shared_physical_site = 'true'
        }
    }

    return [pscustomobject]@{
        rows = @($rows | Sort-Object @{ Expression = { [int]$_.event_id } }, source_path, @{ Expression = { [int]$_.source_line } }, emitter)
        direct_wpp = $directWpp
        unexplained_direct_wpp = $unexplainedDirectWpp
    }
}

$script:EmissionProperties = @(
    'schema_version','event_id','symbolic_name','family','source_path','function',
    'source_line','source_locator','source_locator_sha256','emission_kind','emitter',
    'helper_chain','wpp_source_path','wpp_function','wpp_line','wpp_locator_sha256',
    'physical_site_id','shared_physical_site','discriminator')

function Get-EmissionRowFingerprint($Row) {
    return (($script:EmissionProperties | ForEach-Object { [string]$Row.$_ }) -join "`u{001F}")
}

function Get-EmissionEvidenceDefects {
    param(
        [object[]]$ExpectedRows,
        [object[]]$CandidateRows,
        [int]$AdditionalUnexplainedWppSites = 0)

    $expectedPrints = @($ExpectedRows | ForEach-Object { Get-EmissionRowFingerprint $_ })
    $candidatePrints = @($CandidateRows | ForEach-Object { Get-EmissionRowFingerprint $_ })
    $missingRows = @($expectedPrints | Where-Object { $candidatePrints -cnotcontains $_ })
    $extraRows = @($candidatePrints | Where-Object { $expectedPrints -cnotcontains $_ })
    $duplicateMappings = @($CandidateRows | Group-Object event_id,physical_site_id | Where-Object Count -gt 1)
    $expectedIds = @($ExpectedRows.event_id | Sort-Object -Unique)
    $candidateIds = @($CandidateRows.event_id | Sort-Object -Unique)
    $missingIds = @($expectedIds | Where-Object { $candidateIds -cnotcontains $_ })
    $extraIds = @($candidateIds | Where-Object { $expectedIds -cnotcontains $_ })
    $productionPaths = @(
        'src/driver/ChatpadFilter/driver.c',
        'src/driver/ChatpadFilter/device.c',
        'src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c')
    $phantom = @($CandidateRows | Where-Object { $productionPaths -cnotcontains [string]$_.source_path })
    $collapsed = 0
    foreach ($id in $expectedIds) {
        $expectedCount = @($ExpectedRows | Where-Object event_id -ceq $id).Count
        $candidateCount = @($CandidateRows | Where-Object event_id -ceq $id).Count
        if ($candidateCount -lt $expectedCount) { $collapsed += ($expectedCount - $candidateCount) }
    }
    return [pscustomobject]@{
        missing_rows = $missingRows.Count
        extra_rows = $extraRows.Count
        duplicate_mappings = $duplicateMappings.Count
        missing_semantic_ids = $missingIds.Count
        extra_semantic_ids = $extraIds.Count
        phantom_mappings = $phantom.Count
        stale_source_evidence = @($extraRows).Count
        collapsed_physical_sites = $collapsed
        unexplained_wpp_sites = $AdditionalUnexplainedWppSites
        total = $missingRows.Count + $extraRows.Count + $duplicateMappings.Count +
            $missingIds.Count + $extraIds.Count + $phantom.Count + $collapsed +
            $AdditionalUnexplainedWppSites
    }
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
$modelRunnerPath = Join-Path $repoRoot 'tests\offline\RuntimeInstrumentationModel\Test-RuntimeInstrumentationModel.ps1'
$modelModulePath = Join-Path $repoRoot 'tests\offline\RuntimeInstrumentationModel\RuntimeInstrumentationModel.psm1'
$orchestrationGuardPath = Join-Path $repoRoot 'tools\Test-ChatpadProductionOrchestrationInvocation.ps1'
$ownerGuardPath = Join-Path $repoRoot 'tools\Test-ChatpadProductionOwnerInitialization.ps1'

foreach ($path in @(
    $designPath, $headerPath, $driverPath, $devicePath, $contextPath,
    $filterProjectPath, $contextProjectPath, $inventoryPath,
    $modelRunnerPath, $modelModulePath, $orchestrationGuardPath, $ownerGuardPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Required path missing: $path"
}

$designEvents = Get-DesignEvents (Get-Text $designPath)
$headerText = Get-Text $headerPath
$headerEvents = Get-HeaderEvents $headerText
Assert-True ($designEvents.Count -eq 73) 'Design catalogue must contain 73 events.'
Assert-SameMapping $designEvents $headerEvents 'C catalogue'
Assert-True ($headerText -match '\{1B3D3598-9D78-4F3E-9DB2-95BB9344A731\}') 'Provider GUID string changed.'
Assert-True ($headerText -match '\(1B3D3598,9D78,4F3E,9DB2,95BB9344A731\)') 'Provider GUID tuple changed.'
Assert-True ($headerText -match 'CHATPAD_RUNTIME_TRACE_SCHEMA_VERSION \(\(ULONG\)1u\)') 'Trace schema version changed.'

$sourceByRelativePath = @{
    'src/driver/ChatpadFilter/driver.c' = Get-Text $driverPath
    'src/driver/ChatpadFilter/device.c' = Get-Text $devicePath
    'src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c' = Get-Text $contextPath
}
$idsByName = @{}
foreach ($id in $designEvents.Keys) { $idsByName[$designEvents[$id]] = [int]$id }
$derivedEmission = Get-EmissionMap $sourceByRelativePath $designEvents $idsByName
$expectedEmissionRows = @($derivedEmission.rows)

if ($RegenerateEventSiteEvidence) {
    $expectedEmissionRows |
        Select-Object $script:EmissionProperties |
        Export-Csv -LiteralPath $inventoryPath -NoTypeInformation -Encoding utf8
}

$inventory = @(Import-Csv -LiteralPath $inventoryPath)
Assert-True ($inventory.Count -gt 73) 'Precise event-site evidence must include repeated physical emission paths.'
Assert-True ($inventory.Count -eq $expectedEmissionRows.Count) 'Event-site evidence row count differs from current production emission paths.'
$actualColumns = @($inventory[0].PSObject.Properties.Name)
Assert-True (($actualColumns -join ',') -ceq ($script:EmissionProperties -join ',')) 'Event-site evidence schema does not match schema version 2.'
$inventoryIds = @($inventory | ForEach-Object { [int]$_.event_id })
Assert-True (($inventoryIds | Sort-Object -Unique).Count -eq 73) 'Event-site evidence must cover 73 unique semantic IDs.'
Assert-True (@($inventory | Where-Object schema_version -cne '2').Count -eq 0) 'Event-site evidence schema version must be 2 for every row.'

$evidenceDefects = Get-EmissionEvidenceDefects `
    $expectedEmissionRows `
    $inventory `
    @($derivedEmission.unexplained_direct_wpp).Count
Assert-True ($evidenceDefects.total -eq 0) (
    'Concrete semantic-event mapping defects: ' + ($evidenceDefects | ConvertTo-Json -Compress))
Assert-True (@($inventory | Where-Object {
    -not $sourceByRelativePath.ContainsKey([string]$_.source_path) -or
    -not $sourceByRelativePath.ContainsKey([string]$_.wpp_source_path) -or
    [string]$_.source_path -match '(^|/)\.\.(/|$)' -or
    [string]$_.wpp_source_path -match '(^|/)\.\.(/|$)'
}).Count -eq 0) 'Event-site evidence path normalization or repository containment failed.'
Assert-True (@($inventory | Group-Object event_id,physical_site_id | Where-Object Count -gt 1).Count -eq 0) 'Duplicate semantic-ID/physical-site mapping exists.'
Assert-True (@($inventory | Where-Object event_id -ceq '1301').Count -eq 9) 'Nine stage-entered physical locations must be represented.'
Assert-True (@($inventory | Where-Object event_id -ceq '1302').Count -eq 9) 'Nine stage-completed physical locations must be represented.'
Assert-True (@($inventory | Where-Object {
    $_.event_id -in @('1301', '1302') -and [string]::IsNullOrWhiteSpace([string]$_.discriminator)
}).Count -eq 0) 'Every repeated stage mapping requires a stage discriminator.'

$negativeEmissionSelfTests = 0
function Assert-NegativeEmissionFixture {
    param([object[]]$Rows, [string]$Description, [int]$UnexplainedWppSites = 0)
    $fixtureDefects = Get-EmissionEvidenceDefects $expectedEmissionRows $Rows $UnexplainedWppSites
    Assert-True ($fixtureDefects.total -gt 0) "Negative emission-map fixture passed unexpectedly: $Description"
    $script:negativeEmissionSelfTests += 1
}
function Copy-EmissionRows([object[]]$Rows) {
    return @((($Rows | ConvertTo-Json -Depth 6) | ConvertFrom-Json))
}

$fixture = Copy-EmissionRows $inventory
$sameFunctionReplacement = @($fixture | Where-Object {
    $_.function -ceq $fixture[0].function -and $_.physical_site_id -cne $fixture[0].physical_site_id
} | Select-Object -First 1)
$fixture[0].source_line = $sameFunctionReplacement[0].source_line
$fixture[0].source_locator = $sameFunctionReplacement[0].source_locator
$fixture[0].source_locator_sha256 = $sameFunctionReplacement[0].source_locator_sha256
Assert-NegativeEmissionFixture $fixture 'event token plus unrelated trace helper in the same function'

$fixture = Copy-EmissionRows $inventory
$fixture[0].source_line = [string]([int]$fixture[0].source_line + 1)
Assert-NegativeEmissionFixture $fixture 'stale source line'
$fixture = Copy-EmissionRows $inventory
$fixture[0].emitter = 'NonexistentDiagnosticHelper'
Assert-NegativeEmissionFixture $fixture 'nonexistent helper'
$fixture = Copy-EmissionRows $inventory
$fixture[0].wpp_line = '999999'
Assert-NegativeEmissionFixture $fixture 'helper that does not reach WPP'
$fixture = @(Copy-EmissionRows $inventory) + @((Copy-EmissionRows @($inventory[0]))[0])
Assert-NegativeEmissionFixture $fixture 'duplicate semantic mapping'
$fixture = @($inventory | Where-Object event_id -cne '1000')
Assert-NegativeEmissionFixture $fixture 'missing semantic ID'
$fixture = Copy-EmissionRows $inventory
$fixture[0].event_id = '9999'
$fixture[0].symbolic_name = 'TEST_ONLY_PHANTOM'
Assert-NegativeEmissionFixture $fixture 'extra semantic ID'
$fixture = Copy-EmissionRows $inventory
$fixture[0].source_path = 'tests/offline/phantom.c'
Assert-NegativeEmissionFixture $fixture 'phantom test-only mapping'
Assert-NegativeEmissionFixture $inventory 'unexplained direct WPP site' 1
$fixtureList = [System.Collections.Generic.List[object]]::new()
$removedStage = $false
foreach ($row in $inventory) {
    if (-not $removedStage -and $row.event_id -ceq '1301') { $removedStage = $true; continue }
    $fixtureList.Add($row)
}
Assert-NegativeEmissionFixture @($fixtureList) 'collapsed repeated physical site'
Assert-True ($negativeEmissionSelfTests -eq 10) 'All ten emission-map negative fixtures must execute.'

$allSource = ($sourceByRelativePath.Values -join [Environment]::NewLine)
$sourceEventNames = @([regex]::Matches(
    $allSource,
    'CHATPAD_RUNTIME_EVENT_(?<name>[A-Z0-9_]+)') |
    ForEach-Object { $_.Groups['name'].Value } |
    Sort-Object -Unique)
$missingInventoryCalls = @($sourceEventNames | Where-Object {
    $name = $_
    -not ($inventory | Where-Object { $_.symbolic_name -ceq $name })
})
Assert-True ($missingInventoryCalls.Count -eq 0) "Source events absent from inventory: $($missingInventoryCalls -join ', ')"

$traceCalls = @()
foreach ($text in $sourceByRelativePath.Values) {
    $traceCalls += Get-TraceInvocations $text
}
Assert-True ($traceCalls.Count -gt 0) 'No actual trace invocations were parsed.'
$sideEffectCalls = @($traceCalls | Where-Object {
    $argumentText = [regex]::Replace($_, '"(?:\\.|[^"])*"', '""')
    $argumentText -match '\+\+|--|(?<![=!<>])=(?!=)|\b(?:Interlocked[A-Za-z0-9_]*|Wdf[A-Za-z0-9_]*|ChatpadNextDeviceTraceSequence|ChatpadKmdfNextOwnerTraceSequence)\s*\('
})
Assert-True ($sideEffectCalls.Count -eq 0) 'A trace argument expression mutates state or invokes a prohibited operation.'
$unsafeFormatCalls = @($traceCalls | Where-Object { $_ -match '%(?:p|ws|wZ|Z|!)' })
Assert-True ($unsafeFormatCalls.Count -eq 0) 'Unsafe WPP field format detected.'

$spinlockTraceCount = 0
foreach ($match in [regex]::Matches(
    $allSource,
    '(?s)WdfSpinLockAcquire\s*\([^;]+;(?<region>.*?)WdfSpinLockRelease\s*\([^;]+;')) {
    if ($match.Groups['region'].Value -match 'ChatpadTrace') { $spinlockTraceCount += 1 }
}
Assert-True ($spinlockTraceCount -eq 0) 'Tracing occurs while an owner spinlock is held.'

$counterNames = @(
    'TargetDiscovery','TargetOpen','TargetAssignment','RequestFormat',
    'RequestReuse','RequestSend','Completion','Cancellation','ProtocolTraffic',
    'KeyboardInjection','D0OwnerObservation','RemovalRundownObservation')
$terminalBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadTraceDeviceTerminal'
$cleanupBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadEvtDeviceContextCleanup'
foreach ($name in $counterNames) {
    Assert-True ($headerText -match [regex]::Escape($name)) "Counter field missing: $name"
    Assert-True ($cleanupBody -match [regex]::Escape($name)) "Cleanup snapshot omits $name."
}
Assert-True ($terminalBody -match 'ChatpadValidateProhibitedCounters' -and $terminalBody -match 'ChatpadEmitCounterSnapshot') 'Terminal counter validation/snapshot missing.'
Assert-True ($cleanupBody -match 'ChatpadValidateProhibitedCounters' -and
    $cleanupBody -match 'FirstTransitionMask' -and
    $cleanupBody -match 'CounterOverflowMask' -and
    $cleanupBody -match 'FinalSnapshotState' -and
    $cleanupBody -match 'StructuralReady') 'Cleanup counter/final/structural snapshot evidence missing.'

$counterEmitterBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadEmitProhibitedCounterEvent'
foreach ($id in 1701..1712) {
    $name = $designEvents[[string]$id]
    Assert-True ($counterEmitterBody -match ('CHATPAD_RUNTIME_EVENT_' + [regex]::Escape($name))) "Counter event $id has no real emitter."
}
foreach ($id in @(1308, 1310, 1801, 1802, 1804)) {
    $name = $designEvents[[string]$id]
    Assert-True ($allSource -match ('CHATPAD_RUNTIME_EVENT_' + [regex]::Escape($name))) "Required real source site missing for $id."
}

$summaryBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadTraceOrchestrationReportSummary'
foreach ($field in @(
    'FunctionResult','ReportResult','FunctionReportMismatch','TerminalStage','FailedStage',
    'TerminalCategory','FirstFailureClass','MappedStatusClass','RollbackAttempted',
    'RollbackCompleted','SpinlockPresent','ReusableRequestPresent',
    'OutboundMemoryPresent','InboundMemoryPresent','ReadyAttempted','ReadyPublished',
    'ObjectGraphComplete','StructuralReady','FinalInitializationMaskClass')) {
    Assert-True ($summaryBody -match [regex]::Escape($field)) "Event 1308 field missing: $field"
}

$preContextBody = Get-FunctionBody $sourceByRelativePath['src/driver/ChatpadFilter/device.c'] 'ChatpadTracePreContextTerminal'
Assert-True ($preContextBody -match 'CHATPAD_RUNTIME_EVENT_PROHIBITED_COUNTERS_FINAL_SNAPSHOT') 'Pre-context terminal omits event 1713.'
Assert-True (([regex]::Matches($sourceByRelativePath['src/driver/ChatpadFilter/device.c'], 'ChatpadTracePreContextTerminal\s*\(').Count -ge 3)) 'Pre-context terminal helper is not used by every pre-context failure path.'

$modelRunnerText = Get-Text $modelRunnerPath
$modelModuleText = Get-Text $modelModulePath
Assert-True (([regex]::Matches($modelRunnerText, "(?m)^\s*New-Scenario '").Count -eq 19)) 'Executable model runner must define nineteen scenarios.'
Assert-True ($modelRunnerText -match 'Invoke-RuntimeInstrumentationScenario' -and
    $modelRunnerText -match 'Assert-Model' -and
    $modelModuleText -match 'Add-RuntimeProhibitedCounter') 'Pure-model tests are not executable state-transition tests.'
Assert-True ($modelRunnerText -match 'ExpectedSemanticNames' -and
    $modelRunnerText -match 'WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN\.md' -and
    $modelModuleText -match '\$script:ModelEventIds') 'Model expectations are not independent semantic-name contracts.'

[xml]$filterProject = Get-Content -LiteralPath $filterProjectPath -Raw
[xml]$contextProject = Get-Content -LiteralPath $contextProjectPath -Raw
$filterDefinitions = @($filterProject.Project.ItemDefinitionGroup)
$contextDefinitions = @($contextProject.Project.ItemDefinitionGroup)
foreach ($config in @('Debug', 'Release')) {
    $filterNode = @($filterDefinitions | Where-Object { $_.Condition -match [regex]::Escape($config + '|x64') })
    $contextNode = @($contextDefinitions | Where-Object { $_.Condition -match [regex]::Escape($config + '|x64') })
    Assert-True ($filterNode.Count -eq 1 -and $filterNode[0].ClCompile.WppEnabled -ceq 'true') "$config filter WPP configuration missing."
    Assert-True ($contextNode.Count -eq 1 -and $contextNode[0].ClCompile.WppEnabled -ceq 'true') "$config context WPP configuration missing."
    Assert-True ([string]$filterNode[0].ClCompile.WppScanConfigurationData -match 'ChatpadRuntimeDiagnostics\.h') "$config filter WPP source missing."
    Assert-True ([string]$contextNode[0].ClCompile.WppScanConfigurationData -match 'ChatpadRuntimeDiagnostics\.h') "$config context WPP source missing."
}

$orchestrationGuardText = Get-Text $orchestrationGuardPath
$ownerGuardText = Get-Text $ownerGuardPath
Assert-True ($orchestrationGuardText -notmatch "\`$InspectionMode\s*=\s*'SourceOnly'") 'Production orchestration guard still downgrades Full mode.'
Assert-True ($orchestrationGuardText -match 'Tracked contract/inventory SHA-256 mismatch' -and
    $orchestrationGuardText -match '\$wrapperInput\.entries' -and
    $orchestrationGuardText -match '\$frozenInput\.entries') 'Production orchestration guard does not cross-bind both tracked-input contracts to retained inventory SHA-256 evidence.'
Assert-True ($sourceByRelativePath['src/driver/ChatpadFilter/device.c'] -match 'orchestrationEnumsValid\s*==\s*0u\s*\|\|\s*\r?\n\s*orchestrationResult\s*!=') 'Unexpected orchestration taxonomy does not enter the fail-closed terminal branch.'
Assert-True ($ownerGuardText -notmatch 'Instrumented final driver size or SHA-256 evidence is invalid') 'Owner guard still accepts an unbound arbitrary binary.'

$forbiddenSource = '(?i)\b(?:WdfIoTargetOpen|WdfUsbTargetDeviceCreate|WdfRequestSend|WdfRequestReuse|WdfRequestCancelSentRequest|WdfUsbTargetDeviceFormatRequestForControlTransfer|WdfRequestComplete)\b'
$prohibitedOperationCalls = @([regex]::Matches($allSource, $forbiddenSource))
Assert-True ($prohibitedOperationCalls.Count -eq 0) 'A prohibited target/request operation exists in production source.'

Write-Output 'RUNTIME INSTRUMENTATION GUARD: PASS'
Write-Output "Configuration=$Configuration"
Write-Output "Platform=$Platform"
Write-Output "ProviderGuid={1B3D3598-9D78-4F3E-9DB2-95BB9344A731}"
Write-Output 'TraceSchemaVersion=1'
Write-Output "AcceptedEventCount=$($designEvents.Count)"
Write-Output "HeaderEventCount=$($headerEvents.Count)"
$indirectHelperMappings = @($inventory | Where-Object emission_kind -ceq 'helper-mediated').Count
$uniquePhysicalSites = @($inventory.physical_site_id | Sort-Object -Unique).Count
$sharedPhysicalSites = @($inventory | Where-Object shared_physical_site -ceq 'true' |
    Select-Object -ExpandProperty physical_site_id -Unique).Count
Write-Output "SemanticEventCount=$($designEvents.Count)"
Write-Output "EmissionMappingCount=$($inventory.Count)"
Write-Output "DirectWppInvocationCount=$(@($derivedEmission.direct_wpp).Count)"
Write-Output "IndirectHelperMappingCount=$indirectHelperMappings"
Write-Output "UniquePhysicalEmissionSiteCount=$uniquePhysicalSites"
Write-Output "SharedPhysicalSiteCount=$sharedPhysicalSites"
Write-Output "MissingMappingCount=$($evidenceDefects.missing_rows)"
Write-Output "ExtraMappingCount=$($evidenceDefects.extra_rows)"
Write-Output "PhantomMappingCount=$($evidenceDefects.phantom_mappings)"
Write-Output "StaleSourceEvidenceCount=$($evidenceDefects.stale_source_evidence)"
Write-Output "UnexplainedWppSiteCount=$($evidenceDefects.unexplained_wpp_sites)"
Write-Output "CollapsedPhysicalSiteCount=$($evidenceDefects.collapsed_physical_sites)"
Write-Output "EmissionMapNegativeSelfTests=$negativeEmissionSelfTests"
Write-Output "SideEffectfulTraceArgumentCount=$($sideEffectCalls.Count)"
Write-Output "TraceUnderSpinlockCount=$spinlockTraceCount"
Write-Output 'MissingCounterEventCount=0'
Write-Output 'MissingPreContextTerminalSnapshotCount=0'
Write-Output 'MissingCleanupCounterFieldCount=0'
Write-Output 'MissingReportSummaryFieldCount=0'
Write-Output 'WeakenedAcceptedGuardCount=0'
Write-Output "ProhibitedOperationCallCount=$($prohibitedOperationCalls.Count)"
Write-Output "ConfigurationCatalogueSource=$Configuration project WPP configuration plus actual production source"
$validationReport = [ordered]@{
    schema_version = 'chatpad-validation-result-v1'
    suite_id = 'runtime-instrumentation'
    configuration = $Configuration
    validation_type = 'static-production-instrumentation-guard'
    result = 'PASS'
    successful_checks = @(
        'authoritative-catalogue-equality',
        'concrete-semantic-emission-map',
        'direct-wpp-site-accounting',
        'helper-to-wpp-resolution',
        'precise-source-locator-validation',
        'repeated-stage-site-preservation',
        'trace-argument-safety',
        'counter-terminal-cleanup-contract',
        'accepted-guard-strength',
        'prohibited-operation-absence')
    failed_checks = @()
}
Write-Output ('CHATPAD_VALIDATION_JSON=' + ($validationReport | ConvertTo-Json -Depth 6 -Compress))
Write-Output 'Result=PASS'
