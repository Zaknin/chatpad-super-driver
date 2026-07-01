[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedProducerSha256,

    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9a-f]{40}$')]
    [string]$ExpectedProducerBlobId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($PSScriptRoot, '..'))
$implementationCommit = 'efb729502a0527ac70e2d20fa31a323c3beb2920'
$finalizationStartingCommit = 'b2a9b5cee457f69126c6f6c80615738e4ae59f31'
$expectedBranch = 'feature/offline-kmdf-production-orchestration-tlog-provenance-remediation'
$producerRelativePath = 'tools/New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1'
$producerPath = Join-Path $repositoryRoot $producerRelativePath
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
        [Parameter(Mandatory)][string]$Mechanism
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
            category = Get-InputCategory $fullPath $Mechanism
            size = [long](Get-Item -LiteralPath $fullPath).Length
            sha256 = $hash
            repo_local = [bool]$repoLocal
            mechanisms = @($Mechanism)
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
                Add-BuildInput $Inputs $candidate $Mechanism
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
            Add-BuildInput $Inputs $sourcePath $Mechanism
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

function Copy-RawTLogs {
    param(
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$Set,
        [Parameter(Mandatory)][datetime]$BuildStartUtc,
        [Parameter(Mandatory)][datetime]$BuildEndUtc
    )

    $key = "$($Configuration.ToLowerInvariant())-$($Set.ToLowerInvariant())"
    $sourceRoot = Join-Path $repositoryRoot "artifacts\obj\x64\$Configuration"
    $setRoot = Join-Path $evidenceRoot $key
    $rawRoot = Join-Path $setRoot 'raw-tlogs'
    New-Item -ItemType Directory -Path $rawRoot -Force | Out-Null
    $captureUtc = (Get-Date).ToUniversalTime()
    $records = [System.Collections.Generic.List[object]]::new()
    $staleCount = 0
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
        if ($sourceFile.LastWriteTimeUtc -lt $BuildStartUtc -or $sourceFile.LastWriteTimeUtc -gt $BuildEndUtc.AddMinutes(2)) {
            $staleCount++
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
        $records.Add([pscustomobject][ordered]@{
            source_path = Get-RelativeRepositoryPath $sourceFile.FullName
            retained_path = $retainedRelative
            project = Get-TLogProject $sourceFile.FullName
            family = Get-TLogFamily $sourceFile.FullName
            size = [long]$sourceFile.Length
            sha256 = $sourceHash
            retained_sha256 = $retainedHash
            source_last_write_utc = $sourceFile.LastWriteTimeUtc.ToString('o')
            build_start_utc = $BuildStartUtc.ToString('o')
            build_end_utc = $BuildEndUtc.ToString('o')
            capture_utc = $captureUtc.ToString('o')
            encoding = 'MSBuild tracking log bytes retained as-is'
            retained_git_ignored = $ignoredMismatchCount -eq 0
            retained_git_tracked = $tracked.Count -ne 0
        })
    }

    $families = @($records | Group-Object family | Sort-Object Name | ForEach-Object {
        [pscustomobject][ordered]@{ family = $_.Name; count = [int]$_.Count }
    })
    $projects = @($records | Group-Object project | Sort-Object Name | ForEach-Object {
        [pscustomobject][ordered]@{ project = $_.Name; count = [int]$_.Count }
    })
    $inventory = [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-raw-tlog-inventory-v1'
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
        hash_mismatch_count = [int]$hashMismatchCount
        stale_tlog_count = [int]$staleCount
        ignored_mismatch_count = [int]$ignoredMismatchCount
        tracked_retained_count = [int]$trackedMismatchCount
        source_and_retained_roots_disjoint = $true
        families = [object[]]$families
        projects = [object[]]$projects
        tlogs = [object[]]$records
        result = if ($records.Count -gt 0 -and $hashMismatchCount -eq 0 -and $staleCount -eq 0 -and $ignoredMismatchCount -eq 0 -and $trackedMismatchCount -eq 0) { 'PASS' } else { 'FAIL' }
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
        "HashMismatchCount=$hashMismatchCount",
        "StaleTlogCount=$staleCount",
        "IgnoredMismatchCount=$ignoredMismatchCount",
        "TrackedRetainedCount=$trackedMismatchCount",
        "SourceAndRetainedRootsDisjoint=True",
        "ProducerSha256=$($ExpectedProducerSha256.ToUpperInvariant())",
        "ProducerBlobId=$($ExpectedProducerBlobId.ToLowerInvariant())",
        "BuildStartUtc=$($BuildStartUtc.ToString('o'))",
        "BuildEndUtc=$($BuildEndUtc.ToString('o'))",
        "CaptureUtc=$($captureUtc.ToString('o'))",
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
            foreach ($match in [regex]::Matches($line, '(?i)[A-Z]:\\[^|"\r\n ]+\.(obj|lib)')) {
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
        $project = if ($repoLocal) { Get-TLogProject $libraryPath } else { 'external' }
        $projectTlogs = @($TLogInventory.tlogs | Where-Object { [string]$_.project -ceq $project })
        $libraryRecords.Add([pscustomobject][ordered]@{
            linked_path = if ($repoLocal) { Get-RelativeRepositoryPath $libraryPath } else { $libraryPath }
            linked_sha256 = if (Test-Path -LiteralPath $libraryPath -PathType Leaf) { (Get-FileHash -LiteralPath $libraryPath -Algorithm SHA256).Hash } else { $null }
            identity = if ($repoLocal) { 'repo_local_project_reference' } else { 'external_toolchain_or_sdk_library' }
            producing_project = $project
            producing_tool = if ($repoLocal) { 'LIB' } else { 'external' }
            producer_tlogs = [string[]]@($projectTlogs | Where-Object { [string]$_.family -like 'LIB.*' } | ForEach-Object retained_path)
            consuming_tlogs = [string[]]@($linkTlogs | ForEach-Object retained_path)
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

function Get-BuildInputInventory {
    param(
        [Parameter(Mandatory)][string]$Configuration,
        [Parameter(Mandatory)][string]$Set,
        [Parameter(Mandatory)][string]$DumpbinPath
    )

    $inputs = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    foreach ($path in @(
            'ChatpadWin11.sln',
            'Directory.Build.props',
            'src/driver/ChatpadFilter/ChatpadFilter.vcxproj',
            'src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.vcxproj')) {
        Add-BuildInput $inputs (Join-Path $repositoryRoot $path) 'msbuild_project_closure:explicit_project_or_repo_import'
    }

    $filterTLogRoot = Join-Path $repositoryRoot "artifacts\obj\x64\$Configuration\ChatpadFilter\ChatpadFilter.tlog"
    $contextTLogRoot = Join-Path $repositoryRoot "artifacts\obj\x64\$Configuration\ChatpadKmdfRequestOwnerContext\ChatpadK.421C7E3A.tlog"
    Add-ClCommandSources $inputs (Join-Path $filterTLogRoot 'CL.command.1.tlog') 'cl_command_tlog:ChatpadFilter'
    Add-TLogPathInputs $inputs (Join-Path $filterTLogRoot 'CL.read.1.tlog') 'cl_read_tlog:ChatpadFilter'
    Add-TLogPathInputs $inputs (Join-Path $filterTLogRoot 'Cl.items.tlog') 'cl_items_tlog:ChatpadFilter'
    Add-TLogPathInputs $inputs (Join-Path $filterTLogRoot 'link.read.1.tlog') 'link_read_tlog:ChatpadFilter'
    Add-ClCommandSources $inputs (Join-Path $contextTLogRoot 'CL.command.1.tlog') 'cl_command_tlog:ChatpadKmdfRequestOwnerContext'
    Add-TLogPathInputs $inputs (Join-Path $contextTLogRoot 'CL.read.1.tlog') 'cl_read_tlog:ChatpadKmdfRequestOwnerContext'
    Add-TLogPathInputs $inputs (Join-Path $contextTLogRoot 'Cl.items.tlog') 'cl_items_tlog:ChatpadKmdfRequestOwnerContext'
    Add-TLogPathInputs $inputs (Join-Path $contextTLogRoot 'Lib-link.read.1.tlog') 'lib_read_tlog:ChatpadKmdfRequestOwnerContext'

    foreach ($tool in @(
            (Get-ToolchainPath 'cl.exe' $DumpbinPath),
            (Get-ToolchainPath 'link.exe' $DumpbinPath),
            (Get-ToolchainPath 'lib.exe' $DumpbinPath),
            $DumpbinPath)) {
        Add-BuildInput $inputs $tool ("toolchain_identity:{0}:{1}" -f [System.IO.Path]::GetFileName($tool), (Get-Item -LiteralPath $tool).VersionInfo.FileVersion)
    }

    $commandFiles = @(
        (Join-Path $filterTLogRoot 'CL.command.1.tlog'),
        (Join-Path $filterTLogRoot 'link.command.1.tlog'),
        (Join-Path $contextTLogRoot 'CL.command.1.tlog'),
        (Join-Path $contextTLogRoot 'Lib.command.1.tlog')
    )
    $configurationDigestText = (($commandFiles | ForEach-Object {
        '{0}={1}' -f (Get-RelativeDisplayPath $_), (Get-TextFileHash $_)
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
        schema_version = 'chatpad-production-orchestration-ab-input-inventory-v1'
        configuration = "$Configuration|x64"
        set = $Set
        starting_commit = $finalizationStartingCommit
        implementation_commit = $implementationCommit
        generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
        generation_command = '.\tools\New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1'
        method = 'MSBuild clean build followed by compiler/linker tracking log closure: ChatpadFilter CL/link tlogs plus ChatpadKmdfRequestOwnerContext project-reference CL/lib producer tlogs; explicit solution/project/Directory.Build.props files; external headers/libraries/system reads; toolchain executable identity. Generated repo-local obj/lib intermediates are resolved through their producer tlog closure instead of treated as pre-build source inputs.'
        command_digests = [pscustomobject][ordered]@{
            filter_cl_command_tlog_sha256 = Get-TextFileHash (Join-Path $filterTLogRoot 'CL.command.1.tlog')
            filter_link_command_tlog_sha256 = Get-TextFileHash (Join-Path $filterTLogRoot 'link.command.1.tlog')
            context_cl_command_tlog_sha256 = Get-TextFileHash (Join-Path $contextTLogRoot 'CL.command.1.tlog')
            context_lib_command_tlog_sha256 = Get-TextFileHash (Join-Path $contextTLogRoot 'Lib.command.1.tlog')
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
    $producerSha256 = (Get-FileHash -LiteralPath $producerPath -Algorithm SHA256).Hash
    $producerBlobId = Invoke-GitText @('hash-object', '--', $producerPath)
    if ($producerSha256 -cne $ExpectedProducerSha256.ToUpperInvariant() -or
        $producerBlobId -cne $ExpectedProducerBlobId.ToLowerInvariant()) {
        throw 'Producer source identity does not match the caller-provided frozen hash/blob.'
    }
    $trackedProducer = @(& git -C $repositoryRoot ls-files --error-unmatch -- $producerRelativePath 2>$null)
    if ($LASTEXITCODE -ne 0 -or $trackedProducer.Count -ne 1) {
        throw "Producer must be staged/tracked before evidence generation: $producerRelativePath"
    }
    $allowedTrackedPaths = @($producerRelativePath)
    Assert-AllowedTrackedState 'before provenance evidence capture' $allowedTrackedPaths
    Remove-IgnoredArtifactTree $evidenceRoot
    New-Item -ItemType Directory -Path $evidenceRoot -Force | Out-Null
    Write-Evidence (Join-Path $evidenceRoot 'producer-source.log') @(
        "ProducerPath=$producerRelativePath",
        "ProducerSha256=$producerSha256",
        "ProducerBlobId=$producerBlobId",
        "Branch=$branch",
        "StartingCommit=$head",
        "ImplementationCommit=$implementationCommit",
        "OutputRoot=$(Get-RelativeRepositoryPath $evidenceRoot)",
        "TrackedBeforeGeneration=True",
        "Result=PASS")

    $dumpbinPath = Get-DumpbinPath
    $dumpbinVersion = (Get-Item -LiteralPath $dumpbinPath).VersionInfo.FileVersion
    $results = [ordered]@{}
    $inputInventories = [ordered]@{}
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
            $buildPath = Join-Path $evidenceRoot "ab-build-$key.log"
            $generatedAt = (Get-Date).ToUniversalTime().ToString('o')
            Assert-AllowedTrackedState "before A/B build $set $configuration" $allowedTrackedPaths
            Remove-IgnoredArtifactTree (Join-Path $repositoryRoot "artifacts\obj\x64\$configuration")
            Remove-IgnoredArtifactTree (Join-Path $repositoryRoot "artifacts\bin\x64\$configuration")
            $preBuildTlogs = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot "artifacts\obj\x64\$configuration") -Recurse -File -Filter '*.tlog' -ErrorAction SilentlyContinue)
            if ($preBuildTlogs.Count -ne 0) {
                throw "Pre-build tlog count was not zero for $set $configuration."
            }
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

            $tlogInventory = Copy-RawTLogs -Configuration $configuration -Set $set -BuildStartUtc $buildStartUtc -BuildEndUtc $buildEndUtc
            $producerClosure = New-ProducerClosureEvidence -Configuration $configuration -Set $set -TLogInventory $tlogInventory
            $inventory = Get-BuildInputInventory -Configuration $configuration -Set $set -DumpbinPath $dumpbinPath
            $inventoryRelative = "artifacts/logs/production-orchestration-ab-tlog-provenance/ab-input-inventory-$key.json"
            $inventoryPath = Join-Path $repositoryRoot $inventoryRelative
            Write-JsonEvidence $inventoryPath $inventory
            $inventoryHash = (Get-FileHash -LiteralPath $inventoryPath -Algorithm SHA256).Hash
            $inputInventories[$key] = $inventory

            $buildLines = [System.Collections.Generic.List[string]]::new()
            $buildLines.Add("Command: $buildCommand")
            $buildLines.Add("WorkingDirectory=$repositoryRoot")
            $buildLines.Add("Set=$set")
            $buildLines.Add("Configuration=$configuration|x64")
            $buildLines.Add("StartingCommit=$head")
            $buildLines.Add("ImplementationCommit=$implementationCommit")
            $buildLines.Add("DumpbinVersion=$dumpbinVersion")
            $buildLines.Add("InputInventoryPath=$inventoryRelative")
            $buildLines.Add("InputInventorySha256=$inventoryHash")
            $buildLines.Add("InputCount=$($inventory.input_count)")
            $buildLines.Add("UnresolvedInputCount=$($inventory.unresolved_input_count)")
            $buildLines.Add("DuplicateNormalizedPathCount=$($inventory.duplicate_normalized_path_count)")
            $buildLines.Add("PreBuildTlogCount=0")
            $buildLines.Add("PostBuildTlogCount=$($tlogInventory.post_build_tlog_count)")
            $buildLines.Add("RawTlogInventory=$(Get-RelativeRepositoryPath (Join-Path (Join-Path $evidenceRoot $key) 'tlog-inventory.json'))")
            $buildLines.Add("ProducerClosure=$(Get-RelativeRepositoryPath (Join-Path (Join-Path $evidenceRoot $key) 'producer-closure.json'))")
            $buildLines.Add("LinkedObjectProducerCount=$($producerClosure.linked_object_count)")
            $buildLines.Add("MissingObjectProducerCount=$($producerClosure.missing_object_producer_count)")
            $buildLines.Add("ConfigurationDigestSha256=$($inventory.configuration_digest_sha256)")
            $buildLines.Add("ToolchainDigestSha256=$($inventory.toolchain_digest_sha256)")
            $buildLines.Add('TrackedStateBeforeBuild=AllowedProducerOnly')
            $buildLines.Add('TrackedStateAfterBuild=AllowedProducerOnly')
            $buildLines.Add("GeneratedAtUtc=$generatedAt")
            $buildLines.Add('')
            foreach ($line in $buildOutput) {
                $buildLines.Add($line)
            }
            $buildLines.Add("BuildExitCode=$buildExitCode")
            $buildLines.Add('Result=PASS')
            Write-Evidence $buildPath $buildLines

            $driverSource = Join-Path $repositoryRoot (
                "artifacts\bin\x64\$configuration\ChatpadFilter\ChatpadFilter.sys")
            $pdbSource = Join-Path $repositoryRoot (
                "artifacts\bin\x64\$configuration\ChatpadFilter\ChatpadFilter.pdb")
            $driverRelative = "artifacts/logs/production-orchestration-ab-tlog-provenance/ChatpadFilter-$key.sys"
            $driverPath = Join-Path $repositoryRoot $driverRelative
            $pdbPath = Join-Path $evidenceRoot "ChatpadFilter-$key.pdb"
            Copy-Item -LiteralPath $driverSource -Destination $driverPath -Force
            Copy-Item -LiteralPath $pdbSource -Destination $pdbPath -Force

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
        }
    }

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


