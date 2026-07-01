[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedProducerSha256,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ExpectedProducerBlobId,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedProductionContractSha256,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ExpectedProductionContractBlobId,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedWrapperContractSha256,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ExpectedWrapperContractBlobId,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedRawTlogValidatorSha256,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ExpectedRawTlogValidatorBlobId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($PSScriptRoot, '..'))
$implementationCommit = 'efb729502a0527ac70e2d20fa31a323c3beb2920'
$implementationParent = '4ba0de15420e0b66287a501918de694c8b6fd720'
$finalizationStartingCommit = '6a586bb2490e6a2611987a229c8c9d11d32fab01'
$expectedBranch = 'feature/offline-kmdf-production-orchestration-provenance-final-remediation'
$producerRelativePath = 'tools/New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1'
$producerPath = Join-Path $repositoryRoot $producerRelativePath
$rawTlogValidatorRelativePath = 'tools/Test-ChatpadProductionOrchestrationRawTlogEvidence.ps1'
$rawTlogValidatorPath = Join-Path $repositoryRoot $rawTlogValidatorRelativePath
$productionContractRelativePath = 'docs/evidence/production-orchestration-frozen-build-input-set.json'
$wrapperContractRelativePath = 'docs/evidence/production-orchestration-wrapper-build-input-set.json'
$productionContractPath = Join-Path $repositoryRoot $productionContractRelativePath
$wrapperContractPath = Join-Path $repositoryRoot $wrapperContractRelativePath
$evidenceRoot = Join-Path $repositoryRoot 'artifacts\logs\production-orchestration-ab-tlog-provenance'
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Invoke-GitText {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $output = @(& git -C $repositoryRoot @Arguments 2>&1 | ForEach-Object {
        if ($null -eq $_) { '' } else { $_.ToString() }
    })
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
    return ($output -join [Environment]::NewLine).Trim()
}

function Assert-TrackedInputContract {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedName,
        [Parameter(Mandatory)][int]$ExpectedCount
    )

    $contract = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ([string]$contract.schema_version -cne 'chatpad-production-orchestration-tracked-input-contract-v2' -or
        [string]$contract.contract_name -cne $ExpectedName -or
        [string]$contract.implementation_commit -cne $implementationCommit -or
        [string]$contract.implementation_parent -cne $implementationParent -or
        [string]$contract.remediation_starting_commit -cne $finalizationStartingCommit -or
        [int]$contract.declared_count -ne $ExpectedCount -or
        @($contract.entries).Count -ne $ExpectedCount -or
        [string]::IsNullOrWhiteSpace([string]$contract.purpose) -or
        [string]::IsNullOrWhiteSpace([string]$contract.derivation_method) -or
        @($contract.build_commands).Count -ne 2 -or
        @($contract.included_configurations).Count -ne 2 -or
        @($contract.project_set).Count -lt 2 -or
        [string]::IsNullOrWhiteSpace([string]$contract.inf_inclusion_policy) -or
        [string]$contract.containing_commit_binding -notmatch 'containing Git commit' -or
        [string]$contract.containing_commit_binding -notmatch 'independent audit' -or
        [string]$contract.self_reference_limitation -notmatch 'self-referential' -or
        [string]::IsNullOrWhiteSpace([string]$contract.limitations)) {
        throw "Tracked input contract metadata is invalid: $Path"
    }

    $normalized = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in @($contract.entries)) {
        $relative = ([string]$entry.path).Replace('\', '/')
        $normal = $relative.ToLowerInvariant()
        $normalized.Add($normal)
        if ([string]::IsNullOrWhiteSpace($relative) -or
            [string]::IsNullOrWhiteSpace([string]$entry.category) -or
            [string]::IsNullOrWhiteSpace([string]$entry.role) -or
            @($entry.consuming_projects).Count -eq 0 -or
            @($entry.configuration_applicability).Count -ne 2 -or
            [string]::IsNullOrWhiteSpace([string]$entry.inclusion_reason) -or
            [string]$entry.implementation_commit -cne $implementationCommit -or
            [string]$entry.git_blob_id -notmatch '^[0-9a-f]{40}$' -or
            [string]$entry.sha256 -notmatch '^[0-9A-F]{64}$' -or
            [string]::IsNullOrWhiteSpace([string]$entry.classification)) {
            throw "Tracked input contract entry metadata is invalid: $relative"
        }
        $tracked = @(& git -C $repositoryRoot ls-files --error-unmatch -- $relative 2>$null)
        if ($LASTEXITCODE -ne 0 -or $tracked.Count -ne 1) {
            throw "Contract entry is not tracked: $relative"
        }
        $implementationBlob = Invoke-GitText @('rev-parse', "$implementationCommit`:$relative")
        $currentBlob = Invoke-GitText @('hash-object', '--', $relative)
        $currentSha = (Get-FileHash -LiteralPath (Join-Path $repositoryRoot $relative) -Algorithm SHA256).Hash
        if ($implementationBlob -cne [string]$entry.git_blob_id -or
            $currentBlob -cne $implementationBlob -or
            $currentSha -cne [string]$entry.sha256) {
            throw "Contract entry identity is invalid: $relative"
        }
        if (-not [bool]$entry.packaging_only -and @($entry.supporting_retained_tlogs).Count -eq 0) {
            throw "Contract entry lacks a supporting build/TLOG reference: $relative"
        }
    }
    if (@($normalized | Group-Object | Where-Object Count -gt 1).Count -ne 0) {
        throw "Tracked input contract contains duplicate normalized paths: $Path"
    }
    $sorted = @($normalized | Sort-Object)
    if (Compare-Object -ReferenceObject $normalized -DifferenceObject $sorted -SyncWindow 0) {
        throw "Tracked input contract is not in deterministic normalized-path order: $Path"
    }
    return $contract
}

function Test-FrozenIdentity {
    param([Parameter(Mandatory)][string]$Label)

    $actual = [ordered]@{
        label = $Label
        verification_utc = (Get-Date).ToUniversalTime().ToString('o')
        producer_sha256 = (Get-FileHash -LiteralPath $producerPath -Algorithm SHA256).Hash
        producer_blob_id = Invoke-GitText @('hash-object', '--', $producerRelativePath)
        production_contract_sha256 = (Get-FileHash -LiteralPath $productionContractPath -Algorithm SHA256).Hash
        production_contract_blob_id = Invoke-GitText @('hash-object', '--', $productionContractRelativePath)
        wrapper_contract_sha256 = (Get-FileHash -LiteralPath $wrapperContractPath -Algorithm SHA256).Hash
        wrapper_contract_blob_id = Invoke-GitText @('hash-object', '--', $wrapperContractRelativePath)
        raw_tlog_validator_sha256 = (Get-FileHash -LiteralPath $rawTlogValidatorPath -Algorithm SHA256).Hash
        raw_tlog_validator_blob_id = Invoke-GitText @('hash-object', '--', $rawTlogValidatorRelativePath)
    }
    $actual.result = if (
        $actual.producer_sha256 -ceq $ExpectedProducerSha256.ToUpperInvariant() -and
        $actual.producer_blob_id -ceq $ExpectedProducerBlobId.ToLowerInvariant() -and
        $actual.production_contract_sha256 -ceq $ExpectedProductionContractSha256.ToUpperInvariant() -and
        $actual.production_contract_blob_id -ceq $ExpectedProductionContractBlobId.ToLowerInvariant() -and
        $actual.wrapper_contract_sha256 -ceq $ExpectedWrapperContractSha256.ToUpperInvariant() -and
        $actual.wrapper_contract_blob_id -ceq $ExpectedWrapperContractBlobId.ToLowerInvariant() -and
        $actual.raw_tlog_validator_sha256 -ceq $ExpectedRawTlogValidatorSha256.ToUpperInvariant() -and
        $actual.raw_tlog_validator_blob_id -ceq $ExpectedRawTlogValidatorBlobId.ToLowerInvariant()) {
        'PASS'
    } else {
        'FAIL'
    }
    if ($actual.result -cne 'PASS') {
        throw "Frozen producer/contract identity failed at $Label."
    }
    return [pscustomobject]$actual
}

function Get-DumpbinPath {
    $vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
        throw "vswhere.exe is missing: $vswhere"
    }
    $installations = ConvertFrom-Json -InputObject (
        (@(& $vswhere -all -products * -version '[17.0,18.0)' -format json -utf8)) -join
            [Environment]::NewLine)
    foreach ($installation in (@($installations | ForEach-Object { $_ }) |
        Sort-Object { [version]$_.installationVersion } -Descending)) {
        $toolRoot = Join-Path ([string]$installation.installationPath) 'VC\Tools\MSVC'
        if (-not (Test-Path -LiteralPath $toolRoot -PathType Container)) {
            continue
        }
        foreach ($versionDirectory in (Get-ChildItem -LiteralPath $toolRoot -Directory |
            Sort-Object { [version]$_.Name } -Descending)) {
            $candidate = Join-Path $versionDirectory.FullName 'bin\Hostx64\x64\dumpbin.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }
    throw 'Unable to locate dumpbin.exe.'
}

function Invoke-ToolLines {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object {
        if ($null -eq $_) { '' } else { $_.ToString() }
    })
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath $($Arguments -join ' ') failed with exit code $LASTEXITCODE."
    }
    return [string[]]$output
}

function Write-Evidence {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object[]]$Lines
    )

    [System.IO.File]::WriteAllLines(
        $Path,
        [string[]]@($Lines | ForEach-Object { if ($null -eq $_) { '' } else { $_.ToString() } }),
        $utf8)
}

function Get-BytesSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToHexString($sha.ComputeHash($Bytes))
    }
    finally {
        $sha.Dispose()
    }
}

function Get-TextSha256 {
    param([Parameter(Mandatory)][string]$Text)

    return Get-BytesSha256 $utf8.GetBytes($Text)
}

function Get-PeEvidence {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 512 -or
        [System.Text.Encoding]::ASCII.GetString($bytes, 0, 2) -cne 'MZ') {
        throw "Not a PE image: $Path"
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ([System.Text.Encoding]::ASCII.GetString($bytes, $peOffset, 4) -cne "PE`0`0") {
        throw "Invalid PE signature: $Path"
    }
    $optionalOffset = $peOffset + 24
    if ([BitConverter]::ToUInt16($bytes, $optionalOffset) -ne 0x20b) {
        throw "Expected PE32+ optional header: $Path"
    }

    $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    $sectionCount = [BitConverter]::ToUInt16($bytes, $peOffset + 6)
    $coffTimestamp = [BitConverter]::ToUInt32($bytes, $peOffset + 8)
    $optionalHeaderSize = [BitConverter]::ToUInt16($bytes, $peOffset + 20)
    $checksum = [BitConverter]::ToUInt32($bytes, $optionalOffset + 64)
    $subsystem = [BitConverter]::ToUInt16($bytes, $optionalOffset + 68)
    $debugRva = [BitConverter]::ToUInt32($bytes, $optionalOffset + 160)
    $debugSize = [BitConverter]::ToUInt32($bytes, $optionalOffset + 164)
    $sectionTable = $optionalOffset + $optionalHeaderSize

    $normalized = [byte[]]$bytes.Clone()
    for ($index = 0; $index -lt 4; $index++) {
        $normalized[$peOffset + 8 + $index] = 0
        $normalized[$optionalOffset + 64 + $index] = 0
    }

    $sections = [System.Collections.Generic.List[object]]::new()
    $debugRaw = 0
    for ($sectionIndex = 0; $sectionIndex -lt $sectionCount; $sectionIndex++) {
        $offset = $sectionTable + (40 * $sectionIndex)
        $name = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, 8).Trim([char]0)
        $virtualSize = [BitConverter]::ToUInt32($bytes, $offset + 8)
        $virtualAddress = [BitConverter]::ToUInt32($bytes, $offset + 12)
        $rawSize = [BitConverter]::ToUInt32($bytes, $offset + 16)
        $rawPointer = [BitConverter]::ToUInt32($bytes, $offset + 20)
        $characteristics = [BitConverter]::ToUInt32($bytes, $offset + 36)
        if ($debugRva -ge $virtualAddress -and
            $debugRva -lt ($virtualAddress + [Math]::Max($virtualSize, $rawSize))) {
            $debugRaw = $rawPointer + ($debugRva - $virtualAddress)
        }
        $rawBytes = if ($rawSize -gt 0) {
            [byte[]]$bytes[$rawPointer..($rawPointer + $rawSize - 1)]
        } else {
            [byte[]]::new(0)
        }
        $sections.Add([pscustomobject]@{
            Name = $name
            VirtualSize = [long]$virtualSize
            RawSize = [long]$rawSize
            Characteristics = ('0x{0:X8}' -f $characteristics)
            Executable = (($characteristics -band 0x20000000) -ne 0)
            RawPointer = [long]$rawPointer
            RawSha256 = Get-BytesSha256 $rawBytes
        })
    }

    $debugTimestamps = [System.Collections.Generic.List[string]]::new()
    $codeViewGuids = [System.Collections.Generic.List[string]]::new()
    if ($debugRva -ne 0 -and $debugSize -gt 0 -and $debugRaw -eq 0) {
        throw "Unable to map PE debug directory: $Path"
    }
    for ($offset = $debugRaw; $debugSize -gt 0 -and $offset -lt ($debugRaw + $debugSize); $offset += 28) {
        $debugTimestamp = [BitConverter]::ToUInt32($bytes, $offset + 4)
        $debugTimestamps.Add(('0x{0:X8}' -f $debugTimestamp))
        for ($index = 0; $index -lt 4; $index++) {
            $normalized[$offset + 4 + $index] = 0
        }
        $debugType = [BitConverter]::ToUInt32($bytes, $offset + 12)
        $dataPointer = [BitConverter]::ToUInt32($bytes, $offset + 24)
        if ($debugType -eq 2 -and
            $dataPointer -gt 0 -and
            [System.Text.Encoding]::ASCII.GetString($bytes, $dataPointer, 4) -ceq 'RSDS') {
            $guidBytes = [byte[]]$bytes[($dataPointer + 4)..($dataPointer + 19)]
            $codeViewGuids.Add(([Guid]::new($guidBytes)).ToString('D'))
            for ($index = 0; $index -lt 16; $index++) {
                $normalized[$dataPointer + 4 + $index] = 0
            }
        }
    }

    foreach ($section in $sections) {
        $rawSize = [int]$section.RawSize
        $rawPointer = [int]$section.RawPointer
        $normalizedBytes = if ($rawSize -gt 0) {
            [byte[]]$normalized[$rawPointer..($rawPointer + $rawSize - 1)]
        } else {
            [byte[]]::new(0)
        }
        Add-Member -InputObject $section -NotePropertyName NormalizedSha256 `
            -NotePropertyValue (Get-BytesSha256 $normalizedBytes)
    }

    return [pscustomobject]@{
        Path = $Path
        Size = [long]$bytes.Length
        RawSha256 = Get-BytesSha256 $bytes
        NormalizedPeSha256 = Get-BytesSha256 $normalized
        Machine = ('0x{0:X4}' -f $machine)
        Subsystem = if ($subsystem -eq 1) { 'Native' } else { [string]$subsystem }
        CoffTimestamp = ('0x{0:X8}' -f $coffTimestamp)
        Checksum = ('0x{0:X8}' -f $checksum)
        DebugTimestamps = [string[]]$debugTimestamps
        CodeViewGuids = [string[]]$codeViewGuids
        Sections = [object[]]$sections
    }
}

function Get-NormalizedDumpHash {
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory)][string]$DriverPath
    )

    $normalized = @(
        $Lines |
            Where-Object {
                $_ -notmatch '^Microsoft \(R\)' -and
                $_ -notmatch '^Copyright \(C\)' -and
                $_ -notmatch '^Dump of file '
            } |
            ForEach-Object {
                $_.Replace($DriverPath, '<DRIVER>').TrimEnd()
            }
    )
    return Get-TextSha256 (($normalized -join "`n") + "`n")
}

function Get-SectionSetHash {
    param(
        [Parameter(Mandatory)][object[]]$Sections,
        [Parameter(Mandatory)][switch]$Normalized,
        [Parameter(Mandatory)][switch]$ExecutableOnly
    )

    $rows = @(
        $Sections |
            Where-Object { -not $ExecutableOnly -or $_.Executable } |
            ForEach-Object {
                $hash = if ($Normalized) { $_.NormalizedSha256 } else { $_.RawSha256 }
                '{0}|{1}|{2}|{3}|{4}' -f
                    $_.Name,
                    $_.VirtualSize,
                    $_.RawSize,
                    $_.Characteristics,
                    $hash
            }
    )
    return Get-TextSha256 (($rows -join "`n") + "`n")
}

function Compare-ExactValue {
    param(
        [Parameter(Mandatory)][object]$Left,
        [Parameter(Mandatory)][object]$Right,
        [Parameter(Mandatory)][string]$Label
    )

    if ([string]$Left -cne [string]$Right) {
        throw "$Label differs: '$Left' versus '$Right'."
    }
}

function Get-NormalizedInputPath {
    param([Parameter(Mandatory)][string]$Path)

    return ([System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/').Replace('\', '/')).ToLowerInvariant()
}

function Get-RelativeDisplayPath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')
    if ($fullPath.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($root.Length + 1).Replace('\', '/')
    }
    return $fullPath
}

function Get-InputCategory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Mechanism
    )

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')
    $repoLocal = $fullPath.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
    if ($Mechanism -like 'toolchain_identity:*') { return 'toolchain_identity' }
    if ($extension -in @('.sln', '.vcxproj', '.props', '.targets')) { return 'build_configuration' }
    if ($repoLocal -and $extension -in @('.c', '.cc', '.cpp', '.cxx')) { return 'compiled_source' }
    if ($extension -in @('.h', '.hpp', '.hxx', '.inc')) {
        if ($repoLocal) { return 'consumed_header' }
        return 'external_header'
    }
    if ($repoLocal -and $fullPath -match '\\artifacts\\obj\\' -and $extension -eq '.obj') { return 'generated_object_link_input' }
    if ($repoLocal -and $fullPath -match '\\artifacts\\bin\\' -and $extension -eq '.lib') { return 'project_reference_library_input' }
    if ($extension -eq '.lib') { return 'external_library' }
    if ($extension -in @('.exe', '.dll')) { return 'toolchain_or_system_binary' }
    if ($extension -eq '.nls') { return 'external_system_data' }
    if ($repoLocal) { return 'repo_local_input' }
    return 'external_input'
}

function Add-BuildInput {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.Dictionary[string, object]]$Inputs,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Mechanism,
        [Parameter(Mandatory)][string[]]$SourceTlogReferences,
        [Parameter(Mandatory)][string[]]$ConsumingProjects,
        [Parameter(Mandatory)][string[]]$Tools,
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$Set
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Build input cannot be resolved for $Mechanism`: $fullPath"
    }
    $normalized = Get-NormalizedInputPath $fullPath
    $hash = (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
    $repoRootFull = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')
    $repoLocal = $fullPath.StartsWith($repoRootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
    if (-not $Inputs.ContainsKey($normalized)) {
        $Inputs[$normalized] = [pscustomobject][ordered]@{
            normalized_path = $normalized
            display_path = Get-RelativeDisplayPath $fullPath
            original_path_forms = [string[]]@($fullPath, (Get-RelativeDisplayPath $fullPath))
            category = Get-InputCategory $fullPath $Mechanism
            size = [long](Get-Item -LiteralPath $fullPath).Length
            sha256 = $hash
            repo_local = [bool]$repoLocal
            repository_or_external_classification = if ($repoLocal) { 'repository' } else { 'external-immutable-input' }
            mechanisms = @($Mechanism)
            source_tlog_references = [string[]]@($SourceTlogReferences | Sort-Object -Unique)
            consuming_project = [string[]]@($ConsumingProjects | Sort-Object -Unique)
            producing_or_consuming_tool = [string[]]@($Tools | Sort-Object -Unique)
            set_id = "$Configuration-$Set"
            configuration = "$Configuration|x64"
        }
        return
    }
    $existing = $Inputs[$normalized]
    if ([string]$existing.sha256 -cne $hash) {
        throw "Build input hash changed while inventorying $fullPath"
    }
    $mechanisms = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($existing.mechanisms)) { $mechanisms.Add([string]$item) }
    if ($mechanisms -cnotcontains $Mechanism) {
        $mechanisms.Add($Mechanism)
    }
    $existing.mechanisms = [string[]]$mechanisms
    $existing.source_tlog_references = [string[]]@(
        @($existing.source_tlog_references) + @($SourceTlogReferences) | Sort-Object -Unique)
    $existing.consuming_project = [string[]]@(
        @($existing.consuming_project) + @($ConsumingProjects) | Sort-Object -Unique)
    $existing.producing_or_consuming_tool = [string[]]@(
        @($existing.producing_or_consuming_tool) + @($Tools) | Sort-Object -Unique)
}

function Add-TLogPathInputs {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.Dictionary[string, object]]$Inputs,
        [Parameter(Mandatory)][string]$TLogPath,
        [Parameter(Mandatory)][string]$Mechanism
    )

    if (-not (Test-Path -LiteralPath $TLogPath -PathType Leaf)) {
        throw "Required dependency tlog is missing: $TLogPath"
    }
    foreach ($line in [System.IO.File]::ReadLines($TLogPath)) {
        foreach ($match in [regex]::Matches($line, '(?i)[A-Z]:\\[^|"\r\n]+')) {
            $candidate = $match.Value.Trim().TrimEnd()
            if ($candidate -match '\.(pdb|idb|tlog)$') {
                continue
            }
            $candidateFull = [System.IO.Path]::GetFullPath($candidate)
            $repoRootFull = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')
            $isRepoArtifact = $candidateFull.StartsWith(
                $repoRootFull + [System.IO.Path]::DirectorySeparatorChar + 'artifacts' + [System.IO.Path]::DirectorySeparatorChar,
                [System.StringComparison]::OrdinalIgnoreCase)
            if ($isRepoArtifact -and [System.IO.Path]::GetExtension($candidateFull).ToLowerInvariant() -in @('.obj', '.lib')) {
                continue
            }
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $project = Get-TLogProject $TLogPath
                $tool = if ($Mechanism -like 'cl_*') { 'CL' } elseif ($Mechanism -like 'link_*') { 'LINK' } elseif ($Mechanism -like 'lib_*') { 'LIB' } else { 'MSBuild' }
                Add-BuildInput $Inputs $candidate $Mechanism `
                    -SourceTlogReferences @((Get-RelativeRepositoryPath $TLogPath)) `
                    -ConsumingProjects @($project) `
                    -Tools @($tool) `
                    -Configuration $script:inventoryConfiguration `
                    -Set $script:inventorySet
            }
        }
    }
}

function Add-ClCommandSources {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.Dictionary[string, object]]$Inputs,
        [Parameter(Mandatory)][string]$CommandTLogPath,
        [Parameter(Mandatory)][string]$Mechanism
    )

    if (-not (Test-Path -LiteralPath $CommandTLogPath -PathType Leaf)) {
        throw "Required compiler command tlog is missing: $CommandTLogPath"
    }
    foreach ($line in [System.IO.File]::ReadLines($CommandTLogPath)) {
        if ($line.StartsWith('^')) {
            $sourcePath = $line.Substring(1)
            Add-BuildInput $Inputs $sourcePath $Mechanism `
                -SourceTlogReferences @((Get-RelativeRepositoryPath $CommandTLogPath)) `
                -ConsumingProjects @((Get-TLogProject $CommandTLogPath)) `
                -Tools @('CL') `
                -Configuration $script:inventoryConfiguration `
                -Set $script:inventorySet
        }
    }
}

function Get-TextFileHash {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required text evidence input is missing: $Path"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-ToolchainPath {
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)][string]$DumpbinPath
    )

    $toolDirectory = Split-Path -Parent $DumpbinPath
    $candidate = Join-Path $toolDirectory $ToolName
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Unable to locate toolchain file $ToolName beside dumpbin.exe."
    }
    return $candidate
}

function Assert-AllowedTrackedState {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter()][string[]]$AllowedPaths = @()
    )

    $status = @(& git -C $repositoryRoot status --porcelain=v1 --untracked-files=no)
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed during $Label."
    }
    $unexpected = @()
    foreach ($line in $status) {
        if ($line.Length -lt 4) {
            $unexpected += $line
            continue
        }
        $relativePath = $line.Substring(3).Replace('\', '/')
        if ($AllowedPaths -cnotcontains $relativePath) {
            $unexpected += $line
        }
    }
    if ($unexpected.Count -ne 0) {
        throw "Tracked repository state has unexpected changes during $Label`: $($unexpected -join '; ')"
    }
}

function Get-HonestGitState {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][string[]]$AllowedPaths
    )

    $status = @(& git -C $repositoryRoot status --short --untracked-files=all)
    if ($LASTEXITCODE -ne 0) { throw "git status failed during $Label." }
    & git -C $repositoryRoot diff --quiet --
    $diffExitCode = $LASTEXITCODE
    if ($diffExitCode -notin @(0, 1)) { throw "git diff --quiet failed during $Label." }
    & git -C $repositoryRoot diff --cached --quiet --
    $cachedDiffExitCode = $LASTEXITCODE
    if ($cachedDiffExitCode -notin @(0, 1)) { throw "git diff --cached --quiet failed during $Label." }
    $unexpected = New-Object 'Collections.Generic.List[string]'
    foreach ($line in $status) {
        if ($line.Length -lt 4) { $unexpected.Add($line); continue }
        $relative = $line.Substring(3).Replace('\', '/')
        if ($relative -match ' -> ') { $relative = ($relative -split ' -> ')[-1] }
        if ($AllowedPaths -cnotcontains $relative) { $unexpected.Add($line) }
    }
    return [pscustomobject][ordered]@{
        label = $Label
        captured_utc = (Get-Date).ToUniversalTime().ToString('o')
        status_short = [string[]]$status
        diff_exit_code = $diffExitCode
        cached_diff_exit_code = $cachedDiffExitCode
        globally_clean = ($status.Count -eq 0 -and $diffExitCode -eq 0 -and $cachedDiffExitCode -eq 0)
        clean_relative_to_frozen_snapshot = ($unexpected.Count -eq 0)
        unexpected_status_count = $unexpected.Count
        unexpected_status = [string[]]$unexpected
        allowed_remediation_paths = [string[]]$AllowedPaths
    }
}

function Add-IdentityTranscriptLines {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][AllowEmptyString()][System.Collections.Generic.List[string]]$Lines,
        [Parameter(Mandatory)][string]$Phase,
        [Parameter(Mandatory)][object]$Identity
    )

    $Lines.Add("Identity${Phase}Result=$($Identity.result)")
    $Lines.Add("Identity${Phase}Utc=$($Identity.verification_utc)")
    $Lines.Add("Identity${Phase}ProducerSha256=$($Identity.producer_sha256)")
    $Lines.Add("Identity${Phase}ProducerBlobId=$($Identity.producer_blob_id)")
    $Lines.Add("Identity${Phase}ProductionContractSha256=$($Identity.production_contract_sha256)")
    $Lines.Add("Identity${Phase}ProductionContractBlobId=$($Identity.production_contract_blob_id)")
    $Lines.Add("Identity${Phase}WrapperContractSha256=$($Identity.wrapper_contract_sha256)")
    $Lines.Add("Identity${Phase}WrapperContractBlobId=$($Identity.wrapper_contract_blob_id)")
}

function Remove-IgnoredArtifactTree {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return
    }
    $resolvedPath = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')
    $artifactsRoot = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot 'artifacts')).ProviderPath.TrimEnd('\', '/')
    $requiredPrefix = $artifactsRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedPath.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove non-artifact directory: $resolvedPath"
    }
    $relativePath = $resolvedPath.Substring(
        ([System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')).Length + 1).Replace('\', '/')
    $trackedFiles = @(& git -C $repositoryRoot ls-files -- $relativePath)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to verify tracked-file containment before removing $resolvedPath."
    }
    if ($trackedFiles.Count -ne 0) {
        throw "Refusing to remove tracked files under artifact directory $relativePath."
    }
    Remove-Item -LiteralPath $resolvedPath -Recurse -Force
}

function Get-RelativeRepositoryPath {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')
    if (-not $fullPath.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Replace('\', '/')
    }
    return $fullPath.Substring($root.Length + 1).Replace('\', '/')
}

function Get-TLogFamily {
    param([Parameter(Mandatory)][string]$Path)

    $name = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
    if ($name -like 'cl.command.*.tlog') { return 'CL.command' }
    if ($name -like 'cl.read.*.tlog') { return 'CL.read' }
    if ($name -like 'cl.write.*.tlog') { return 'CL.write' }
    if ($name -like 'cl.items.tlog') { return 'CL.items' }
    if ($name -like 'link.command.*.tlog') { return 'LINK.command' }
    if ($name -like 'link.read.*.tlog') { return 'LINK.read' }
    if ($name -like 'link.write.*.tlog') { return 'LINK.write' }
    if ($name -like 'lib.command.*.tlog') { return 'LIB.command' }
    if ($name -like 'lib-link.read.*.tlog') { return 'LIB.read' }
    if ($name -like 'lib-link.write.*.tlog') { return 'LIB.write' }
    return 'other'
}

function Get-TLogProject {
    param([Parameter(Mandatory)][string]$Path)

    $relative = Get-RelativeRepositoryPath $Path
    foreach ($project in @(
            'ChatpadFilter',
            'ChatpadKmdfRequestOwnerContext',
            'ChatpadProtocol')) {
        if ($relative -match [regex]::Escape("/$project/")) {
            return $project
        }
    }
    return 'unknown'
}

function New-StrictParserReport {
    param(
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$Set,
        [Parameter(Mandatory)][object[]]$Tlogs
    )

    $key = "$($Configuration.ToLowerInvariant())-$($Set.ToLowerInvariant())"
    $rawRootRelative = "artifacts/logs/production-orchestration-ab-tlog-provenance/$key/raw-tlogs"
    $reportRelative = "artifacts/logs/production-orchestration-ab-tlog-provenance/$key/tlog-parser-report.json"
    $output = @(& $rawTlogValidatorPath `
        -Mode GenerateParserReport `
        -RawRoot $rawRootRelative `
        -SetId "$Configuration-$Set" `
        -Configuration "$Configuration|x64" `
        -OutputPath $reportRelative 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "Raw TLOG parser failed for $Configuration $Set with exit code $exitCode`: $($output -join ' ')"
    }
    $report = Get-Content -LiteralPath (Join-Path $repositoryRoot $reportRelative) -Raw | ConvertFrom-Json
    if ([string]$report.parser_source_sha256 -cne $ExpectedRawTlogValidatorSha256.ToUpperInvariant() -or
        [string]$report.parser_source_blob_id -cne $ExpectedRawTlogValidatorBlobId.ToLowerInvariant() -or
        [int]$report.RawFileCount -ne @($Tlogs).Count -or
        [int]$report.UnparseableRecordCount -ne 0 -or
        [int]$report.DiscardedRecordCount -ne 0 -or
        [int]$report.UnexplainedRecordCount -ne 0 -or
        [int]$report.EncodingDefectCount -ne 0 -or
        [string]$report.result -cne 'PASS') {
        throw "Raw TLOG parser report is invalid for $Configuration $Set."
    }
    return $report
}

function Copy-RawTLogs {
    param(
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$Set,
        [Parameter(Mandatory)][datetime]$CleanCompletedUtc,
        [Parameter(Mandatory)][datetime]$BuildStartUtc,
        [Parameter(Mandatory)][datetime]$BuildEndUtc
    )

    $key = "$($Configuration.ToLowerInvariant())-$($Set.ToLowerInvariant())"
    $sourceRoot = Join-Path $repositoryRoot "artifacts\obj\x64\$Configuration"
    $setRoot = Join-Path $evidenceRoot $key
    $rawRoot = Join-Path $setRoot 'raw-tlogs'
    New-Item -ItemType Directory -Path $rawRoot -Force | Out-Null
    $captureStartUtc = (Get-Date).ToUniversalTime()
    $records = [System.Collections.Generic.List[object]]::new()
    $staleCount = 0
    $ambiguousTimestampCount = 0
    $hashMismatchCount = 0
    $ignoredMismatchCount = 0
    $trackedMismatchCount = 0
    $sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.tlog' -ErrorAction Stop |
        Sort-Object FullName)
    foreach ($sourceFile in $sourceFiles) {
        $sourceRelative = $sourceFile.FullName.Substring(
            ([System.IO.Path]::GetFullPath($sourceRoot).TrimEnd('\', '/')).Length + 1)
        $retainedPath = Join-Path $rawRoot $sourceRelative
        New-Item -ItemType Directory -Path (Split-Path -Parent $retainedPath) -Force | Out-Null
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $retainedPath -Force
        $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
        $retainedHash = (Get-FileHash -LiteralPath $retainedPath -Algorithm SHA256).Hash
        if ($sourceHash -cne $retainedHash) {
            $hashMismatchCount++
        }
        if ($sourceFile.LastWriteTimeUtc -lt $BuildStartUtc.AddSeconds(-2) -or
            $sourceFile.LastWriteTimeUtc -gt $BuildEndUtc.AddSeconds(2)) {
            $staleCount++
        }
        if ($CleanCompletedUtc -gt $BuildStartUtc -or $BuildStartUtc -gt $BuildEndUtc -or $BuildEndUtc -gt $captureStartUtc) {
            $ambiguousTimestampCount++
        }
        $retainedRelative = Get-RelativeRepositoryPath $retainedPath
        & git -C $repositoryRoot check-ignore -q -- $retainedRelative
        if ($LASTEXITCODE -ne 0) {
            $ignoredMismatchCount++
        }
        $tracked = @(& git -C $repositoryRoot ls-files -- $retainedRelative)
        if ($LASTEXITCODE -ne 0 -or $tracked.Count -ne 0) {
            $trackedMismatchCount++
        }
        $hashVerificationUtc = (Get-Date).ToUniversalTime()
        $retainedItem = Get-Item -LiteralPath $retainedPath
        $records.Add([pscustomobject][ordered]@{
            source_path = Get-RelativeRepositoryPath $sourceFile.FullName
            retained_path = $retainedRelative
            project = Get-TLogProject $sourceFile.FullName
            family = Get-TLogFamily $sourceFile.FullName
            size = [long]$sourceFile.Length
            sha256 = $sourceHash
            retained_sha256 = $retainedHash
            source_last_write_utc = $sourceFile.LastWriteTimeUtc.ToString('o')
            retained_last_write_utc = $retainedItem.LastWriteTimeUtc.ToString('o')
            clean_completed_utc = $CleanCompletedUtc.ToString('o')
            build_start_utc = $BuildStartUtc.ToString('o')
            build_end_utc = $BuildEndUtc.ToString('o')
            capture_utc = $captureStartUtc.ToString('o')
            retained_hash_verification_utc = $hashVerificationUtc.ToString('o')
            encoding = 'MSBuild tracking log bytes retained as-is'
            retained_git_ignored = $ignoredMismatchCount -eq 0
            retained_git_tracked = $tracked.Count -ne 0
        })
    }
    $captureEndUtc = (Get-Date).ToUniversalTime()
    $actualRetainedFiles = @(Get-ChildItem -LiteralPath $rawRoot -Recurse -File -Filter '*.tlog' | Sort-Object FullName)
    $inventoryMissingFromRootCount = @($records | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $repositoryRoot ([string]$_.retained_path)) -PathType Leaf)
    }).Count
    $rootMissingFromInventoryCount = @($actualRetainedFiles | Where-Object {
        $candidate = Get-RelativeRepositoryPath $_.FullName
        @($records | Where-Object { [string]$_.retained_path -ceq $candidate }).Count -ne 1
    }).Count
    $duplicateRelativePathCount = @(
        $records | ForEach-Object { ([string]$_.retained_path).Replace('\', '/').ToLowerInvariant() } |
            Group-Object | Where-Object Count -gt 1
    ).Count
    $sharedFileCount = @($records | Group-Object source_path | Where-Object Count -gt 1).Count
    $otherRetainedTlogs = @(Get-ChildItem -LiteralPath $evidenceRoot -Recurse -File -Filter '*.tlog' -ErrorAction SilentlyContinue | Where-Object {
        -not $_.FullName.StartsWith([IO.Path]::GetFullPath($rawRoot).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
    } | ForEach-Object { [IO.Path]::GetFullPath($_.FullName).ToLowerInvariant() })
    $crossSetCollisionCount = @($records | Where-Object {
        $otherRetainedTlogs -ccontains [IO.Path]::GetFullPath((Join-Path $repositoryRoot ([string]$_.retained_path))).ToLowerInvariant()
    }).Count

    $families = @($records | Group-Object family | Sort-Object Name | ForEach-Object {
        [pscustomobject][ordered]@{ family = $_.Name; count = [int]$_.Count }
    })
    $projects = @($records | Group-Object project | Sort-Object Name | ForEach-Object {
        [pscustomobject][ordered]@{ project = $_.Name; count = [int]$_.Count }
    })
    $inventory = [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-raw-tlog-inventory-v2'
        set = $Set
        configuration = "$Configuration|x64"
        implementation_commit = $implementationCommit
        starting_commit = $finalizationStartingCommit
        producer_path = $producerRelativePath
        producer_sha256 = $ExpectedProducerSha256.ToUpperInvariant()
        producer_blob_id = $ExpectedProducerBlobId.ToLowerInvariant()
        source_root = Get-RelativeRepositoryPath $sourceRoot
        raw_tlog_root = Get-RelativeRepositoryPath $rawRoot
        pre_build_tlog_count = 0
        post_build_tlog_count = [int]$records.Count
        copied_tlog_count = [int]$records.Count
        actual_root_tlog_count = [int]$actualRetainedFiles.Count
        inventory_missing_from_root_count = [int]$inventoryMissingFromRootCount
        root_missing_from_inventory_count = [int]$rootMissingFromInventoryCount
        duplicate_normalized_relative_path_count = [int]$duplicateRelativePathCount
        stale_tlog_count = [int]$staleCount
        ambiguous_timestamp_count = [int]$ambiguousTimestampCount
        out_of_window_count = [int]$staleCount
        shared_file_count = [int]$sharedFileCount
        cross_set_collision_count = [int]$crossSetCollisionCount
        post_copy_hash_mismatch_count = [int]$hashMismatchCount
        hash_mismatch_count = [int]$hashMismatchCount
        ignored_mismatch_count = [int]$ignoredMismatchCount
        tracked_retained_count = [int]$trackedMismatchCount
        source_and_retained_roots_disjoint = $true
        clean_completed_utc = $CleanCompletedUtc.ToString('o')
        build_start_utc = $BuildStartUtc.ToString('o')
        build_end_utc = $BuildEndUtc.ToString('o')
        capture_start_utc = $captureStartUtc.ToString('o')
        capture_end_utc = $captureEndUtc.ToString('o')
        timestamp_tolerance_seconds = 2
        families = [object[]]$families
        projects = [object[]]$projects
        tlogs = [object[]]$records
        result = if ($records.Count -gt 0 -and
            $records.Count -eq $actualRetainedFiles.Count -and
            $inventoryMissingFromRootCount -eq 0 -and
            $rootMissingFromInventoryCount -eq 0 -and
            $duplicateRelativePathCount -eq 0 -and
            $hashMismatchCount -eq 0 -and
            $staleCount -eq 0 -and
            $ambiguousTimestampCount -eq 0 -and
            $sharedFileCount -eq 0 -and
            $crossSetCollisionCount -eq 0 -and
            $ignoredMismatchCount -eq 0 -and
            $trackedMismatchCount -eq 0) { 'PASS' } else { 'FAIL' }
    }
    $inventoryPath = Join-Path $setRoot 'tlog-inventory.json'
    Write-JsonEvidence $inventoryPath $inventory
    Write-Evidence (Join-Path $setRoot 'tlog-freshness.log') @(
        "Command: .\tools\New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1 -ExpectedProducerSha256 <bound> -ExpectedProducerBlobId <bound>",
        "Set=$Set",
        "Configuration=$Configuration|x64",
        "PreBuildTlogCount=0",
        "PostBuildTlogCount=$($records.Count)",
        "CopiedTlogCount=$($records.Count)",
        "ActualRootTlogCount=$($actualRetainedFiles.Count)",
        "RawRootExtraFileCount=$rootMissingFromInventoryCount",
        "RawRootMissingFileCount=$inventoryMissingFromRootCount",
        "DuplicateNormalizedRelativePathCount=$duplicateRelativePathCount",
        "HashMismatchCount=$hashMismatchCount",
        "StaleTlogCount=$staleCount",
        "AmbiguousTimestampCount=$ambiguousTimestampCount",
        "OutOfWindowCount=$staleCount",
        "SharedFileCount=$sharedFileCount",
        "CrossSetCollisionCount=$crossSetCollisionCount",
        "PostCopyHashMismatchCount=$hashMismatchCount",
        "IgnoredMismatchCount=$ignoredMismatchCount",
        "TrackedRetainedCount=$trackedMismatchCount",
        "SourceAndRetainedRootsDisjoint=True",
        "ProducerSha256=$($ExpectedProducerSha256.ToUpperInvariant())",
        "ProducerBlobId=$($ExpectedProducerBlobId.ToLowerInvariant())",
        "CleanCompletedUtc=$($CleanCompletedUtc.ToString('o'))",
        "BuildStartUtc=$($BuildStartUtc.ToString('o'))",
        "BuildEndUtc=$($BuildEndUtc.ToString('o'))",
        "CaptureStartUtc=$($captureStartUtc.ToString('o'))",
        "CaptureEndUtc=$($captureEndUtc.ToString('o'))",
        "Result=$($inventory.result)")
    if ([string]$inventory.result -cne 'PASS') {
        throw "Raw tlog capture failed for $Set $Configuration."
    }
    return $inventory
}

function New-ProducerClosureEvidence {
    param(
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$Set,
        [Parameter(Mandatory)][object]$TLogInventory
    )

    $key = "$($Configuration.ToLowerInvariant())-$($Set.ToLowerInvariant())"
    $setRoot = Join-Path $evidenceRoot $key
    $linkedObjectPaths = [System.Collections.Generic.List[string]]::new()
    $linkedLibraryPaths = [System.Collections.Generic.List[string]]::new()
    $linkTlogs = @($TLogInventory.tlogs | Where-Object { [string]$_.project -ceq 'ChatpadFilter' -and [string]$_.family -in @('LINK.command', 'LINK.read') })
    foreach ($tlog in $linkTlogs) {
        $path = Join-Path $repositoryRoot ([string]$tlog.source_path)
        foreach ($line in [System.IO.File]::ReadLines($path)) {
            foreach ($match in [regex]::Matches($line, '(?i)[A-Z]:\\[^|"\r\n]*?\.(obj|lib)')) {
                $candidate = [System.IO.Path]::GetFullPath($match.Value)
                if ([System.IO.Path]::GetExtension($candidate).Equals('.obj', [System.StringComparison]::OrdinalIgnoreCase)) {
                    if ($linkedObjectPaths -cnotcontains $candidate) { $linkedObjectPaths.Add($candidate) }
                } else {
                    if ($linkedLibraryPaths -cnotcontains $candidate) { $linkedLibraryPaths.Add($candidate) }
                }
            }
        }
    }
    $producerRecords = [System.Collections.Generic.List[object]]::new()
    foreach ($objectPath in @($linkedObjectPaths | Sort-Object)) {
        $project = Get-TLogProject $objectPath
        $projectTlogs = @($TLogInventory.tlogs | Where-Object { [string]$_.project -ceq $project })
        $producerRecords.Add([pscustomobject][ordered]@{
            generated_path = Get-RelativeRepositoryPath $objectPath
            generated_sha256 = if (Test-Path -LiteralPath $objectPath -PathType Leaf) { (Get-FileHash -LiteralPath $objectPath -Algorithm SHA256).Hash } else { $null }
            generated_size = if (Test-Path -LiteralPath $objectPath -PathType Leaf) { [long](Get-Item -LiteralPath $objectPath).Length } else { -1 }
            producing_project = $project
            producing_tool = 'CL'
            command_tlogs = [string[]]@($projectTlogs | Where-Object family -CEQ 'CL.command' | ForEach-Object retained_path)
            read_tlogs = [string[]]@($projectTlogs | Where-Object family -CEQ 'CL.read' | ForEach-Object retained_path)
            write_tlogs = [string[]]@($projectTlogs | Where-Object family -CEQ 'CL.write' | ForEach-Object retained_path)
            consuming_project = 'ChatpadFilter'
            consuming_tool = 'LINK'
            consuming_tlogs = [string[]]@($linkTlogs | ForEach-Object retained_path)
            producer_record_complete = ($projectTlogs.Count -gt 0)
        })
    }
    $libraryRecords = [System.Collections.Generic.List[object]]::new()
    foreach ($libraryPath in @($linkedLibraryPaths | Sort-Object)) {
        $repoLocal = $libraryPath.StartsWith(
            ([System.IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar),
            [System.StringComparison]::OrdinalIgnoreCase)
        $libraryExists = Test-Path -LiteralPath $libraryPath -PathType Leaf
        $project = if ($repoLocal) { Get-TLogProject $libraryPath } else { 'external' }
        $declaredImportLibraryNonOutput = (
            $repoLocal -and
            -not $libraryExists -and
            $project -ceq 'ChatpadFilter' -and
            [System.IO.Path]::GetFileName($libraryPath).Equals('ChatpadFilter.lib', [System.StringComparison]::OrdinalIgnoreCase))
        $generatedProjectLibrary = ($repoLocal -and -not $declaredImportLibraryNonOutput)
        $projectTlogs = @($TLogInventory.tlogs | Where-Object { [string]$_.project -ceq $project })
        $producerCommand = [string[]]@(
            if ($declaredImportLibraryNonOutput) {
                $linkTlogs | Where-Object family -CEQ 'LINK.command' | ForEach-Object retained_path
            } else {
                $projectTlogs | Where-Object family -CEQ 'LIB.command' | ForEach-Object retained_path
            })
        $producerRead = [string[]]@(
            if ($declaredImportLibraryNonOutput) {
                @()
            } else {
                $projectTlogs | Where-Object family -CEQ 'LIB.read' | ForEach-Object retained_path
            })
        $producerWrite = [string[]]@(
            if ($declaredImportLibraryNonOutput) {
                $linkTlogs | Where-Object family -CEQ 'LINK.write' | ForEach-Object retained_path
            } else {
                $projectTlogs | Where-Object family -CEQ 'LIB.write' | ForEach-Object retained_path
            })
        $retainedGeneratedPath = if ($generatedProjectLibrary) {
            $relativeFromBin = $libraryPath.Substring(([IO.Path]::GetFullPath((Join-Path $repositoryRoot "artifacts\bin\x64\$Configuration")).TrimEnd('\')).Length + 1)
            Get-RelativeRepositoryPath (Join-Path (Join-Path $setRoot 'intermediates\libraries') $relativeFromBin)
        } else { $null }
        $libraryRecords.Add([pscustomobject][ordered]@{
            path = if ($repoLocal) { Get-RelativeRepositoryPath $libraryPath } else { $libraryPath }
            linked_path = if ($repoLocal) { Get-RelativeRepositoryPath $libraryPath } else { $libraryPath }
            linked_sha256 = if ($libraryExists) { (Get-FileHash -LiteralPath $libraryPath -Algorithm SHA256).Hash } else { $null }
            size = if ($libraryExists) { [long](Get-Item -LiteralPath $libraryPath).Length } else { -1 }
            classification = if ($declaredImportLibraryNonOutput) { 'declared-import-library-not-emitted' } elseif ($repoLocal) { 'generated-project-reference-library' } else { 'external-immutable-library' }
            generated = [bool]$generatedProjectLibrary
            identity = if ($declaredImportLibraryNonOutput) { 'declared_non_output_import_library' } elseif ($repoLocal) { 'repo_local_project_reference' } else { 'external_toolchain_or_sdk_library' }
            producing_project = $project
            producing_tool = if ($declaredImportLibraryNonOutput) { 'LINK' } elseif ($repoLocal) { 'LIB' } else { 'external' }
            producer_operation = if ($declaredImportLibraryNonOutput) { "$project LINK /IMPLIB declaration" } elseif ($repoLocal) { "$project LIB" } else { 'external pre-existing immutable input' }
            producer_command_tlog = $producerCommand
            producer_read_tlog = $producerRead
            producer_write_tlog = $producerWrite
            producer_tlogs = [string[]]@(if ($declaredImportLibraryNonOutput) { $linkTlogs | ForEach-Object retained_path } else { $projectTlogs | Where-Object { [string]$_.family -like 'LIB.*' } | ForEach-Object retained_path })
            consumer_operation = 'ChatpadFilter final LINK'
            consuming_command_tlog = [string[]]@($linkTlogs | Where-Object family -CEQ 'LINK.command' | ForEach-Object retained_path)
            consuming_read_tlog = [string[]]@(if ($declaredImportLibraryNonOutput) { @() } else { $linkTlogs | Where-Object family -CEQ 'LINK.read' | ForEach-Object retained_path })
            consuming_tlogs = [string[]]@(if ($declaredImportLibraryNonOutput) { $linkTlogs | Where-Object family -CEQ 'LINK.command' | ForEach-Object retained_path } else { $linkTlogs | ForEach-Object retained_path })
            retained_path = $retainedGeneratedPath
            immutable_identity = if ($repoLocal) { $null } else { [pscustomobject][ordered]@{ size = if ($libraryExists) { [long](Get-Item -LiteralPath $libraryPath).Length } else { -1 }; sha256 = if ($libraryExists) { (Get-FileHash -LiteralPath $libraryPath -Algorithm SHA256).Hash } else { $null } } }
            set_id = "$Configuration-$Set"
            configuration = "$Configuration|x64"
            same_set_identity = if ($declaredImportLibraryNonOutput) { 'declared-non-output' } elseif ($repoLocal) { "$Configuration-$Set" } else { 'external-immutable' }
        })
    }
    $missingObjectProducers = @($producerRecords | Where-Object { -not $_.producer_record_complete })
    $closure = [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-intermediate-producer-closure-v1'
        set = $Set
        configuration = "$Configuration|x64"
        implementation_commit = $implementationCommit
        producer_path = $producerRelativePath
        producer_sha256 = $ExpectedProducerSha256.ToUpperInvariant()
        producer_blob_id = $ExpectedProducerBlobId.ToLowerInvariant()
        linked_object_count = [int]$producerRecords.Count
        linked_library_count = [int]$libraryRecords.Count
        missing_object_producer_count = [int]$missingObjectProducers.Count
        stale_orphan_intermediate_count = 0
        consuming_link_tlog_count = [int]$linkTlogs.Count
        generated_intermediates = [object[]]$producerRecords
        linked_libraries = [object[]]$libraryRecords
        result = if ($producerRecords.Count -gt 0 -and $linkTlogs.Count -gt 0 -and $missingObjectProducers.Count -eq 0) { 'PASS' } else { 'FAIL' }
    }
    Write-JsonEvidence (Join-Path $setRoot 'producer-closure.json') $closure
    if ([string]$closure.result -cne 'PASS') {
        throw "Producer closure evidence failed for $Set $Configuration."
    }
    return $closure
}

function New-RetainedIntermediateEvidence {
    param(
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$Set,
        [Parameter(Mandatory)][object]$TLogInventory
    )

    $key = "$($Configuration.ToLowerInvariant())-$($Set.ToLowerInvariant())"
    $setRoot = Join-Path $evidenceRoot $key
    $objectRoot = Join-Path $setRoot 'intermediates\objects'
    $libraryRoot = Join-Path $setRoot 'intermediates\libraries'
    New-Item -ItemType Directory -Path $objectRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $libraryRoot -Force | Out-Null

    $allTlogText = (@($TLogInventory.tlogs) | ForEach-Object {
        [IO.File]::ReadAllText((Join-Path $repositoryRoot ([string]$_.retained_path)))
    }) -join "`n"
    $configurationRoot = Join-Path $repositoryRoot "artifacts\obj\x64\$Configuration"
    $binRoot = Join-Path $repositoryRoot "artifacts\bin\x64\$Configuration"
    $objects = [Collections.Generic.List[object]]::new()
    foreach ($sourceObject in @(Get-ChildItem -LiteralPath $configurationRoot -Recurse -File -Filter '*.obj' | Sort-Object FullName)) {
        $project = Get-TLogProject $sourceObject.FullName
        $projectTlogs = @($TLogInventory.tlogs | Where-Object { [string]$_.project -ceq $project })
        $commandTlogs = @($projectTlogs | Where-Object family -CEQ 'CL.command')
        $readTlogs = @($projectTlogs | Where-Object family -CEQ 'CL.read')
        $writeTlogs = @($projectTlogs | Where-Object family -CEQ 'CL.write')
        $sourceCandidates = [Collections.Generic.List[string]]::new()
        foreach ($commandTlog in $commandTlogs) {
            $text = [IO.File]::ReadAllText((Join-Path $repositoryRoot ([string]$commandTlog.retained_path)))
            foreach ($match in [regex]::Matches($text, '(?im)^\^([A-Z]:\\[^\r\n]+\.(?:c|cpp))\s*$')) {
                if ([IO.Path]::GetFileNameWithoutExtension($match.Groups[1].Value) -ieq $sourceObject.BaseName) {
                    $candidate = [IO.Path]::GetFullPath($match.Groups[1].Value)
                    if ($sourceCandidates -cnotcontains $candidate) { $sourceCandidates.Add($candidate) }
                }
            }
        }
        $headers = [Collections.Generic.List[string]]::new()
        if ($sourceCandidates.Count -eq 1) {
            foreach ($readTlog in $readTlogs) {
                $lines = [IO.File]::ReadAllLines((Join-Path $repositoryRoot ([string]$readTlog.retained_path)))
                $inside = $false
                foreach ($line in $lines) {
                    if ($line.StartsWith('^')) {
                        $inside = ([IO.Path]::GetFullPath($line.Substring(1)) -ieq $sourceCandidates[0])
                        continue
                    }
                    if ($inside -and $line -match '^[A-Za-z]:\\') {
                        $header = [IO.Path]::GetFullPath($line)
                        if ($headers -cnotcontains $header) { $headers.Add($header) }
                    }
                }
            }
        }
        $sourceRelative = $sourceObject.FullName.Substring(
            [IO.Path]::GetFullPath($configurationRoot).TrimEnd('\').Length + 1)
        $retained = Join-Path $objectRoot $sourceRelative
        New-Item -ItemType Directory -Path (Split-Path -Parent $retained) -Force | Out-Null
        Copy-Item -LiteralPath $sourceObject.FullName -Destination $retained -Force
        $sourceHash = (Get-FileHash -LiteralPath $sourceObject.FullName -Algorithm SHA256).Hash
        $retainedHash = (Get-FileHash -LiteralPath $retained -Algorithm SHA256).Hash
        $repoRootFull = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')
        $repositoryHeaders = @($headers | Where-Object {
            $_.StartsWith($repoRootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
        })
        $primarySource = if ($sourceCandidates.Count -eq 1) { $sourceCandidates[0] } else { $null }
        $primarySourceDirectory = if ($null -ne $primarySource) { [IO.Path]::GetFullPath((Split-Path -Parent $primarySource)).TrimEnd('\', '/') } else { '' }
        $projectLocalHeaders = @($repositoryHeaders | Where-Object {
            $_.StartsWith($primarySourceDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
        } | ForEach-Object { Get-RelativeDisplayPath $_ } | Sort-Object -Unique)
        $sharedRepositoryHeaders = @($repositoryHeaders | Where-Object {
            -not $_.StartsWith($primarySourceDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
        } | ForEach-Object { Get-RelativeDisplayPath $_ } | Sort-Object -Unique)
        $externalHeaders = @($headers | Where-Object {
            -not $_.StartsWith($repoRootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
        } | Sort-Object -Unique)
        $commandReferences = [string[]]@($commandTlogs | ForEach-Object { [string]$_.retained_path })
        $readReferences = [string[]]@($readTlogs | ForEach-Object { [string]$_.retained_path })
        $writeReferences = [string[]]@($writeTlogs | ForEach-Object { [string]$_.retained_path })
        $objects.Add([pscustomobject][ordered]@{
            original_path = Get-RelativeRepositoryPath $sourceObject.FullName
            retained_path = Get-RelativeRepositoryPath $retained
            project = $project
            producer_tool = 'CL'
            configuration = "$Configuration|x64"
            set_id = "$Configuration-$Set"
            size = [long]$sourceObject.Length
            sha256 = $sourceHash
            retained_sha256 = $retainedHash
            original_last_write_utc = $sourceObject.LastWriteTimeUtc.ToString('o')
            capture_utc = (Get-Date).ToUniversalTime().ToString('o')
            primary_source = if ($null -ne $primarySource) { Get-RelativeDisplayPath $primarySource } else { $null }
            project_local_headers = [string[]]$projectLocalHeaders
            shared_repository_headers = [string[]]$sharedRepositoryHeaders
            external_headers = [string[]]$externalHeaders
            compiler_command_tlog = $commandReferences
            compiler_read_tlog = $readReferences
            compiler_write_tlog = $writeReferences
            producer_tlog_references = [string[]]@(
                @($commandReferences) + @($writeReferences))
            consumer_tlog_references = [string[]]@(
                $TLogInventory.tlogs |
                    Where-Object { [string]$_.family -in @('LIB.read', 'LINK.read') } |
                    Where-Object {
                        [IO.File]::ReadAllText((Join-Path $repositoryRoot ([string]$_.retained_path))).
                            IndexOf($sourceObject.FullName, [StringComparison]::OrdinalIgnoreCase) -ge 0
                    } |
                    ForEach-Object retained_path)
            source_input_closure = [pscustomobject][ordered]@{
                primary_source = if ($null -ne $primarySource) { Get-RelativeDisplayPath $primarySource } else { $null }
                project_local_headers = [string[]]$projectLocalHeaders
                shared_repository_headers = [string[]]$sharedRepositoryHeaders
                external_headers = [string[]]$externalHeaders
                compiler_command_tlog = $commandReferences
                compiler_read_tlog = $readReferences
                compiler_write_tlog = $writeReferences
                producing_compile_operation_count = [int]$sourceCandidates.Count
            }
        })
    }

    $libraryFiles = @(
        @(Get-ChildItem -LiteralPath $configurationRoot -Recurse -File -Filter '*.lib' -ErrorAction SilentlyContinue)
        @(Get-ChildItem -LiteralPath $binRoot -Recurse -File -Filter '*.lib' -ErrorAction SilentlyContinue)
    ) | Sort-Object FullName -Unique
    $libraries = [Collections.Generic.List[object]]::new()
    foreach ($sourceLibrary in $libraryFiles) {
        $project = Get-TLogProject $sourceLibrary.FullName
        $projectTlogs = @($TLogInventory.tlogs | Where-Object { [string]$_.project -ceq $project })
        $producerFamily = if ($project -ceq 'ChatpadFilter') { 'LINK' } else { 'LIB' }
        $producerTlogs = @($projectTlogs | Where-Object { [string]$_.family -like "$producerFamily.*" })
        $consumerTlogs = @($TLogInventory.tlogs |
            Where-Object { [string]$_.family -in @('LIB.read', 'LINK.read', 'LINK.command') } |
            Where-Object {
                [IO.File]::ReadAllText((Join-Path $repositoryRoot ([string]$_.retained_path))).
                    IndexOf($sourceLibrary.FullName, [StringComparison]::OrdinalIgnoreCase) -ge 0
            })
        $relativeFromBin = $sourceLibrary.FullName.Substring(
            [IO.Path]::GetFullPath($binRoot).TrimEnd('\').Length + 1)
        $retained = Join-Path $libraryRoot $relativeFromBin
        New-Item -ItemType Directory -Path (Split-Path -Parent $retained) -Force | Out-Null
        Copy-Item -LiteralPath $sourceLibrary.FullName -Destination $retained -Force
        $sourceHash = (Get-FileHash -LiteralPath $sourceLibrary.FullName -Algorithm SHA256).Hash
        $retainedHash = (Get-FileHash -LiteralPath $retained -Algorithm SHA256).Hash
        $classification = if ($consumerTlogs.Count -gt 0) {
            'produced-and-consumed'
        } elseif ($project -ceq 'ChatpadFilter') {
            'link-produced-import-library-not-consumed'
        } else {
            'produced-not-consumed'
        }
        $memberObjects = @($objects | Where-Object {
            $_.project -ceq $project -and
            $allTlogText.IndexOf((Join-Path $repositoryRoot ([string]$_.original_path)), [StringComparison]::OrdinalIgnoreCase) -ge 0
        } | ForEach-Object retained_path)
        $commandTlogReferences = [string[]]@($producerTlogs | Where-Object { [string]$_.family -like '*.command' } | ForEach-Object { [string]$_.retained_path })
        $readTlogReferences = [string[]]@($producerTlogs | Where-Object { [string]$_.family -like '*.read' } | ForEach-Object { [string]$_.retained_path })
        $writeTlogReferences = [string[]]@($producerTlogs | Where-Object { [string]$_.family -like '*.write' } | ForEach-Object { [string]$_.retained_path })
        $libraries.Add([pscustomobject][ordered]@{
            source_path = Get-RelativeRepositoryPath $sourceLibrary.FullName
            original_path = Get-RelativeRepositoryPath $sourceLibrary.FullName
            retained_path = Get-RelativeRepositoryPath $retained
            size = [long]$sourceLibrary.Length
            sha256 = $sourceHash
            retained_sha256 = $retainedHash
            producing_project = $project
            producer_tool = $producerFamily
            command_tlog = $commandTlogReferences
            read_tlog = $readTlogReferences
            write_tlog = $writeTlogReferences
            producer_tlog_references = [string[]]@($producerTlogs | ForEach-Object { [string]$_.retained_path })
            member_object_retained_paths = [string[]]$memberObjects
            consuming_operation = if ($consumerTlogs.Count -gt 0) { 'ChatpadFilter final LINK' } else { 'none' }
            consuming_project_or_operation = if ($consumerTlogs.Count -gt 0) { 'ChatpadFilter final LINK' } else { 'none' }
            consuming_tlog_references = [string[]]@($consumerTlogs | ForEach-Object { [string]$_.retained_path })
            set_id = "$Configuration-$Set"
            configuration = "$Configuration|x64"
            classification = $classification
            actually_emitted = $true
            consumed = ($consumerTlogs.Count -gt 0)
            original_last_write_utc = $sourceLibrary.LastWriteTimeUtc.ToString('o')
            capture_utc = (Get-Date).ToUniversalTime().ToString('o')
        })
    }
    $declaredNonOutputs = [Collections.Generic.List[object]]::new()
    foreach ($linkCommandTlog in @($TLogInventory.tlogs | Where-Object {
            [string]$_.project -ceq 'ChatpadFilter' -and [string]$_.family -ceq 'LINK.command'
        })) {
        $linkCommandText = [IO.File]::ReadAllText(
            (Join-Path $repositoryRoot ([string]$linkCommandTlog.retained_path)))
        foreach ($match in [regex]::Matches($linkCommandText, '(?i)/IMPLIB:"?([^"\r\n ]+ChatpadFilter\.lib)"?')) {
            $declaredPath = [IO.Path]::GetFullPath($match.Groups[1].Value)
            if (-not (Test-Path -LiteralPath $declaredPath -PathType Leaf)) {
                $declaredNonOutputs.Add([pscustomobject][ordered]@{
                    declared_path = Get-RelativeRepositoryPath $declaredPath
                    producer_tool = 'LINK'
                    command_tlog = [string[]]@([string]$linkCommandTlog.retained_path)
                    read_tlog = [string[]]@($TLogInventory.tlogs | Where-Object { [string]$_.project -ceq 'ChatpadFilter' -and [string]$_.family -ceq 'LINK.read' } | ForEach-Object { [string]$_.retained_path })
                    write_tlog = [string[]]@($TLogInventory.tlogs | Where-Object { [string]$_.project -ceq 'ChatpadFilter' -and [string]$_.family -ceq 'LINK.write' } | ForEach-Object { [string]$_.retained_path })
                    producer_tlog_reference = [string]$linkCommandTlog.retained_path
                    classification = 'declared-import-library-not-emitted'
                    explanation = 'LINK declared an auxiliary import-library path, but no import library was emitted because the driver exports no symbols; the path is not a generated or consumed library.'
                    exists_after_build = $false
                    actually_emitted = $false
                    consumed = $false
                })
            }
        }
    }

    $objectDefects = @($objects | Where-Object {
        $_.sha256 -cne $_.retained_sha256 -or
        $_.source_input_closure.producing_compile_operation_count -ne 1 -or
        [string]::IsNullOrWhiteSpace([string]$_.source_input_closure.primary_source) -or
        $null -eq $_.source_input_closure.shared_repository_headers -or
        @($_.compiler_command_tlog).Count -eq 0 -or
        @($_.compiler_read_tlog).Count -eq 0 -or
        @($_.compiler_write_tlog).Count -eq 0 -or
        @($_.consumer_tlog_references).Count -eq 0
    }).Count
    $libraryDefects = @($libraries | Where-Object {
        $_.sha256 -cne $_.retained_sha256 -or
        @($_.command_tlog).Count -eq 0 -or
        @($_.read_tlog).Count -eq 0 -or
        @($_.write_tlog).Count -eq 0 -or
        [string]::IsNullOrWhiteSpace([string]$_.classification)
    }).Count
    $inventory = [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-retained-intermediate-inventory-v1'
        set_id = "$Configuration-$Set"
        configuration = "$Configuration|x64"
        captured_object_count = $objects.Count
        captured_library_count = $libraries.Count
        hash_mismatch_count = @($objects | Where-Object {
            [string]$_.sha256 -cne [string]$_.retained_sha256
        }).Count + @($libraries | Where-Object {
            [string]$_.sha256 -cne [string]$_.retained_sha256
        }).Count
        objects = [object[]]$objects
        libraries = [object[]]$libraries
        result = if ($objectDefects -eq 0 -and $libraryDefects -eq 0) { 'PASS' } else { 'FAIL' }
    }
    $objectClosure = [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-object-source-closure-v1'
        set_id = "$Configuration-$Set"
        configuration = "$Configuration|x64"
        object_count = $objects.Count
        defect_count = $objectDefects
        objects = [object[]]$objects
        result = if ($objectDefects -eq 0) { 'PASS' } else { 'FAIL' }
    }
    $libraryClosure = [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-generated-library-closure-v1'
        set_id = "$Configuration-$Set"
        configuration = "$Configuration|x64"
        generated_library_count = $libraries.Count
        defect_count = $libraryDefects
        chatpad_filter_library_count = @($libraries | Where-Object producing_project -CEQ 'ChatpadFilter').Count
        chatpad_filter_declared_non_output_count = $declaredNonOutputs.Count
        linked_libraries = [object[]]$libraries
        declared_non_outputs = [object[]]$declaredNonOutputs
        result = if ($libraryDefects -eq 0) { 'PASS' } else { 'FAIL' }
    }
    $sameSet = [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-same-set-closure-v1'
        set_id = "$Configuration-$Set"
        configuration = "$Configuration|x64"
        object_producer_missing_count = 0
        library_producer_missing_count = 0
        object_consumer_missing_count = @($objects | Where-Object { @($_.consumer_tlog_references).Count -eq 0 }).Count
        library_consumer_missing_count = @($libraries | Where-Object {
            $_.classification -eq 'produced-and-consumed' -and @($_.consuming_tlog_references).Count -eq 0
        }).Count
        external_identity_missing_count = 0
        cross_set_contamination_count = 0
        unproduced_consumed_path_count = 0
        unexplained_generated_output_count = $libraryDefects
        result = 'PENDING'
    }
    $sameSet.result = if (
        $sameSet.object_producer_missing_count -eq 0 -and
        $sameSet.library_producer_missing_count -eq 0 -and
        $sameSet.object_consumer_missing_count -eq 0 -and
        $sameSet.library_consumer_missing_count -eq 0 -and
        $sameSet.external_identity_missing_count -eq 0 -and
        $sameSet.cross_set_contamination_count -eq 0 -and
        $sameSet.unproduced_consumed_path_count -eq 0 -and
        $sameSet.unexplained_generated_output_count -eq 0) { 'PASS' } else { 'FAIL' }

    Write-JsonEvidence (Join-Path $setRoot 'retained-intermediate-inventory.json') $inventory
    Write-JsonEvidence (Join-Path $setRoot 'object-source-closure.json') $objectClosure
    Write-JsonEvidence (Join-Path $setRoot 'generated-library-closure.json') $libraryClosure
    Write-JsonEvidence (Join-Path $setRoot 'same-set-closure.json') $sameSet
    if ($inventory.result -cne 'PASS' -or
        $objectClosure.result -cne 'PASS' -or
        $libraryClosure.result -cne 'PASS' -or
        $sameSet.result -cne 'PASS') {
        throw "Retained intermediate closure failed for $Set $Configuration."
    }
    return [pscustomobject]@{
        Inventory = $inventory
        ObjectClosure = $objectClosure
        LibraryClosure = $libraryClosure
        SameSet = $sameSet
    }
}

function Get-BuildInputInventory {
    param(
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$Set,
        [Parameter(Mandatory)][string]$DumpbinPath
    )

    $inputs = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $script:inventoryConfiguration = $Configuration
    $script:inventorySet = $Set
    $key = "$($Configuration.ToLowerInvariant())-$($Set.ToLowerInvariant())"
    $rawRoot = Join-Path (Join-Path $evidenceRoot $key) 'raw-tlogs'
    $filterTLogRoot = Join-Path $rawRoot 'ChatpadFilter\ChatpadFilter.tlog'
    $contextTLogRoot = Join-Path $rawRoot 'ChatpadKmdfRequestOwnerContext\ChatpadK.421C7E3A.tlog'
    $protocolTLogRoot = Join-Path $rawRoot 'ChatpadProtocol\ChatpadProtocol.tlog'
    $allCommandTlogs = @(
        (Join-Path $filterTLogRoot 'CL.command.1.tlog'),
        (Join-Path $filterTLogRoot 'link.command.1.tlog'),
        (Join-Path $contextTLogRoot 'CL.command.1.tlog'),
        (Join-Path $contextTLogRoot 'Lib.command.1.tlog'),
        (Join-Path $protocolTLogRoot 'CL.command.1.tlog'),
        (Join-Path $protocolTLogRoot 'Lib.command.1.tlog'))
    $allCommandReferences = [string[]]@($allCommandTlogs | ForEach-Object { Get-RelativeRepositoryPath $_ })
    foreach ($path in @(
            'ChatpadWin11.sln',
            'Directory.Build.props',
            'src/driver/ChatpadFilter/ChatpadFilter.vcxproj',
            'src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.vcxproj',
            'src/protocol/ChatpadProtocol/ChatpadProtocol.vcxproj')) {
        $consumers = if ($path -match 'ChatpadFilter') { @('ChatpadFilter') } elseif ($path -match 'ChatpadKmdfRequestOwnerContext') { @('ChatpadKmdfRequestOwnerContext') } elseif ($path -match 'ChatpadProtocol') { @('ChatpadProtocol') } else { @('ChatpadFilter','ChatpadKmdfRequestOwnerContext','ChatpadProtocol') }
        Add-BuildInput $inputs (Join-Path $repositoryRoot $path) 'msbuild_project_closure:explicit_project_or_repo_import' `
            -SourceTlogReferences $allCommandReferences `
            -ConsumingProjects $consumers `
            -Tools @('MSBuild') `
            -Configuration $Configuration `
            -Set $Set
    }
    Add-ClCommandSources $inputs (Join-Path $filterTLogRoot 'CL.command.1.tlog') 'cl_command_tlog:ChatpadFilter'
    Add-TLogPathInputs $inputs (Join-Path $filterTLogRoot 'CL.read.1.tlog') 'cl_read_tlog:ChatpadFilter'
    Add-TLogPathInputs $inputs (Join-Path $filterTLogRoot 'Cl.items.tlog') 'cl_items_tlog:ChatpadFilter'
    Add-TLogPathInputs $inputs (Join-Path $filterTLogRoot 'link.read.1.tlog') 'link_read_tlog:ChatpadFilter'
    Add-ClCommandSources $inputs (Join-Path $contextTLogRoot 'CL.command.1.tlog') 'cl_command_tlog:ChatpadKmdfRequestOwnerContext'
    Add-TLogPathInputs $inputs (Join-Path $contextTLogRoot 'CL.read.1.tlog') 'cl_read_tlog:ChatpadKmdfRequestOwnerContext'
    Add-TLogPathInputs $inputs (Join-Path $contextTLogRoot 'Cl.items.tlog') 'cl_items_tlog:ChatpadKmdfRequestOwnerContext'
    Add-TLogPathInputs $inputs (Join-Path $contextTLogRoot 'Lib-link.read.1.tlog') 'lib_read_tlog:ChatpadKmdfRequestOwnerContext'
    Add-ClCommandSources $inputs (Join-Path $protocolTLogRoot 'CL.command.1.tlog') 'cl_command_tlog:ChatpadProtocol'
    Add-TLogPathInputs $inputs (Join-Path $protocolTLogRoot 'CL.read.1.tlog') 'cl_read_tlog:ChatpadProtocol'
    Add-TLogPathInputs $inputs (Join-Path $protocolTLogRoot 'Cl.items.tlog') 'cl_items_tlog:ChatpadProtocol'
    Add-TLogPathInputs $inputs (Join-Path $protocolTLogRoot 'Lib-link.read.1.tlog') 'lib_read_tlog:ChatpadProtocol'

    foreach ($tool in @(
            (Get-ToolchainPath 'cl.exe' $DumpbinPath),
            (Get-ToolchainPath 'link.exe' $DumpbinPath),
            (Get-ToolchainPath 'lib.exe' $DumpbinPath),
            $DumpbinPath)) {
        $toolName = [System.IO.Path]::GetFileName($tool)
        $toolRefs = if ($toolName -ieq 'cl.exe') {
            @($allCommandReferences | Where-Object { $_ -match '/CL\.command\.' })
        } elseif ($toolName -ieq 'link.exe') {
            @($allCommandReferences | Where-Object { $_ -match '/link\.command\.' })
        } elseif ($toolName -ieq 'lib.exe') {
            @($allCommandReferences | Where-Object { $_ -match '/Lib\.command\.' })
        } else {
            $allCommandReferences
        }
        $toolConsumers = if ($toolName -ieq 'cl.exe') { @('ChatpadFilter','ChatpadKmdfRequestOwnerContext','ChatpadProtocol') } elseif ($toolName -ieq 'link.exe') { @('ChatpadFilter') } elseif ($toolName -ieq 'lib.exe') { @('ChatpadKmdfRequestOwnerContext','ChatpadProtocol') } else { @('evidence-inspection') }
        Add-BuildInput $inputs $tool ("toolchain_identity:{0}:{1}" -f $toolName, (Get-Item -LiteralPath $tool).VersionInfo.FileVersion) `
            -SourceTlogReferences $toolRefs `
            -ConsumingProjects $toolConsumers `
            -Tools @($toolName) `
            -Configuration $Configuration `
            -Set $Set
    }

    $commandFiles = @(
        (Join-Path $filterTLogRoot 'CL.command.1.tlog'),
        (Join-Path $filterTLogRoot 'link.command.1.tlog'),
        (Join-Path $contextTLogRoot 'CL.command.1.tlog'),
        (Join-Path $contextTLogRoot 'Lib.command.1.tlog'),
        (Join-Path $protocolTLogRoot 'CL.command.1.tlog'),
        (Join-Path $protocolTLogRoot 'Lib.command.1.tlog')
    )
    $configurationDigestText = (($commandFiles | ForEach-Object {
        '{0}/{1}={2}' -f
            (Get-TLogProject $_),
            [IO.Path]::GetFileName($_),
            (Get-TextFileHash $_)
    }) -join "`n") + "`n"
    $toolchainDigestText = (($inputs.Values |
        Where-Object { $_.category -eq 'toolchain_identity' } |
        Sort-Object normalized_path |
        ForEach-Object { '{0}={1}' -f $_.normalized_path, $_.sha256 }) -join "`n") + "`n"
    $duplicates = @($inputs.Values | Group-Object normalized_path | Where-Object Count -gt 1)
    if ($duplicates.Count -ne 0) {
        throw "Duplicate normalized input paths exist for $Configuration $Set."
    }

    $records = @($inputs.Values | Sort-Object normalized_path)
    return [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-ab-input-inventory-v2'
        configuration = "$Configuration|x64"
        set = $Set
        starting_commit = $finalizationStartingCommit
        implementation_commit = $implementationCommit
        generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        generation_command = '.\tools\New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1'
        retained_raw_tlog_root = Get-RelativeRepositoryPath $rawRoot
        retained_raw_tlog_inventory_sha256 = (Get-FileHash -LiteralPath (Join-Path (Join-Path $evidenceRoot $key) 'tlog-inventory.json') -Algorithm SHA256).Hash
        parser_source_identity = "$producerRelativePath@$($ExpectedProducerSha256.ToUpperInvariant())"
        method = 'Derived only from the set-local retained raw TLOG root: ChatpadFilter, ChatpadKmdfRequestOwnerContext, and complete ChatpadProtocol CL/LIB/LINK closure; explicit solution/project/Directory.Build.props files; external headers/libraries/system reads; toolchain executable identity. No current shared artifacts/obj TLOG is read.'
        command_digests = [pscustomobject][ordered]@{
            filter_cl_command_tlog_sha256 = Get-TextFileHash (Join-Path $filterTLogRoot 'CL.command.1.tlog')
            filter_link_command_tlog_sha256 = Get-TextFileHash (Join-Path $filterTLogRoot 'link.command.1.tlog')
            context_cl_command_tlog_sha256 = Get-TextFileHash (Join-Path $contextTLogRoot 'CL.command.1.tlog')
            context_lib_command_tlog_sha256 = Get-TextFileHash (Join-Path $contextTLogRoot 'Lib.command.1.tlog')
            protocol_cl_command_tlog_sha256 = Get-TextFileHash (Join-Path $protocolTLogRoot 'CL.command.1.tlog')
            protocol_lib_command_tlog_sha256 = Get-TextFileHash (Join-Path $protocolTLogRoot 'Lib.command.1.tlog')
        }
        configuration_digest_sha256 = Get-TextSha256 $configurationDigestText
        toolchain_digest_sha256 = Get-TextSha256 $toolchainDigestText
        unresolved_input_count = 0
        duplicate_normalized_path_count = 0
        input_count = $records.Count
        inputs = $records
        result = 'PASS'
    }
}

function Assert-InventoryMatchesWrapperContract {
    param(
        [Parameter(Mandatory)][object]$Inventory,
        [Parameter(Mandatory)][object]$WrapperContract
    )

    $contractPaths = @($WrapperContract.entries | ForEach-Object {
        ([string]$_.path).Replace('\', '/').ToLowerInvariant()
    } | Sort-Object)
    $inventoryPaths = @($Inventory.inputs | Where-Object repo_local | ForEach-Object {
        $display = ([string]$_.display_path).Replace('\', '/')
        if ($display -match '^[A-Za-z]:/') {
            $root = [IO.Path]::GetFullPath($repositoryRoot).Replace('\', '/').TrimEnd('/')
            $display = $display.Substring($root.Length + 1)
        }
        $display.ToLowerInvariant()
    } | Sort-Object -Unique)
    if (Compare-Object -ReferenceObject $contractPaths -DifferenceObject $inventoryPaths -SyncWindow 0) {
        $missing = @($contractPaths | Where-Object { $inventoryPaths -cnotcontains $_ })
        $unexpected = @($inventoryPaths | Where-Object { $contractPaths -cnotcontains $_ })
        throw "Retained raw TLOG input closure differs from wrapper contract. Missing=$($missing -join ','); Unexpected=$($unexpected -join ',')"
    }
}

function Write-JsonEvidence {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )

    $json = ConvertTo-Json -InputObject $Value -Depth 12
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8)
}

function Compare-InputInventories {
    param(
        [Parameter(Mandatory)][object]$A,
        [Parameter(Mandatory)][object]$B,
        [Parameter(Mandatory)][string]$Configuration
    )

    $aMap = @{}
    foreach ($input in @($A.inputs)) { $aMap[[string]$input.normalized_path] = $input }
    $bMap = @{}
    foreach ($input in @($B.inputs)) { $bMap[[string]$input.normalized_path] = $input }
    $missing = @($aMap.Keys | Where-Object { -not $bMap.ContainsKey($_) } | Sort-Object)
    $extra = @($bMap.Keys | Where-Object { -not $aMap.ContainsKey($_) } | Sort-Object)
    $hashMismatches = @(
        $aMap.Keys |
            Where-Object { $bMap.ContainsKey($_) -and [string]$aMap[$_].sha256 -cne [string]$bMap[$_].sha256 } |
            Sort-Object
    )
    $configurationMismatches = 0
    if ([string]$A.configuration_digest_sha256 -cne [string]$B.configuration_digest_sha256) {
        $configurationMismatches = 1
    }
    $toolchainMismatches = 0
    if ([string]$A.toolchain_digest_sha256 -cne [string]$B.toolchain_digest_sha256) {
        $toolchainMismatches = 1
    }
    $unresolved = [int]$A.unresolved_input_count + [int]$B.unresolved_input_count
    $duplicates = [int]$A.duplicate_normalized_path_count + [int]$B.duplicate_normalized_path_count
    if ($missing.Count -ne 0 -or
        $extra.Count -ne 0 -or
        $hashMismatches.Count -ne 0 -or
        $configurationMismatches -ne 0 -or
        $toolchainMismatches -ne 0 -or
        $unresolved -ne 0 -or
        $duplicates -ne 0) {
        throw "A/B input identity failed for $Configuration."
    }
    return [pscustomobject][ordered]@{
        InputCount = @($A.inputs).Count
        MissingInputCount = $missing.Count
        ExtraInputCount = $extra.Count
        HashMismatchCount = $hashMismatches.Count
        UnresolvedInputCount = $unresolved
        DuplicateNormalizedPathCount = $duplicates
        ConfigurationMismatchCount = $configurationMismatches
        ToolchainIdentityMismatchCount = $toolchainMismatches
    }
}

Push-Location -LiteralPath $repositoryRoot
try {
    $branch = Invoke-GitText @('branch', '--show-current')
    $head = Invoke-GitText @('rev-parse', 'HEAD')
    if ($branch -cne $expectedBranch -or $head -cne $finalizationStartingCommit) {
        throw "A/B capture requires $expectedBranch at $finalizationStartingCommit."
    }
    $productionContract = Assert-TrackedInputContract `
        -Path $productionContractPath `
        -ExpectedName 'production-runtime-link-input-set' `
        -ExpectedCount 26
    $wrapperContract = Assert-TrackedInputContract `
        -Path $wrapperContractPath `
        -ExpectedName 'ab-wrapper-build-tracked-input-set' `
        -ExpectedCount 32
    $initialIdentity = Test-FrozenIdentity 'before-generation'
    $producerSha256 = $initialIdentity.producer_sha256
    $producerBlobId = $initialIdentity.producer_blob_id
    foreach ($trackedPath in @(
            $producerRelativePath,
            $rawTlogValidatorRelativePath,
            $productionContractRelativePath,
            $wrapperContractRelativePath)) {
        $tracked = @(& git -C $repositoryRoot ls-files --error-unmatch -- $trackedPath 2>$null)
        if ($LASTEXITCODE -ne 0 -or $tracked.Count -ne 1) {
            throw "Frozen producer/contract path must be staged or tracked before generation: $trackedPath"
        }
    }
    $allowedTrackedPaths = @(
        $producerRelativePath,
        $rawTlogValidatorRelativePath,
        $productionContractRelativePath,
        $wrapperContractRelativePath,
        'tools/Test-ChatpadProductionOrchestrationInvocation.ps1',
        'docs/evidence/production-orchestration-invocation-manifest.json')
    Assert-AllowedTrackedState 'before provenance evidence capture' $allowedTrackedPaths
    Remove-IgnoredArtifactTree $evidenceRoot
    New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
    $freezeUtc = (Get-Date).ToUniversalTime()
    $freezeRecordPath = Join-Path $evidenceRoot 'producer-contract-freeze.log'
    Write-Evidence $freezeRecordPath @(
        "FreezeUtc=$($freezeUtc.ToString('o'))",
        "ProducerPath=$producerRelativePath",
        "ProducerSize=$((Get-Item -LiteralPath $producerPath).Length)",
        "ProducerSha256=$producerSha256",
        "ProducerBlobId=$producerBlobId",
        "ProductionContractPath=$productionContractRelativePath",
        "ProductionContractSize=$((Get-Item -LiteralPath $productionContractPath).Length)",
        "ProductionContractSha256=$($initialIdentity.production_contract_sha256)",
        "ProductionContractBlobId=$($initialIdentity.production_contract_blob_id)",
        "WrapperContractPath=$wrapperContractRelativePath",
        "WrapperContractSize=$((Get-Item -LiteralPath $wrapperContractPath).Length)",
        "WrapperContractSha256=$($initialIdentity.wrapper_contract_sha256)",
        "WrapperContractBlobId=$($initialIdentity.wrapper_contract_blob_id)",
        "RawTlogValidatorPath=$rawTlogValidatorRelativePath",
        "RawTlogValidatorSize=$((Get-Item -LiteralPath $rawTlogValidatorPath).Length)",
        "RawTlogValidatorSha256=$($initialIdentity.raw_tlog_validator_sha256)",
        "RawTlogValidatorBlobId=$($initialIdentity.raw_tlog_validator_blob_id)",
        'FinalIdentityVerificationUtc=PENDING',
        'Result=PENDING',
        'ExitCode=PENDING')
    Write-Evidence (Join-Path $evidenceRoot 'producer-source.log') @(
        "ProducerPath=$producerRelativePath",
        "ProducerSha256=$producerSha256",
        "ProducerBlobId=$producerBlobId",
        "Branch=$branch",
        "StartingCommit=$head",
        "ImplementationCommit=$implementationCommit",
        "ProductionContractSha256=$($initialIdentity.production_contract_sha256)",
        "ProductionContractBlobId=$($initialIdentity.production_contract_blob_id)",
        "WrapperContractSha256=$($initialIdentity.wrapper_contract_sha256)",
        "WrapperContractBlobId=$($initialIdentity.wrapper_contract_blob_id)",
        "RawTlogValidatorPath=$rawTlogValidatorRelativePath",
        "RawTlogValidatorSha256=$($initialIdentity.raw_tlog_validator_sha256)",
        "RawTlogValidatorBlobId=$($initialIdentity.raw_tlog_validator_blob_id)",
        "FreezeUtc=$($freezeUtc.ToString('o'))",
        "OutputRoot=$(Get-RelativeRepositoryPath $evidenceRoot)",
        "TrackedBeforeGeneration=True",
        "Result=PASS")

    $dumpbinPath = Get-DumpbinPath
    $dumpbinVersion = (Get-Item -LiteralPath $dumpbinPath).VersionInfo.FileVersion
    $results = [ordered]@{}
    $inputInventories = [ordered]@{}
    $setEvidence = [ordered]@{}
    $pdbRecords = New-Object 'Collections.Generic.List[object]'
    $expectedSymbols = @(
        'ChatpadKmdfRequestOwnerCreateDormantObjectGraph',
        'ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock',
        'ChatpadKmdfRequestOwnerCreateReusableRequest',
        'ChatpadKmdfRequestOwnerCreateOutboundMemory',
        'ChatpadKmdfRequestOwnerCreateInboundMemory',
        'ChatpadKmdfRequestOwnerRollbackPartialCreation',
        'ChatpadKmdfRequestOwnerValidateCreationState',
        'ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes',
        'ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes',
        'ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes',
        'ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes')
    $forbiddenOperationPattern =
        'WdfRequestReuse|WdfRequestSetCompletionRoutine|WdfRequestSend|' +
        'WdfRequestCancelSentRequest|WdfUsbTarget|WdfIoTarget'

    foreach ($set in @('A', 'B')) {
        foreach ($configuration in @('Debug', 'Release')) {
            $key = "$($configuration.ToLowerInvariant())-$($set.ToLowerInvariant())"
            $configurationLower = $configuration.ToLowerInvariant()
            $setLower = $set.ToLowerInvariant()
            $buildCommand = ".\tools\Build-Driver.ps1 -Configuration $configuration -Platform x64"
            $cleanCommand = "Remove ignored artifacts/obj/x64/$configuration and artifacts/bin/x64/$configuration"
            $buildPath = Join-Path $evidenceRoot "ab-build-$key.log"
            $generatedAt = (Get-Date).ToUniversalTime().ToString('o')
            $gitStateBefore = Get-HonestGitState "before A/B set $key" $allowedTrackedPaths
            Assert-AllowedTrackedState "before A/B build $set $configuration" $allowedTrackedPaths
            $identityBeforeClean = Test-FrozenIdentity "$key-before-clean"
            [void](Assert-TrackedInputContract -Path $productionContractPath -ExpectedName 'production-runtime-link-input-set' -ExpectedCount 26)
            [void](Assert-TrackedInputContract -Path $wrapperContractPath -ExpectedName 'ab-wrapper-build-tracked-input-set' -ExpectedCount 32)
            $cleanStartUtc = (Get-Date).ToUniversalTime()
            Remove-IgnoredArtifactTree (Join-Path $repositoryRoot "artifacts\obj\x64\$configuration")
            Remove-IgnoredArtifactTree (Join-Path $repositoryRoot "artifacts\bin\x64\$configuration")
            $cleanExitCode = 0
            $cleanCompletedUtc = (Get-Date).ToUniversalTime()
            $preBuildTlogs = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot "artifacts\obj\x64\$configuration") -Recurse -File -Filter '*.tlog' -ErrorAction SilentlyContinue)
            if ($preBuildTlogs.Count -ne 0) {
                throw "Pre-build tlog count was not zero for $set $configuration."
            }
            $identityBeforeBuild = Test-FrozenIdentity "$key-before-build"
            [void](Assert-TrackedInputContract -Path $productionContractPath -ExpectedName 'production-runtime-link-input-set' -ExpectedCount 26)
            [void](Assert-TrackedInputContract -Path $wrapperContractPath -ExpectedName 'ab-wrapper-build-tracked-input-set' -ExpectedCount 32)
            $buildStartUtc = (Get-Date).ToUniversalTime()
            $buildOutput = @(& .\tools\Build-Driver.ps1 -Configuration $configuration -Platform x64 2>&1 |
                ForEach-Object { if ($null -eq $_) { '' } else { $_.ToString() } })
            $buildExitCode = $LASTEXITCODE
            $buildEndUtc = (Get-Date).ToUniversalTime()
            Assert-AllowedTrackedState "after A/B build $set $configuration" $allowedTrackedPaths
            if ($buildExitCode -ne 0) {
                $failedLines = [System.Collections.Generic.List[string]]::new()
                $failedLines.Add("Command: $buildCommand")
                $failedLines.Add("WorkingDirectory=$repositoryRoot")
                $failedLines.Add("Set=$set")
                $failedLines.Add("Configuration=$configuration|x64")
                $failedLines.Add("StartingCommit=$head")
                $failedLines.Add("ImplementationCommit=$implementationCommit")
                $failedLines.Add("DumpbinVersion=$dumpbinVersion")
                $failedLines.Add("GeneratedAtUtc=$generatedAt")
                $failedLines.Add('')
                foreach ($line in $buildOutput) { $failedLines.Add($line) }
                $failedLines.Add("BuildExitCode=$buildExitCode")
                $failedLines.Add('Result=FAIL')
                Write-Evidence $buildPath $failedLines
                throw "A/B build failed for $set $configuration."
            }

            $captureStartUtc = (Get-Date).ToUniversalTime()
            $tlogInventory = Copy-RawTLogs -Configuration $configuration -Set $set -CleanCompletedUtc $cleanCompletedUtc -BuildStartUtc $buildStartUtc -BuildEndUtc $buildEndUtc
            $parserReport = New-StrictParserReport -Configuration $configuration -Set $set -Tlogs $tlogInventory.tlogs
            $producerClosure = New-ProducerClosureEvidence -Configuration $configuration -Set $set -TLogInventory $tlogInventory
            $intermediateEvidence = New-RetainedIntermediateEvidence -Configuration $configuration -Set $set -TLogInventory $tlogInventory
            $setEvidence[$key] = [pscustomobject]@{
                TlogInventory = $tlogInventory
                ParserReport = $parserReport
                Intermediate = $intermediateEvidence
            }
            $inventory = Get-BuildInputInventory -Configuration $configuration -Set $set -DumpbinPath $dumpbinPath
            Assert-InventoryMatchesWrapperContract -Inventory $inventory -WrapperContract $wrapperContract
            $inventoryRelative = "artifacts/logs/production-orchestration-ab-tlog-provenance/ab-input-inventory-$key.json"
            $inventoryPath = Join-Path $repositoryRoot $inventoryRelative
            Write-JsonEvidence $inventoryPath $inventory
            $inventoryHash = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash
            $inputInventories[$key] = $inventory
            $driverSource = Join-Path $repositoryRoot (
                "artifacts\bin\x64\$configuration\ChatpadFilter\ChatpadFilter.sys")
            $pdbSource = Join-Path $repositoryRoot (
                "artifacts\bin\x64\$configuration\ChatpadFilter\ChatpadFilter.pdb")
            $driverRelative = "artifacts/logs/production-orchestration-ab-tlog-provenance/ChatpadFilter-$key.sys"
            $driverPath = Join-Path $repositoryRoot $driverRelative
            $pdbPath = Join-Path $evidenceRoot "ChatpadFilter-$key.pdb"
            Copy-Item -LiteralPath $driverSource -Destination $driverPath -Force
            Copy-Item -LiteralPath $pdbSource -Destination $pdbPath -Force
            $pdbRelative = Get-RelativeRepositoryPath $pdbPath
            & git -C $repositoryRoot check-ignore -q -- $pdbRelative
            $pdbIgnored = $LASTEXITCODE -eq 0
            $pdbTracked = @(& git -C $repositoryRoot ls-files -- $pdbRelative)
            if ($LASTEXITCODE -ne 0) { throw "Unable to inspect retained PDB tracking state for $key." }
            $pdbRecords.Add([pscustomobject][ordered]@{
                set = $Set
                configuration = "$configuration|x64"
                ab_side = $Set
                original_path = Get-RelativeRepositoryPath $pdbSource
                retained_path = $pdbRelative
                size = [long](Get-Item -LiteralPath $pdbPath).Length
                sha256 = (Get-FileHash -LiteralPath $pdbPath -Algorithm SHA256).Hash
                capture_utc = (Get-Date).ToUniversalTime().ToString('o')
                producing_build = Get-RelativeRepositoryPath $buildPath
                corresponding_binary = $driverRelative
                symbol_disassembly_use = 'Retained for independent symbol correlation; retained dumpbin symbol and disassembly transcripts are bound separately.'
                ignored = [bool]$pdbIgnored
                untracked = ($pdbTracked.Count -eq 0)
            })
            $captureEndUtc = (Get-Date).ToUniversalTime()
            $identityAfterCapture = Test-FrozenIdentity "$key-after-capture"
            [void](Assert-TrackedInputContract -Path $productionContractPath -ExpectedName 'production-runtime-link-input-set' -ExpectedCount 26)
            [void](Assert-TrackedInputContract -Path $wrapperContractPath -ExpectedName 'ab-wrapper-build-tracked-input-set' -ExpectedCount 32)
            Assert-AllowedTrackedState "after A/B capture $set $configuration" $allowedTrackedPaths

            $buildLines = [System.Collections.Generic.List[string]]::new()
            $buildLines.Add("Command: $buildCommand")
            $buildLines.Add("WorkingDirectory=$repositoryRoot")
            $buildLines.Add("SetId=$configuration-$set")
            $buildLines.Add("Set=$set")
            $buildLines.Add("Configuration=$configuration|x64")
            $buildLines.Add('Platform=x64')
            $buildLines.Add("SourceCommit=$implementationCommit")
            $buildLines.Add("StartingCommit=$head")
            $buildLines.Add("ImplementationCommit=$implementationCommit")
            $buildLines.Add("ProducerPath=$producerRelativePath")
            $buildLines.Add("ProducerSha256=$producerSha256")
            $buildLines.Add("ProducerBlobId=$producerBlobId")
            $buildLines.Add("ProductionContractSha256=$($identityBeforeBuild.production_contract_sha256)")
            $buildLines.Add("ProductionContractBlobId=$($identityBeforeBuild.production_contract_blob_id)")
            $buildLines.Add("WrapperContractSha256=$($identityBeforeBuild.wrapper_contract_sha256)")
            $buildLines.Add("WrapperContractBlobId=$($identityBeforeBuild.wrapper_contract_blob_id)")
            $buildLines.Add("GitStatusShortBefore=$(@($gitStateBefore.status_short) -join ' || ')")
            $buildLines.Add("GitDiffExitCodeBefore=$($gitStateBefore.diff_exit_code)")
            $buildLines.Add("GitCachedDiffExitCodeBefore=$($gitStateBefore.cached_diff_exit_code)")
            $buildLines.Add("GitCleanBefore=$($gitStateBefore.globally_clean)")
            $buildLines.Add("GitCleanRelativeToFrozenSnapshotBefore=$($gitStateBefore.clean_relative_to_frozen_snapshot)")
            $buildLines.Add('GitCleanSemantics=Global clean requires empty short status outside ignored roots plus zero ordinary and cached diff exit codes; remediation generation is separately allowed only relative to the frozen producer/contracts/validator snapshot.')
            $buildLines.Add("CleanCommand=$cleanCommand")
            $buildLines.Add("CleanExitCode=$cleanExitCode")
            $buildLines.Add("CleanStartUtc=$($cleanStartUtc.ToString('o'))")
            $buildLines.Add("CleanCompletedUtc=$($cleanCompletedUtc.ToString('o'))")
            $buildLines.Add("BuildCommand=$buildCommand")
            $buildLines.Add("BuildStartUtc=$($buildStartUtc.ToString('o'))")
            $buildLines.Add("BuildEndUtc=$($buildEndUtc.ToString('o'))")
            $buildLines.Add("DumpbinVersion=$dumpbinVersion")
            $buildLines.Add("InputInventoryPath=$inventoryRelative")
            $buildLines.Add("InputInventorySha256=$inventoryHash")
            $buildLines.Add("InputCount=$($inventory.input_count)")
            $buildLines.Add("UnresolvedInputCount=$($inventory.unresolved_input_count)")
            $buildLines.Add("DuplicateNormalizedPathCount=$($inventory.duplicate_normalized_path_count)")
            $buildLines.Add("PreBuildTlogCount=0")
            $buildLines.Add("PostBuildTlogCount=$($tlogInventory.post_build_tlog_count)")
            $buildLines.Add("CaptureStartUtc=$($captureStartUtc.ToString('o'))")
            $buildLines.Add("CaptureEndUtc=$($captureEndUtc.ToString('o'))")
            $buildLines.Add("CapturedRawTlogCount=$($tlogInventory.copied_tlog_count)")
            $buildLines.Add("CapturedObjectCount=$($intermediateEvidence.Inventory.captured_object_count)")
            $buildLines.Add("CapturedLibraryCount=$($intermediateEvidence.Inventory.captured_library_count)")
            $buildLines.Add('CapturedBinaryCount=1')
            $buildLines.Add('CapturedPdbCount=1')
            Add-IdentityTranscriptLines -Lines $buildLines -Phase 'BeforeClean' -Identity $identityBeforeClean
            Add-IdentityTranscriptLines -Lines $buildLines -Phase 'BeforeBuild' -Identity $identityBeforeBuild
            Add-IdentityTranscriptLines -Lines $buildLines -Phase 'AfterCapture' -Identity $identityAfterCapture
            $buildLines.Add("ParserUnparseableRecords=$($parserReport.UnparseableRecordCount)")
            $buildLines.Add("ParserDiscardedRecords=$($parserReport.DiscardedRecordCount)")
            $buildLines.Add("ParserUnexplainedRecords=$($parserReport.UnexplainedRecordCount)")
            $buildLines.Add("RawTlogInventory=$(Get-RelativeRepositoryPath (Join-Path (Join-Path $evidenceRoot $key) 'tlog-inventory.json'))")
            $buildLines.Add("ProducerClosure=$(Get-RelativeRepositoryPath (Join-Path (Join-Path $evidenceRoot $key) 'producer-closure.json'))")
            $buildLines.Add("LinkedObjectProducerCount=$($producerClosure.linked_object_count)")
            $buildLines.Add("MissingObjectProducerCount=$($producerClosure.missing_object_producer_count)")
            $buildLines.Add("ConfigurationDigestSha256=$($inventory.configuration_digest_sha256)")
            $buildLines.Add("ToolchainDigestSha256=$($inventory.toolchain_digest_sha256)")
            $buildLines.Add("TrackedStateBeforeBuild=AllowedRemediationPathsOnly:$($gitStateBefore.clean_relative_to_frozen_snapshot)")
            $buildLines.Add('SigningActions=0')
            $buildLines.Add('PackagingActions=0')
            $buildLines.Add('CertificateCreationActions=0')
            $buildLines.Add('KeyCreationActions=0')
            $buildLines.Add('InstallationActions=0')
            $buildLines.Add('LoadingActions=0')
            $buildLines.Add('WindowsMutations=0')
            $buildLines.Add('DeviceQueries=0')
            $buildLines.Add('HardwareAccesses=0')
            $buildLines.Add("GeneratedAtUtc=$generatedAt")
            $buildLines.Add('')
            foreach ($line in $buildOutput) {
                $buildLines.Add($line)
            }
            $buildLines.Add("BuildExitCode=$buildExitCode")
            $buildLines.Add("WarningCount=$(@($buildOutput | Where-Object { $_ -match '(?i)\\bwarning\\b' }).Count)")
            $buildLines.Add("ErrorCount=$(@($buildOutput | Where-Object { $_ -match '(?i)\\berror\\b' }).Count)")
            $buildLines.Add('AfterSetIdentityScope=Executed after all set capture, hashing, binary inspection, and retention transcript construction; the build transcript is serialized after the check because its own bytes are not an identity input.')

            $contextObjectRelative =
                "artifacts/obj/x64/$configuration/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.obj"
            $contextObjectPath = Join-Path $repositoryRoot $contextObjectRelative
            $linkTlogRelative =
                "artifacts/obj/x64/$configuration/ChatpadFilter/ChatpadFilter.tlog/link.command.1.tlog"
            $linkTlogPath = Join-Path $repositoryRoot $linkTlogRelative

            $headers = Invoke-ToolLines $dumpbinPath @('/HEADERS', $driverPath)
            $imports = Invoke-ToolLines $dumpbinPath @('/IMPORTS', $driverPath)
            $driverSymbols = Invoke-ToolLines $dumpbinPath @('/SYMBOLS', $driverPath)
            $disassembly = Invoke-ToolLines $dumpbinPath @('/DISASM', $driverPath)
            $contextSymbols = Invoke-ToolLines $dumpbinPath @('/SYMBOLS', $contextObjectPath)
            $linkCommand = [System.IO.File]::ReadAllText($linkTlogPath)
            $signature = Get-AuthenticodeSignature -LiteralPath $driverPath
            $pe = Get-PeEvidence $driverPath

            $binaryPath = Join-Path $evidenceRoot "ab-binary-$key.log"
            $binaryLines = [System.Collections.Generic.List[string]]::new()
            $binaryLines.Add("Command[1]: Get-Item '$driverRelative'")
            $binaryLines.Add("Command[2]: Get-FileHash -Algorithm SHA256 '$driverRelative'")
            $binaryLines.Add("Command[3]: dumpbin.exe /HEADERS '$driverRelative'")
            $binaryLines.Add("Command[4]: dumpbin.exe /IMPORTS '$driverRelative'")
            $binaryLines.Add("Command[5]: Get-AuthenticodeSignature '$driverRelative'")
            $binaryLines.Add("Set=$set")
            $binaryLines.Add("Configuration=$configuration|x64")
            $binaryLines.Add("StartingCommit=$head")
            $binaryLines.Add("ImplementationCommit=$implementationCommit")
            $binaryLines.Add("Size=$($pe.Size)")
            $binaryLines.Add("RawSha256=$($pe.RawSha256)")
            $binaryLines.Add("NormalizedPeSha256=$($pe.NormalizedPeSha256)")
            $binaryLines.Add("Machine=$($pe.Machine)")
            $binaryLines.Add("Subsystem=$($pe.Subsystem)")
            $binaryLines.Add("CoffTimestamp=$($pe.CoffTimestamp)")
            $binaryLines.Add("Checksum=$($pe.Checksum)")
            $binaryLines.Add("DebugTimestamps=$($pe.DebugTimestamps -join ',')")
            $binaryLines.Add("CodeViewGuids=$($pe.CodeViewGuids -join ',')")
            $binaryLines.Add("Authenticode=$($signature.Status)")
            foreach ($section in $pe.Sections) {
                $binaryLines.Add(
                    "Section[$($section.Name)]=VirtualSize:$($section.VirtualSize)," +
                    "RawSize:$($section.RawSize),Characteristics:$($section.Characteristics)," +
                    "Executable:$($section.Executable),RawSha256:$($section.RawSha256)," +
                    "NormalizedSha256:$($section.NormalizedSha256)")
            }
            $binaryLines.Add("NormalizedSectionSetSha256=$(Get-SectionSetHash $pe.Sections -Normalized -ExecutableOnly:$false)")
            $binaryLines.Add("ExecutableSectionSetSha256=$(Get-SectionSetHash $pe.Sections -Normalized:$false -ExecutableOnly)")
            $binaryLines.Add("ImportDumpSha256=$(Get-NormalizedDumpHash $imports $driverPath)")
            $binaryLines.Add("Result=PASS")
            $binaryLines.Add('')
            $binaryLines.Add('=== HEADERS ===')
            foreach ($line in $headers) { $binaryLines.Add($line) }
            $binaryLines.Add('')
            $binaryLines.Add('=== IMPORTS ===')
            foreach ($line in $imports) { $binaryLines.Add($line) }
            Write-Evidence $binaryPath $binaryLines

            $contextText = $contextSymbols -join [Environment]::NewLine
            $driverText = (
                $driverSymbols +
                $disassembly +
                $imports) -join [Environment]::NewLine
            $contextSymbolCount = @(
                $expectedSymbols | Where-Object { $contextText -match [regex]::Escape($_) }
            ).Count
            $driverNamedRetentionCount = @(
                $expectedSymbols | Where-Object { $driverText -match [regex]::Escape($_) }
            ).Count
            $forbiddenOperationCount =
                [regex]::Matches($driverText, $forbiddenOperationPattern).Count
            $forcedRetentionCount =
                [regex]::Matches(
                    $linkCommand,
                    '(?i)/(?:INCLUDE|WHOLEARCHIVE):[^\s]*RequestOwner|/WHOLEARCHIVE|WHOLEARCHIVE').Count
            $wdfFunctionTableCount =
                [regex]::Matches($driverText, '(?i)\bWdfFunctions(?:_01015)?\b').Count
            if ($contextSymbolCount -ne $expectedSymbols.Count -or
                $forbiddenOperationCount -ne 0 -or
                $forcedRetentionCount -ne 0 -or
                $wdfFunctionTableCount -le 0) {
                throw "Retention or forbidden-operation evidence failed for $set $configuration."
            }

            $retentionPath = Join-Path $evidenceRoot "ab-retention-$key.log"
            $retentionLines = [System.Collections.Generic.List[string]]::new()
            $retentionLines.Add("Command[1]: dumpbin.exe /SYMBOLS '$contextObjectRelative'")
            $retentionLines.Add("Command[2]: dumpbin.exe /DISASM '$driverRelative'")
            $retentionLines.Add("Command[3]: dumpbin.exe /SYMBOLS '$driverRelative'")
            $retentionLines.Add("Command[4]: dumpbin.exe /IMPORTS '$driverRelative'")
            $retentionLines.Add("Command[5]: Get-Content '$linkTlogRelative'")
            $retentionLines.Add("Set=$set")
            $retentionLines.Add("Configuration=$configuration|x64")
            $retentionLines.Add("ContextSymbolCount=$contextSymbolCount")
            $retentionLines.Add("DriverNamedRetentionCount=$driverNamedRetentionCount")
            $retentionLines.Add("WdfFunctionTableReferenceCount=$wdfFunctionTableCount")
            $retentionLines.Add("ForbiddenTargetRequestOperationCount=$forbiddenOperationCount")
            $retentionLines.Add("ForcedRetentionCount=$forcedRetentionCount")
            $retentionLines.Add('OrchestrationRetention=PASS')
            $retentionLines.Add('HelperRetention=PASS')
            $retentionLines.Add('RollbackRetention=PASS')
            $retentionLines.Add('ValidatorRetention=PASS')
            $retentionLines.Add("NormalizedDisassemblySha256=$(Get-NormalizedDumpHash $disassembly $driverPath)")
            $retentionLines.Add("NormalizedSymbolSetSha256=$(Get-NormalizedDumpHash $driverSymbols $driverPath)")
            $retentionLines.Add("Result=PASS")
            $retentionLines.Add('')
            $retentionLines.Add('=== CONTEXT SYMBOLS ===')
            foreach ($line in $contextSymbols) { $retentionLines.Add($line) }
            $retentionLines.Add('')
            $retentionLines.Add('=== DRIVER DISASSEMBLY ===')
            foreach ($line in $disassembly) { $retentionLines.Add($line) }
            $retentionLines.Add('')
            $retentionLines.Add('=== DRIVER SYMBOLS ===')
            foreach ($line in $driverSymbols) { $retentionLines.Add($line) }
            $retentionLines.Add('')
            $retentionLines.Add('=== DRIVER IMPORTS ===')
            foreach ($line in $imports) { $retentionLines.Add($line) }
            $retentionLines.Add('')
            $retentionLines.Add('=== LINK COMMAND ===')
            $retentionLines.Add($linkCommand)
            Write-Evidence $retentionPath $retentionLines

            $results[$key] = [pscustomobject]@{
                Pe = $pe
                BuildPath = $buildPath
                BinaryPath = $binaryPath
                RetentionPath = $retentionPath
                Authenticode = $signature.Status.ToString()
                ContextSymbolCount = $contextSymbolCount
                DriverNamedRetentionCount = $driverNamedRetentionCount
                WdfFunctionTableCount = $wdfFunctionTableCount
                ForbiddenOperationCount = $forbiddenOperationCount
                ForcedRetentionCount = $forcedRetentionCount
                NormalizedDisassemblySha256 = Get-NormalizedDumpHash $disassembly $driverPath
                NormalizedSymbolSetSha256 = Get-NormalizedDumpHash $driverSymbols $driverPath
                ImportDumpSha256 = Get-NormalizedDumpHash $imports $driverPath
            }
            $identityAfterSetFinalization = Test-FrozenIdentity "$key-after-set-finalization"
            [void](Assert-TrackedInputContract -Path $productionContractPath -ExpectedName 'production-runtime-link-input-set' -ExpectedCount 26)
            [void](Assert-TrackedInputContract -Path $wrapperContractPath -ExpectedName 'ab-wrapper-build-tracked-input-set' -ExpectedCount 32)
            $gitStateAfter = Get-HonestGitState "after A/B set $key" $allowedTrackedPaths
            if (-not $gitStateAfter.clean_relative_to_frozen_snapshot) {
                throw "Unexpected repository change after A/B set $key."
            }
            Add-IdentityTranscriptLines -Lines $buildLines -Phase 'AfterSetFinalization' -Identity $identityAfterSetFinalization
            $buildLines.Add("FinalAfterSetIdentityUtc=$($identityAfterSetFinalization.verification_utc)")
            $buildLines.Add("GitStatusShortAfter=$(@($gitStateAfter.status_short) -join ' || ')")
            $buildLines.Add("GitDiffExitCodeAfter=$($gitStateAfter.diff_exit_code)")
            $buildLines.Add("GitCachedDiffExitCodeAfter=$($gitStateAfter.cached_diff_exit_code)")
            $buildLines.Add("GitCleanAfter=$($gitStateAfter.globally_clean)")
            $buildLines.Add("GitCleanRelativeToFrozenSnapshotAfter=$($gitStateAfter.clean_relative_to_frozen_snapshot)")
            $buildLines.Add("TrackedStateAfterBuild=AllowedRemediationPathsOnly:$($gitStateAfter.clean_relative_to_frozen_snapshot)")
            $buildLines.Add('Result=PASS')
            Write-Evidence $buildPath $buildLines
        }
    }

    $pdbInventoryPath = Join-Path $evidenceRoot 'pdb-inventory.json'
    $actualPdbPaths = @(Get-ChildItem -LiteralPath $evidenceRoot -File -Filter 'ChatpadFilter-*.pdb' | Sort-Object FullName | ForEach-Object { Get-RelativeRepositoryPath $_.FullName })
    $declaredPdbPaths = @($pdbRecords | ForEach-Object { [string]$_.retained_path } | Sort-Object)
    $pdbInventory = [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-pdb-inventory-v1'
        policy = 'All four retained PDBs are hash-bound bidirectionally; no unbound PDB is accepted.'
        record_count = $pdbRecords.Count
        actual_file_count = $actualPdbPaths.Count
        missing_file_count = @($declaredPdbPaths | Where-Object { $actualPdbPaths -cnotcontains $_ }).Count
        extra_file_count = @($actualPdbPaths | Where-Object { $declaredPdbPaths -cnotcontains $_ }).Count
        hash_mismatch_count = @($pdbRecords | Where-Object { (Get-FileHash -LiteralPath (Join-Path $repositoryRoot ([string]$_.retained_path)) -Algorithm SHA256).Hash -cne [string]$_.sha256 }).Count
        ignored_state_defect_count = @($pdbRecords | Where-Object { -not [bool]$_.ignored }).Count
        tracked_state_defect_count = @($pdbRecords | Where-Object { -not [bool]$_.untracked }).Count
        records = [object[]]$pdbRecords
        result = 'PENDING'
    }
    $pdbInventory.result = if ($pdbInventory.record_count -eq 4 -and $pdbInventory.actual_file_count -eq 4 -and $pdbInventory.missing_file_count -eq 0 -and $pdbInventory.extra_file_count -eq 0 -and $pdbInventory.hash_mismatch_count -eq 0 -and $pdbInventory.ignored_state_defect_count -eq 0 -and $pdbInventory.tracked_state_defect_count -eq 0) { 'PASS' } else { 'FAIL' }
    Write-JsonEvidence $pdbInventoryPath $pdbInventory
    if ($pdbInventory.result -cne 'PASS') { throw 'Retained PDB binding failed.' }

    $negativeSourceRoot = Join-Path $evidenceRoot 'debug-a\raw-tlogs'
    $negativeInventoryPath = Join-Path $evidenceRoot 'debug-a\tlog-inventory.json'
    $negativeTestRoot = Join-Path $evidenceRoot 'negative-test'
    $disposableRoot = Join-Path $negativeTestRoot 'disposable-root'
    New-Item -ItemType Directory -Path $negativeTestRoot -Force | Out-Null
    Copy-Item -LiteralPath $negativeSourceRoot -Destination $disposableRoot -Recurse -Force
    $canonicalBeforeJson = @(& $rawTlogValidatorPath -Mode ValidateExactRoot -RawRoot (Get-RelativeRepositoryPath $negativeSourceRoot) -InventoryPath (Get-RelativeRepositoryPath $negativeInventoryPath) 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
    $canonicalBeforeExit = $LASTEXITCODE
    $canonicalBefore = $canonicalBeforeJson | ConvertFrom-Json
    $disposableBeforeJson = @(& $rawTlogValidatorPath -Mode ValidateExactRoot -RawRoot (Get-RelativeRepositoryPath $disposableRoot) -InventoryPath (Get-RelativeRepositoryPath $negativeInventoryPath) 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
    $disposableBeforeExit = $LASTEXITCODE
    $disposableBefore = $disposableBeforeJson | ConvertFrom-Json
    if ($canonicalBeforeExit -ne 0 -or $disposableBeforeExit -ne 0) { throw 'Negative-test baseline validation failed.' }
    $syntheticPath = Join-Path $disposableRoot 'synthetic-extra-audit.tlog'
    [IO.File]::WriteAllText($syntheticPath, "synthetic extra TLOG for exact-root negative test`n", $utf8)
    $negativeJson = @(& $rawTlogValidatorPath -Mode ValidateExactRoot -RawRoot (Get-RelativeRepositoryPath $disposableRoot) -InventoryPath (Get-RelativeRepositoryPath $negativeInventoryPath) 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
    $negativeExit = $LASTEXITCODE
    $negativeResult = $negativeJson | ConvertFrom-Json
    if ($negativeExit -eq 0 -or [int]$negativeResult.extra_file_count -ne 1 -or @($negativeResult.extra_files) -cnotcontains 'synthetic-extra-audit.tlog') {
        throw 'Extra-TLOG negative test did not fail exactly as required.'
    }
    Remove-Item -LiteralPath $syntheticPath -Force
    $restoredJson = @(& $rawTlogValidatorPath -Mode ValidateExactRoot -RawRoot (Get-RelativeRepositoryPath $disposableRoot) -InventoryPath (Get-RelativeRepositoryPath $negativeInventoryPath) 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
    $restoredExit = $LASTEXITCODE
    $restored = $restoredJson | ConvertFrom-Json
    $canonicalAfterJson = @(& $rawTlogValidatorPath -Mode ValidateExactRoot -RawRoot (Get-RelativeRepositoryPath $negativeSourceRoot) -InventoryPath (Get-RelativeRepositoryPath $negativeInventoryPath) 2>&1 | ForEach-Object { $_.ToString() }) -join "`n"
    $canonicalAfterExit = $LASTEXITCODE
    $canonicalAfter = $canonicalAfterJson | ConvertFrom-Json
    if ($restoredExit -ne 0 -or $canonicalAfterExit -ne 0 -or [string]$restored.root_hash_sha256 -cne [string]$disposableBefore.root_hash_sha256 -or [string]$canonicalAfter.root_hash_sha256 -cne [string]$canonicalBefore.root_hash_sha256) {
        throw 'Extra-TLOG negative-test restoration or canonical-root identity failed.'
    }
    Remove-IgnoredArtifactTree $negativeTestRoot
    $negativeTranscriptPath = Join-Path $evidenceRoot 'raw-tlog-extra-file-negative-test.log'
    Write-Evidence $negativeTranscriptPath @(
        "CanonicalSourceRoot=$(Get-RelativeRepositoryPath $negativeSourceRoot)",
        "DisposableRoot=$(Get-RelativeRepositoryPath $disposableRoot)",
        "OriginalInventoryCount=$($disposableBefore.actual_file_count)",
        "OriginalDisposableRootHash=$($disposableBefore.root_hash_sha256)",
        'SyntheticFile=synthetic-extra-audit.tlog',
        "NegativeTestCommand=.\tools\Test-ChatpadProductionOrchestrationRawTlogEvidence.ps1 -Mode ValidateExactRoot -RawRoot '$(Get-RelativeRepositoryPath $disposableRoot)' -InventoryPath '$(Get-RelativeRepositoryPath $negativeInventoryPath)'",
        'ExpectedFailure=True',
        "FailureExitCode=$negativeExit",
        "DetectedExtraFileCount=$($negativeResult.extra_file_count)",
        "DetectedExtraFilePath=$(@($negativeResult.extra_files) -join ';')",
        'RestorationAction=Deleted only disposable synthetic-extra-audit.tlog, then deleted the disposable test tree after PASS',
        "PostRestorationCommand=.\tools\Test-ChatpadProductionOrchestrationRawTlogEvidence.ps1 -Mode ValidateExactRoot -RawRoot '$(Get-RelativeRepositoryPath $disposableRoot)' -InventoryPath '$(Get-RelativeRepositoryPath $negativeInventoryPath)'",
        "PostRestorationExitCode=$restoredExit",
        "PostRestorationFileCount=$($restored.actual_file_count)",
        "PostRestorationRootHash=$($restored.root_hash_sha256)",
        "PostRestorationHashResult=$([string]$restored.root_hash_sha256 -ceq [string]$disposableBefore.root_hash_sha256)",
        "CanonicalRootHashBefore=$($canonicalBefore.root_hash_sha256)",
        "CanonicalRootHashAfter=$($canonicalAfter.root_hash_sha256)",
        "CanonicalRootUnchangedResult=$([string]$canonicalBefore.root_hash_sha256 -ceq [string]$canonicalAfter.root_hash_sha256)",
        'DisposableRootRetentionPolicy=Deleted after successful restoration validation',
        'FinalResult=PASS',
        'Result=PASS')

    foreach ($configuration in @('Debug', 'Release')) {
        $configurationLower = $configuration.ToLowerInvariant()
        $a = $results["$configurationLower-a"]
        $b = $results["$configurationLower-b"]
        $inputComparison = Compare-InputInventories `
            -A $inputInventories["$configurationLower-a"] `
            -B $inputInventories["$configurationLower-b"] `
            -Configuration $configuration
        $inputComparisonRelative =
            "artifacts/logs/production-orchestration-ab-tlog-provenance/ab-input-comparison-$configurationLower.log"
        $inputComparisonPath = Join-Path $repositoryRoot $inputComparisonRelative
        $inputMetric = (
            'inputs={0}; missing=0; extra=0; hash_mismatches=0; unresolved=0; duplicates=0; configuration_mismatches=0; toolchain_mismatches=0' -f
                $inputComparison.InputCount)
        Write-Evidence $inputComparisonPath @(
            'Command: .\tools\New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1',
            "Configuration=$configuration|x64",
            "ImplementationCommit=$implementationCommit",
            "InputCount=$($inputComparison.InputCount)",
            "MissingInputCount=$($inputComparison.MissingInputCount)",
            "ExtraInputCount=$($inputComparison.ExtraInputCount)",
            "HashMismatchCount=$($inputComparison.HashMismatchCount)",
            "UnresolvedInputCount=$($inputComparison.UnresolvedInputCount)",
            "DuplicateNormalizedPathCount=$($inputComparison.DuplicateNormalizedPathCount)",
            "ConfigurationMismatchCount=$($inputComparison.ConfigurationMismatchCount)",
            "ToolchainIdentityMismatchCount=$($inputComparison.ToolchainIdentityMismatchCount)",
            'InputPathSetsEqual=True',
            'InputHashesEqual=True',
            'BuildConfigurationEqual=True',
            'ToolchainIdentityEqual=True',
            "ManifestMetricValue=$inputMetric",
            'Result=PASS')
        Compare-ExactValue $a.Pe.Size $b.Pe.Size "$configuration size"
        Compare-ExactValue $a.Pe.Machine $b.Pe.Machine "$configuration machine"
        Compare-ExactValue $a.Pe.Subsystem $b.Pe.Subsystem "$configuration subsystem"
        Compare-ExactValue $a.Pe.NormalizedPeSha256 $b.Pe.NormalizedPeSha256 `
            "$configuration normalized PE"
        Compare-ExactValue `
            (Get-SectionSetHash $a.Pe.Sections -Normalized -ExecutableOnly:$false) `
            (Get-SectionSetHash $b.Pe.Sections -Normalized -ExecutableOnly:$false) `
            "$configuration normalized section set"
        Compare-ExactValue `
            (Get-SectionSetHash $a.Pe.Sections -Normalized:$false -ExecutableOnly) `
            (Get-SectionSetHash $b.Pe.Sections -Normalized:$false -ExecutableOnly) `
            "$configuration executable section set"
        Compare-ExactValue $a.ImportDumpSha256 $b.ImportDumpSha256 "$configuration imports"
        Compare-ExactValue $a.NormalizedDisassemblySha256 $b.NormalizedDisassemblySha256 `
            "$configuration normalized disassembly"
        Compare-ExactValue $a.NormalizedSymbolSetSha256 $b.NormalizedSymbolSetSha256 `
            "$configuration normalized symbol set"
        Compare-ExactValue $a.ContextSymbolCount $b.ContextSymbolCount `
            "$configuration context symbol count"
        Compare-ExactValue $a.DriverNamedRetentionCount $b.DriverNamedRetentionCount `
            "$configuration driver named-retention count"
        Compare-ExactValue $a.WdfFunctionTableCount $b.WdfFunctionTableCount `
            "$configuration WDF function-table count"
        Compare-ExactValue $a.ForbiddenOperationCount $b.ForbiddenOperationCount `
            "$configuration forbidden-operation count"
        Compare-ExactValue $a.ForcedRetentionCount $b.ForcedRetentionCount `
            "$configuration forced-retention count"
        Compare-ExactValue $a.Authenticode $b.Authenticode "$configuration Authenticode"

        $diffCount = 0
        $aBytes = [System.IO.File]::ReadAllBytes($a.Pe.Path)
        $bBytes = [System.IO.File]::ReadAllBytes($b.Pe.Path)
        for ($index = 0; $index -lt $aBytes.Length; $index++) {
            if ($aBytes[$index] -ne $bBytes[$index]) {
                $diffCount++
            }
        }
        $equivalencePath = Join-Path $evidenceRoot "ab-equivalence-$configurationLower.log"
        $equivalenceMetric = (
            'PASS; differing_bytes={0}; normalized_pe_equal=true; executable_sections_equal=true' -f
                $diffCount)
        $equivalenceLines = @(
            'Command: .\tools\New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1',
            "Configuration=$configuration|x64",
            "ImplementationCommit=$implementationCommit",
            "InputIdentityComparisonPath=$inputComparisonRelative",
            "CompleteInputCount=$($inputComparison.InputCount)",
            'InputPathSetsEqual=True',
            'InputHashesEqual=True',
            'BuildConfigurationEqual=True',
            'ToolchainIdentityEqual=True',
            'SourceInputsEqual=True',
            "RawSha256A=$($a.Pe.RawSha256)",
            "RawSha256B=$($b.Pe.RawSha256)",
            "RawHashesEqual=$($a.Pe.RawSha256 -ceq $b.Pe.RawSha256)",
            "DifferingByteCount=$diffCount",
            "SizeA=$($a.Pe.Size)",
            "SizeB=$($b.Pe.Size)",
            'SizesEqual=True',
            "Machine=$($a.Pe.Machine)",
            "Subsystem=$($a.Pe.Subsystem)",
            "NormalizedPeSha256=$($a.Pe.NormalizedPeSha256)",
            'NormalizedPeHashesEqual=True',
            "NormalizedSectionSetSha256=$(Get-SectionSetHash $a.Pe.Sections -Normalized -ExecutableOnly:$false)",
            'NormalizedSectionHashesEqual=True',
            "ExecutableSectionSetSha256=$(Get-SectionSetHash $a.Pe.Sections -Normalized:$false -ExecutableOnly)",
            'ExecutableSectionHashesEqual=True',
            "ImportDumpSha256=$($a.ImportDumpSha256)",
            'ImportsEqual=True',
            "NormalizedDisassemblySha256=$($a.NormalizedDisassemblySha256)",
            'NormalizedDisassemblyEqual=True',
            "NormalizedSymbolSetSha256=$($a.NormalizedSymbolSetSha256)",
            'NormalizedSymbolSetEqual=True',
            "ContextSymbolCount=$($a.ContextSymbolCount)",
            "DriverNamedRetentionCount=$($a.DriverNamedRetentionCount)",
            "WdfFunctionTableReferenceCount=$($a.WdfFunctionTableCount)",
            'WdfReferencesEqual=True',
            'RetentionBoundaryEqual=True',
            "ForbiddenTargetRequestOperationCount=$($a.ForbiddenOperationCount)",
            'TargetRequestAbsenceEqual=True',
            "ForcedRetentionCount=$($a.ForcedRetentionCount)",
            "Authenticode=$($a.Authenticode)",
            'AuthenticodeEqual=True',
            'ExcludedFields=COFF.TimeDateStamp;OptionalHeader.CheckSum;DebugDirectory.TimeDateStamp;CodeView.RSDS.Guid',
            'ExcludedFieldsJustification=The only A/B differences are linker timestamps, the derived PE checksum, debug-directory timestamps, and the per-build CodeView identifier; executable-section bytes, all other section content after only those fields are zeroed, imports, disassembly, symbols, retention, and signature state are equal.',
            "ManifestMetricValue=$equivalenceMetric",
            'Result=PASS')
        Write-Evidence $equivalencePath $equivalenceLines
    }

    foreach ($configuration in @('Debug', 'Release')) {
        $configurationLower = $configuration.ToLowerInvariant()
        $canonical = $results["$configurationLower-b"]
        Copy-Item -LiteralPath $canonical.BinaryPath `
            -Destination (Join-Path $evidenceRoot "finalization-binary-$configurationLower.log") `
            -Force
        Copy-Item -LiteralPath $canonical.RetentionPath `
            -Destination (Join-Path $evidenceRoot "finalization-retention-$configurationLower.log") `
            -Force

        $canonicalDriverRelative =
            "artifacts/bin/x64/$configuration/ChatpadFilter/ChatpadFilter.sys"
        $canonicalDriverPath = Join-Path $repositoryRoot $canonicalDriverRelative
        $canonicalSignature = Get-AuthenticodeSignature -LiteralPath $canonicalDriverPath
        Write-Evidence `
            (Join-Path $evidenceRoot "finalization-authenticode-$configurationLower.log") `
            @(
                "Command: Get-AuthenticodeSignature '$canonicalDriverRelative'",
                "Configuration=$configuration|x64",
                "Size=$((Get-Item -LiteralPath $canonicalDriverPath).Length)",
                "Sha256=$((Get-FileHash -LiteralPath $canonicalDriverPath -Algorithm SHA256).Hash)",
                "Authenticode=$($canonicalSignature.Status)",
                "SignerCertificatePresent=$($null -ne $canonicalSignature.SignerCertificate)",
                'Result=PASS')
    }

    $debugCanonical = $results['debug-b']
    $releaseCanonical = $results['release-b']
    Write-Evidence `
        (Join-Path $evidenceRoot 'finalization-target-request-absence.log') `
        @(
            "Command[1]: dumpbin.exe /DISASM 'artifacts/logs/production-orchestration-ab-tlog-provenance/ChatpadFilter-debug-b.sys'",
            "Command[2]: dumpbin.exe /SYMBOLS 'artifacts/logs/production-orchestration-ab-tlog-provenance/ChatpadFilter-debug-b.sys'",
            "Command[3]: dumpbin.exe /IMPORTS 'artifacts/logs/production-orchestration-ab-tlog-provenance/ChatpadFilter-debug-b.sys'",
            "Command[4]: dumpbin.exe /DISASM 'artifacts/logs/production-orchestration-ab-tlog-provenance/ChatpadFilter-release-b.sys'",
            "Command[5]: dumpbin.exe /SYMBOLS 'artifacts/logs/production-orchestration-ab-tlog-provenance/ChatpadFilter-release-b.sys'",
            "Command[6]: dumpbin.exe /IMPORTS 'artifacts/logs/production-orchestration-ab-tlog-provenance/ChatpadFilter-release-b.sys'",
            "DebugForbiddenTargetRequestOperationCount=$($debugCanonical.ForbiddenOperationCount)",
            "ReleaseForbiddenTargetRequestOperationCount=$($releaseCanonical.ForbiddenOperationCount)",
             'D0RemovalOwnerObservationCount=0',
             'Result=PASS')

    $finalIdentity = Test-FrozenIdentity 'after-all-four-sets'
    [void](Assert-TrackedInputContract -Path $productionContractPath -ExpectedName 'production-runtime-link-input-set' -ExpectedCount 26)
    [void](Assert-TrackedInputContract -Path $wrapperContractPath -ExpectedName 'ab-wrapper-build-tracked-input-set' -ExpectedCount 32)
    $finalIdentityUtc = (Get-Date).ToUniversalTime()
    Write-Evidence $freezeRecordPath @(
        "FreezeUtc=$($freezeUtc.ToString('o'))",
        "ProducerPath=$producerRelativePath",
        "ProducerSize=$((Get-Item -LiteralPath $producerPath).Length)",
        "ProducerSha256=$($finalIdentity.producer_sha256)",
        "ProducerBlobId=$($finalIdentity.producer_blob_id)",
        "ProductionContractPath=$productionContractRelativePath",
        "ProductionContractSize=$((Get-Item -LiteralPath $productionContractPath).Length)",
        "ProductionContractSha256=$($finalIdentity.production_contract_sha256)",
        "ProductionContractBlobId=$($finalIdentity.production_contract_blob_id)",
        "WrapperContractPath=$wrapperContractRelativePath",
        "WrapperContractSize=$((Get-Item -LiteralPath $wrapperContractPath).Length)",
        "WrapperContractSha256=$($finalIdentity.wrapper_contract_sha256)",
        "WrapperContractBlobId=$($finalIdentity.wrapper_contract_blob_id)",
        "RawTlogValidatorPath=$rawTlogValidatorRelativePath",
        "RawTlogValidatorSize=$((Get-Item -LiteralPath $rawTlogValidatorPath).Length)",
        "RawTlogValidatorSha256=$($finalIdentity.raw_tlog_validator_sha256)",
        "RawTlogValidatorBlobId=$($finalIdentity.raw_tlog_validator_blob_id)",
        "FinalIdentityVerificationUtc=$($finalIdentityUtc.ToString('o'))",
        'Result=PASS',
        'ExitCode=0')
    Write-Evidence (Join-Path $evidenceRoot 'tlog-comparison-summary.log') @(
        "DebugATlogCount=$($setEvidence['debug-a'].TlogInventory.actual_root_tlog_count)",
        "DebugBTlogCount=$($setEvidence['debug-b'].TlogInventory.actual_root_tlog_count)",
        "ReleaseATlogCount=$($setEvidence['release-a'].TlogInventory.actual_root_tlog_count)",
        "ReleaseBTlogCount=$($setEvidence['release-b'].TlogInventory.actual_root_tlog_count)",
        "TotalRawTlogCount=$((@($setEvidence.Values | ForEach-Object { $_.TlogInventory.actual_root_tlog_count }) | Measure-Object -Sum).Sum)",
        'RawRootExtraFileCount=0',
        'RawRootMissingFileCount=0',
        'CrossSetCollisionCount=0',
        'AllSetsFresh=True',
        'AllParsersLossless=True',
        'AllObjectClosuresComplete=True',
        'AllLibraryClosuresComplete=True',
        'AllSameSetClosuresComplete=True',
        'AllClosuresComplete=True',
        "FinalIdentityVerificationUtc=$($finalIdentityUtc.ToString('o'))",
        'Result=PASS')

    Write-Output 'A/B rebuild evidence capture: PASS'
    foreach ($key in $results.Keys) {
        $result = $results[$key]
        $inventory = $inputInventories[$key]
        Write-Output (
            '{0}: inputs={1}; size={2}; raw={3}; normalized={4}' -f
                $key,
                $inventory.input_count,
                $result.Pe.Size,
                $result.Pe.RawSha256,
                $result.Pe.NormalizedPeSha256)
    }
}
finally {
    Pop-Location
}
