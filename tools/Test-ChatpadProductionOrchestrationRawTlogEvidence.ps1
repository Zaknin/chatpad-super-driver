[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('GenerateParserReport', 'ValidateParserReport', 'ValidateExactRoot', 'ValidateFreshness')]
    [string]$Mode,

    [Parameter(Mandatory)]
    [string]$RawRoot,

    [Parameter()]
    [string]$InventoryPath,

    [Parameter()]
    [string]$ReportPath,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [string]$SetId = 'unspecified',

    [Parameter()]
    [string]$Configuration = 'unspecified'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot, '..'))
$validatorRelativePath = 'tools/Test-ChatpadProductionOrchestrationRawTlogEvidence.ps1'
$utf8NoBom = New-Object Text.UTF8Encoding($false)

function Get-RepositoryRelativePath {
    param([Parameter(Mandatory)][string]$Path)

    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd('\', '/')
    if ($full.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($root.Length + 1).Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-TextSha256 {
    param([Parameter(Mandatory)][string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($utf8NoBom.GetBytes($Text)))).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )

    $parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = $Value | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText($Path, $json + "`n", $utf8NoBom)
}

function Get-TlogFamily {
    param([Parameter(Mandatory)][string]$Path)

    $name = [IO.Path]::GetFileName($Path).ToLowerInvariant()
    if ($name -like 'cl.command.*.tlog') { return 'CL.command' }
    if ($name -like 'cl.read.*.tlog') { return 'CL.read' }
    if ($name -like 'cl.write.*.tlog') { return 'CL.write' }
    if ($name -like 'cl.items.tlog') { return 'CL.items' }
    if ($name -like 'link.command.*.tlog') { return 'LINK.command' }
    if ($name -like 'link.read.*.tlog') { return 'LINK.read' }
    if ($name -like 'link.write.*.tlog') { return 'LINK.write' }
    if ($name -like 'link.secondary.*.tlog') { return 'LINK.metadata' }
    if ($name -like 'lib.command.*.tlog') { return 'LIB.command' }
    if ($name -like 'lib-link.read.*.tlog') { return 'LIB.read' }
    if ($name -like 'lib-link.write.*.tlog') { return 'LIB.write' }
    return 'other'
}

function Get-TlogProject {
    param([Parameter(Mandatory)][string]$Path)

    $relative = $Path.Replace('\', '/')
    foreach ($project in @('ChatpadFilter', 'ChatpadKmdfRequestOwnerContext', 'ChatpadProtocol')) {
        if ($relative -match ('/' + [regex]::Escape($project) + '/')) { return $project }
    }
    return 'unknown'
}

function Test-Utf16Pattern {
    param(
        [Parameter(Mandatory)][byte[]]$Bytes,
        [Parameter(Mandatory)][ValidateSet('LE', 'BE')][string]$Endian
    )

    if ($Bytes.Length -lt 4 -or ($Bytes.Length % 2) -ne 0) { return $false }
    $pairs = [Math]::Min([int]($Bytes.Length / 2), 2048)
    $zeroHigh = 0
    $printableLow = 0
    for ($index = 0; $index -lt $pairs; $index++) {
        $lowIndex = if ($Endian -ceq 'LE') { $index * 2 } else { ($index * 2) + 1 }
        $highIndex = if ($Endian -ceq 'LE') { ($index * 2) + 1 } else { $index * 2 }
        if ($Bytes[$highIndex] -eq 0) { $zeroHigh++ }
        $value = $Bytes[$lowIndex]
        if ($value -eq 0 -or $value -eq 9 -or $value -eq 10 -or $value -eq 13 -or ($value -ge 32 -and $value -le 126)) {
            $printableLow++
        }
    }
    return (($zeroHigh / $pairs) -ge 0.60 -and ($printableLow / $pairs) -ge 0.80)
}

function Read-TlogText {
    param([Parameter(Mandatory)][string]$Path)

    $bytes = [IO.File]::ReadAllBytes($Path)
    $offset = 0
    $encodingName = $null
    $decodeStatus = 'STRICT'
    $encoding = $null

    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xff -and $bytes[1] -eq 0xfe) {
        $encoding = New-Object Text.UnicodeEncoding($false, $true, $true)
        $encodingName = 'UTF-16LE-BOM'
        $offset = 2
    } elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xfe -and $bytes[1] -eq 0xff) {
        $encoding = New-Object Text.UnicodeEncoding($true, $true, $true)
        $encodingName = 'UTF-16BE-BOM'
        $offset = 2
    } elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) {
        $encoding = New-Object Text.UTF8Encoding($false, $true)
        $encodingName = 'UTF-8-BOM'
        $offset = 3
    } elseif (Test-Utf16Pattern -Bytes $bytes -Endian LE) {
        $encoding = New-Object Text.UnicodeEncoding($false, $false, $true)
        $encodingName = 'UTF-16LE-no-BOM'
    } elseif (Test-Utf16Pattern -Bytes $bytes -Endian BE) {
        $encoding = New-Object Text.UnicodeEncoding($true, $false, $true)
        $encodingName = 'UTF-16BE-no-BOM'
    } else {
        $encoding = New-Object Text.UTF8Encoding($false, $true)
        try {
            [void]$encoding.GetString($bytes)
            $encodingName = 'UTF-8-no-BOM'
        } catch {
            $encoding = [Text.Encoding]::Default
            $encodingName = 'ANSI-or-unknown'
            $decodeStatus = 'EXPLICIT-ANSI-FALLBACK'
        }
    }

    try {
        $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
    } catch {
        return [pscustomobject][ordered]@{
            encoding = $encodingName
            decode_status = 'UNDECODABLE'
            text = $null
            raw_file_base64 = [Convert]::ToBase64String($bytes)
        }
    }

    return [pscustomobject][ordered]@{
        encoding = $encodingName
        decode_status = $decodeStatus
        text = $text
        raw_file_base64 = $null
    }
}

function Split-TlogRecords {
    param([Parameter(Mandatory)][string]$Text)

    $records = New-Object 'Collections.Generic.List[object]'
    $buffer = New-Object Text.StringBuilder
    $index = 0
    while ($index -lt $Text.Length) {
        $character = $Text[$index]
        $delimiter = $null
        if ($character -eq [char]0) {
            $delimiter = 'NUL'
        } elseif ($character -eq "`r") {
            if (($index + 1) -lt $Text.Length -and $Text[$index + 1] -eq "`n") {
                $delimiter = 'CRLF'
                $index++
            } else {
                $delimiter = 'CR'
            }
        } elseif ($character -eq "`n") {
            $delimiter = 'LF'
        }

        if ($null -ne $delimiter) {
            $records.Add([pscustomobject]@{ text = $buffer.ToString(); delimiter = $delimiter })
            [void]$buffer.Clear()
        } else {
            [void]$buffer.Append($character)
        }
        $index++
    }
    $records.Add([pscustomobject]@{ text = $buffer.ToString(); delimiter = 'EOF' })
    return [object[]]$records
}

function Get-NormalizedCandidate {
    param([Parameter(Mandatory)][string]$Text)
    return (($Text.Trim() -replace '\\', '/').ToLowerInvariant())
}

function Get-PathCandidates {
    param([Parameter(Mandatory)][string]$Text)

    $paths = New-Object 'Collections.Generic.List[string]'
    foreach ($match in [regex]::Matches($Text, '(?i)(?:[A-Z]:\\[^|;"\r\n]+|\\\\[^|;"\r\n]+)')) {
        $candidate = $match.Value.Trim().TrimEnd()
        if ($paths -cnotcontains $candidate) { $paths.Add($candidate) }
    }
    return [string[]]$paths
}

function Classify-TlogRecord {
    param(
        [Parameter()][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Family,
        [Parameter(Mandatory)][string]$RawPath,
        [Parameter(Mandatory)][int]$Index,
        [Parameter(Mandatory)][string]$Encoding,
        [Parameter(Mandatory)][string]$Delimiter
    )

    $trimmed = $Text.Trim()
    $classification = $null
    $parseResult = 'PASS'
    $normalized = ''
    $environmentStatus = 'not-present'
    $relativeBase = $null
    $responsePath = $null
    $responseStatus = 'not-present'
    $metadataExplanation = $null
    $pathCandidates = [string[]]@()

    if ($trimmed.Length -eq 0) {
        $classification = 'empty'
        $parseResult = 'EMPTY'
    } else {
        $pathCandidates = Get-PathCandidates $trimmed
        $hasEnvironment = $trimmed -match '%[^%]+%|\$\([^)]+\)|\$\{[^}]+\}'
        $responseMatch = [regex]::Match($trimmed, '(?:^|\s)@(?:"([^"]+)"|([^\s]+))')
        if ($trimmed.StartsWith('^')) {
            $classification = 'tool marker'
            $metadataExplanation = 'MSBuild TLOG source/input-key marker; the payload is parsed into path candidates.'
        } elseif ($hasEnvironment) {
            $classification = 'environment-variable-containing path or command'
            $environmentStatus = 'present-unresolved-by-parser'
        } elseif ($responseMatch.Success) {
            $classification = 'response-file reference'
            $responsePath = if ($responseMatch.Groups[1].Success) { $responseMatch.Groups[1].Value } else { $responseMatch.Groups[2].Value }
            $responseStatus = if ([IO.Path]::IsPathRooted($responsePath)) { 'absolute-reference' } else { 'relative-reference' }
        } elseif ($trimmed -match '^(?:/[A-Za-z]|-[A-Za-z])' -or $trimmed -match '(?i)^(?:cl|link|lib)(?:\.exe)?\s') {
            $classification = 'command line'
        } elseif ($trimmed -match '^"(?:[A-Za-z]:[\\/]|\\\\)[^"]+"$') {
            $classification = 'quoted path'
        } elseif ($trimmed -match '^(?:[A-Za-z]:[\\/]|\\\\)') {
            $classification = 'absolute path'
        } elseif ($trimmed -match '^\.\.?[\\/]' -or $trimmed -match '^[^\s|;]+[\\/][^\s|;]+$') {
            $classification = 'relative path'
            $relativeBase = Get-RepositoryRelativePath (Split-Path -Parent (Join-Path $repositoryRoot $RawPath))
        } elseif ($Family -ceq 'LINK.metadata' -and $pathCandidates.Count -gt 0) {
            $classification = 'known non-path TLOG metadata'
            $metadataExplanation = 'LINK secondary dependency metadata with parsed absolute path payload.'
        } else {
            $classification = 'unexplained'
            $parseResult = 'FAIL'
        }

        $normalized = Get-NormalizedCandidate $trimmed
    }

    return [pscustomobject][ordered]@{
        raw_tlog_path = $RawPath
        raw_record_index = $Index
        original_record_text = $Text
        safe_encoded_representation = $null
        encoding = $Encoding
        delimiter_type = $Delimiter
        family = $Family
        classification = $classification
        normalized_comparison_form = $normalized
        path_candidates = $pathCandidates
        expanded_or_unresolved_environment_variable_status = $environmentStatus
        relative_path_resolution_base = $relativeBase
        response_file_path = $responsePath
        response_file_resolution_status = $responseStatus
        parse_result = $parseResult
        known_non_path_metadata_explanation = $metadataExplanation
    }
}

function New-ParserReport {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ReportSetId,
        [Parameter(Mandatory)][string]$ReportConfiguration
    )

    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw "Raw TLOG root is missing: $resolvedRoot"
    }
    $files = New-Object 'Collections.Generic.List[object]'
    $allRecords = New-Object 'Collections.Generic.List[object]'
    $encodingDefects = 0
    foreach ($file in @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Filter '*.tlog' | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($resolvedRoot.Length + 1).Replace('\', '/')
        $retainedPath = Get-RepositoryRelativePath $file.FullName
        $family = Get-TlogFamily $file.FullName
        $project = Get-TlogProject $file.FullName
        $decoded = Read-TlogText $file.FullName
        $fileRecords = New-Object 'Collections.Generic.List[object]'
        if ($decoded.decode_status -ceq 'UNDECODABLE') {
            $encodingDefects++
            $fileRecords.Add([pscustomobject][ordered]@{
                raw_tlog_path = $retainedPath; raw_record_index = 0; original_record_text = $null
                safe_encoded_representation = $decoded.raw_file_base64; encoding = $decoded.encoding
                delimiter_type = 'UNAVAILABLE'; family = $family; classification = 'unparseable'
                normalized_comparison_form = ''; path_candidates = [string[]]@()
                expanded_or_unresolved_environment_variable_status = 'not-present'
                relative_path_resolution_base = $null; response_file_path = $null
                response_file_resolution_status = 'not-present'; parse_result = 'FAIL'
                known_non_path_metadata_explanation = 'Raw bytes could not be decoded by the detected strict encoding.'
            })
        } else {
            $recordIndex = 0
            foreach ($split in @(Split-TlogRecords $decoded.text)) {
                $record = Classify-TlogRecord -Text ([string]$split.text) -Family $family -RawPath $retainedPath -Index $recordIndex -Encoding $decoded.encoding -Delimiter ([string]$split.delimiter)
                $fileRecords.Add($record)
                $allRecords.Add($record)
                $recordIndex++
            }
        }
        if ($decoded.decode_status -ceq 'UNDECODABLE') {
            foreach ($record in $fileRecords) { $allRecords.Add($record) }
        }

        $nonempty = @($fileRecords | Where-Object classification -CNE 'empty')
        $normalizedDuplicates = @($nonempty | Where-Object { -not [string]::IsNullOrEmpty([string]$_.normalized_comparison_form) } | Group-Object normalized_comparison_form | ForEach-Object { [Math]::Max(0, $_.Count - 1) } | Measure-Object -Sum).Sum
        if ($null -eq $normalizedDuplicates) { $normalizedDuplicates = 0 }
        $files.Add([pscustomobject][ordered]@{
            path = $retainedPath
            relative_path = $relative
            sha256 = Get-Sha256 $file.FullName
            size = [long]$file.Length
            family = $family
            project = $project
            encoding = $decoded.encoding
            decode_status = $decoded.decode_status
            RawRecordCount = $fileRecords.Count
            ParsedRecordCount = $nonempty.Count
            EmptyRecordCount = @($fileRecords | Where-Object classification -CEQ 'empty').Count
            NullSeparatedRecordCount = @($fileRecords | Where-Object delimiter_type -CEQ 'NUL').Count
            CrLfRecordCount = @($fileRecords | Where-Object delimiter_type -CEQ 'CRLF').Count
            LfRecordCount = @($fileRecords | Where-Object delimiter_type -CEQ 'LF').Count
            AbsolutePathRecordCount = @($fileRecords | Where-Object classification -CEQ 'absolute path').Count
            RelativePathRecordCount = @($fileRecords | Where-Object classification -CEQ 'relative path').Count
            QuotedRecordCount = @($fileRecords | Where-Object classification -CEQ 'quoted path').Count
            ResponseFileRecordCount = @($fileRecords | Where-Object classification -CEQ 'response-file reference').Count
            EnvironmentVariableRecordCount = @($fileRecords | Where-Object classification -CEQ 'environment-variable-containing path or command').Count
            KnownMetadataRecordCount = @($fileRecords | Where-Object { $_.classification -in @('tool marker', 'known non-path TLOG metadata') }).Count
            DuplicateNormalizedRecordCount = [int]$normalizedDuplicates
            UnparseableRecordCount = @($fileRecords | Where-Object classification -CEQ 'unparseable').Count
            DiscardedRecordCount = 0
            UnexplainedRecordCount = @($fileRecords | Where-Object classification -CEQ 'unexplained').Count
            records = [object[]]$fileRecords
        })
    }

    $nonemptyRecords = @($allRecords | Where-Object classification -CNE 'empty')
    $duplicateCount = @($nonemptyRecords | Where-Object { -not [string]::IsNullOrEmpty([string]$_.normalized_comparison_form) } | Group-Object normalized_comparison_form | ForEach-Object { [Math]::Max(0, $_.Count - 1) } | Measure-Object -Sum).Sum
    if ($null -eq $duplicateCount) { $duplicateCount = 0 }
    $report = [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-raw-tlog-parser-v2'
        parser_source_path = $validatorRelativePath
        parser_source_sha256 = Get-Sha256 (Join-Path $repositoryRoot $validatorRelativePath)
        parser_source_blob_id = (& git -C $repositoryRoot hash-object -- $validatorRelativePath).Trim()
        set_id = $ReportSetId
        configuration = $ReportConfiguration
        raw_tlog_root = Get-RepositoryRelativePath $resolvedRoot
        RawFileCount = $files.Count
        RawRecordCount = $allRecords.Count
        ParsedRecordCount = $nonemptyRecords.Count
        EmptyRecordCount = @($allRecords | Where-Object classification -CEQ 'empty').Count
        NullSeparatedRecordCount = @($allRecords | Where-Object delimiter_type -CEQ 'NUL').Count
        CrLfRecordCount = @($allRecords | Where-Object delimiter_type -CEQ 'CRLF').Count
        LfRecordCount = @($allRecords | Where-Object delimiter_type -CEQ 'LF').Count
        AbsolutePathRecordCount = @($allRecords | Where-Object classification -CEQ 'absolute path').Count
        RelativePathRecordCount = @($allRecords | Where-Object classification -CEQ 'relative path').Count
        QuotedRecordCount = @($allRecords | Where-Object classification -CEQ 'quoted path').Count
        ResponseFileRecordCount = @($allRecords | Where-Object classification -CEQ 'response-file reference').Count
        EnvironmentVariableRecordCount = @($allRecords | Where-Object classification -CEQ 'environment-variable-containing path or command').Count
        KnownMetadataRecordCount = @($allRecords | Where-Object { $_.classification -in @('tool marker', 'known non-path TLOG metadata') }).Count
        DuplicateNormalizedRecordCount = [int]$duplicateCount
        UnparseableRecordCount = @($allRecords | Where-Object classification -CEQ 'unparseable').Count
        DiscardedRecordCount = 0
        UnexplainedRecordCount = @($allRecords | Where-Object classification -CEQ 'unexplained').Count
        EncodingDefectCount = $encodingDefects
        files = [object[]]$files
        result = 'PENDING'
    }
    $report.result = if ($report.RawFileCount -gt 0 -and $report.EncodingDefectCount -eq 0 -and $report.UnparseableRecordCount -eq 0 -and $report.DiscardedRecordCount -eq 0 -and $report.UnexplainedRecordCount -eq 0 -and $report.RawRecordCount -eq ($report.ParsedRecordCount + $report.EmptyRecordCount)) { 'PASS' } else { 'FAIL' }
    return $report
}

function Get-InventoryRelativePaths {
    param([Parameter(Mandatory)][object]$Inventory)

    $marker = '/raw-tlogs/'
    return @($Inventory.tlogs | ForEach-Object {
        $path = ([string]$_.retained_path).Replace('\', '/')
        $position = $path.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase)
        if ($position -lt 0) { throw "Inventory retained path lacks raw-tlogs segment: $path" }
        $path.Substring($position + $marker.Length)
    } | Sort-Object)
}

function Test-ExactRoot {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$InventoryFile
    )

    $inventory = Get-Content -LiteralPath $InventoryFile -Raw | ConvertFrom-Json
    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $expected = @(Get-InventoryRelativePaths $inventory)
    $actualFiles = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Filter '*.tlog' | Sort-Object FullName)
    $actual = @($actualFiles | ForEach-Object { $_.FullName.Substring($resolvedRoot.Length + 1).Replace('\', '/') })
    $missing = @($expected | Where-Object { $actual -cnotcontains $_ })
    $extra = @($actual | Where-Object { $expected -cnotcontains $_ })
    $hashDefects = 0
    foreach ($record in @($inventory.tlogs)) {
        $retained = ([string]$record.retained_path).Replace('\', '/')
        $relative = @($expected | Where-Object { $retained.EndsWith($_, [StringComparison]::OrdinalIgnoreCase) }) | Select-Object -First 1
        if ($null -eq $relative) { $hashDefects++; continue }
        $candidate = Join-Path $resolvedRoot $relative
        if ((Test-Path -LiteralPath $candidate -PathType Leaf) -and (Get-Sha256 $candidate) -cne [string]$record.sha256) { $hashDefects++ }
    }
    $rootLines = @($actualFiles | ForEach-Object {
        $relative = $_.FullName.Substring($resolvedRoot.Length + 1).Replace('\', '/')
        '{0}|{1}|{2}' -f $relative, $_.Length, (Get-Sha256 $_.FullName)
    })
    $rootHash = Get-TextSha256 (($rootLines -join "`n") + "`n")
    return [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-raw-root-validation-v1'
        raw_root = Get-RepositoryRelativePath $resolvedRoot
        inventory_path = Get-RepositoryRelativePath $InventoryFile
        expected_file_count = $expected.Count
        actual_file_count = $actual.Count
        missing_file_count = $missing.Count
        missing_files = [string[]]$missing
        extra_file_count = $extra.Count
        extra_files = [string[]]$extra
        hash_mismatch_count = $hashDefects
        root_hash_sha256 = $rootHash
        result = if ($missing.Count -eq 0 -and $extra.Count -eq 0 -and $hashDefects -eq 0) { 'PASS' } else { 'FAIL' }
    }
}

function Test-Freshness {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$InventoryFile
    )

    $inventory = Get-Content -LiteralPath $InventoryFile -Raw | ConvertFrom-Json
    $exact = Test-ExactRoot -Root $Root -InventoryFile $InventoryFile
    $tolerance = [double]$inventory.timestamp_tolerance_seconds
    $stale = 0
    $ambiguous = 0
    $outOfWindow = 0
    $postCopyMismatch = [int]$exact.hash_mismatch_count
    foreach ($record in @($inventory.tlogs)) {
        try {
            $clean = [datetime]::Parse([string]$record.clean_completed_utc).ToUniversalTime()
            $start = [datetime]::Parse([string]$record.build_start_utc).ToUniversalTime()
            $end = [datetime]::Parse([string]$record.build_end_utc).ToUniversalTime()
            $capture = [datetime]::Parse([string]$record.capture_utc).ToUniversalTime()
            $verified = [datetime]::Parse([string]$record.retained_hash_verification_utc).ToUniversalTime()
            $write = [datetime]::Parse([string]$record.source_last_write_utc).ToUniversalTime()
            if ($clean -gt $start -or $start -gt $end -or $end -gt $capture -or $capture -gt $verified) { $ambiguous++ }
            if ($write -lt $start.AddSeconds(-$tolerance)) { $stale++ }
            if ($write -lt $start.AddSeconds(-$tolerance) -or $write -gt $end.AddSeconds($tolerance)) { $outOfWindow++ }
        } catch {
            $ambiguous++
        }
    }
    $retainedPaths = @($inventory.tlogs | ForEach-Object { ([string]$_.retained_path).Replace('\', '/').ToLowerInvariant() })
    $shared = @($retainedPaths | Group-Object | Where-Object Count -gt 1).Count
    $crossSetCollisionCount = @($retainedPaths | Group-Object | Where-Object Count -gt 1).Count
    return [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-freshness-recomputation-v1'
        set = [string]$inventory.set
        configuration = [string]$inventory.configuration
        timestamp_tolerance_seconds = $tolerance
        pre_build_count = [int]$inventory.pre_build_tlog_count
        post_build_count = [int]$exact.actual_file_count
        stale_count = $stale
        ambiguous_timestamp_count = $ambiguous
        out_of_window_count = $outOfWindow
        shared_file_count = $shared
        cross_set_path_collision_count = $crossSetCollisionCount
        post_copy_hash_mismatch_count = $postCopyMismatch
        exact_root_result = $exact.result
        result = if ([int]$inventory.pre_build_tlog_count -eq 0 -and $exact.actual_file_count -eq 22 -and $stale -eq 0 -and $ambiguous -eq 0 -and $outOfWindow -eq 0 -and $shared -eq 0 -and $postCopyMismatch -eq 0 -and $exact.result -ceq 'PASS') { 'PASS' } else { 'FAIL' }
    }
}

try {
    $resolvedRawRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RawRoot))
    $result = $null
    switch ($Mode) {
        'GenerateParserReport' {
            $result = New-ParserReport -Root $resolvedRawRoot -ReportSetId $SetId -ReportConfiguration $Configuration
            if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
                Write-JsonFile -Path ([IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputPath))) -Value $result
            }
        }
        'ValidateParserReport' {
            if ([string]::IsNullOrWhiteSpace($ReportPath)) { throw 'ReportPath is required.' }
            $storedPath = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $ReportPath))
            $stored = Get-Content -LiteralPath $storedPath -Raw | ConvertFrom-Json
            $recomputed = New-ParserReport -Root $resolvedRawRoot -ReportSetId ([string]$stored.set_id) -ReportConfiguration ([string]$stored.configuration)
            $counterNames = @('RawFileCount','RawRecordCount','ParsedRecordCount','EmptyRecordCount','NullSeparatedRecordCount','CrLfRecordCount','LfRecordCount','AbsolutePathRecordCount','RelativePathRecordCount','QuotedRecordCount','ResponseFileRecordCount','EnvironmentVariableRecordCount','KnownMetadataRecordCount','DuplicateNormalizedRecordCount','UnparseableRecordCount','DiscardedRecordCount','UnexplainedRecordCount','EncodingDefectCount')
            $mismatches = New-Object 'Collections.Generic.List[string]'
            foreach ($counter in $counterNames) {
                if ([int]$stored.$counter -ne [int]$recomputed.$counter) { $mismatches.Add($counter) }
            }
            if (@($stored.files).Count -ne @($recomputed.files).Count) { $mismatches.Add('files.count') }
            else {
                for ($fileIndex = 0; $fileIndex -lt @($stored.files).Count; $fileIndex++) {
                    $storedFile = @($stored.files)[$fileIndex]
                    $actualFile = @($recomputed.files)[$fileIndex]
                    if ([string]$storedFile.path -cne [string]$actualFile.path -or [string]$storedFile.sha256 -cne [string]$actualFile.sha256 -or @($storedFile.records).Count -ne @($actualFile.records).Count) {
                        $mismatches.Add("files[$fileIndex]")
                    }
                }
            }
            $result = [pscustomobject][ordered]@{
                schema_version = 'chatpad-production-orchestration-independent-parser-validation-v1'
                report_path = Get-RepositoryRelativePath $storedPath
                validator_source_path = $validatorRelativePath
                validator_source_sha256 = Get-Sha256 (Join-Path $repositoryRoot $validatorRelativePath)
                recomputed_counters = $recomputed
                counter_mismatch_count = $mismatches.Count
                counter_mismatches = [string[]]$mismatches
                result = if ($mismatches.Count -eq 0 -and $recomputed.result -ceq 'PASS') { 'PASS' } else { 'FAIL' }
            }
        }
        'ValidateExactRoot' {
            if ([string]::IsNullOrWhiteSpace($InventoryPath)) { throw 'InventoryPath is required.' }
            $result = Test-ExactRoot -Root $resolvedRawRoot -InventoryFile ([IO.Path]::GetFullPath((Join-Path $repositoryRoot $InventoryPath)))
        }
        'ValidateFreshness' {
            if ([string]::IsNullOrWhiteSpace($InventoryPath)) { throw 'InventoryPath is required.' }
            $result = Test-Freshness -Root $resolvedRawRoot -InventoryFile ([IO.Path]::GetFullPath((Join-Path $repositoryRoot $InventoryPath)))
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($OutputPath) -and $Mode -cne 'GenerateParserReport') {
        Write-JsonFile -Path ([IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputPath))) -Value $result
    }
    $result | ConvertTo-Json -Depth 100
    if ([string]$result.result -cne 'PASS') { exit 3 }
    exit 0
} catch {
    [pscustomobject][ordered]@{
        schema_version = 'chatpad-production-orchestration-raw-tlog-validator-error-v1'
        mode = $Mode
        error = $_.Exception.Message
        result = 'FAIL'
    } | ConvertTo-Json -Depth 10
    exit 2
}
