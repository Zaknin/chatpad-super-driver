[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GitLines {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $output = @(& git @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
    return @($output | Where-Object { $_ -ne '' })
}

$failures = [System.Collections.Generic.List[string]]::new()
$repoRoot = @(Invoke-GitLines -Arguments @('rev-parse', '--show-toplevel'))[0]
Push-Location -LiteralPath $repoRoot
try {
    $trackedFiles = Invoke-GitLines -Arguments @('ls-files')
    $generatedPattern = '(?i)\.(sys|exe|dll|cat|cab|msi|pdb|lib|obj|ilk|idb)$'
    $trackedGenerated = @($trackedFiles | Where-Object { $_ -match $generatedPattern })
    if ($trackedGenerated.Count -gt 0) {
        $failures.Add("Generated binaries are tracked: $($trackedGenerated -join ', ')")
    }

    $legacyDiff = Invoke-GitLines -Arguments @('diff', '--name-only', 'origin/win11-port', '--', 'legacy')
    $legacyUntracked = Invoke-GitLines -Arguments @('ls-files', '--others', '--exclude-standard', '--', 'legacy')
    $legacyChanges = @($legacyDiff + $legacyUntracked | Sort-Object -Unique)
    if ($legacyChanges.Count -gt 0) {
        $failures.Add("Files under legacy/ differ from origin/win11-port: $($legacyChanges -join ', ')")
    }

    $indexedLegacyBinaries = @(
        Invoke-GitLines -Arguments @('ls-files', '--', 'legacy') |
            Where-Object { $_ -match '(?i)\.(sys|exe|dll|cat|cab|msi|pdb|lib)$' -or $_ -match '(?i)(^|/)WdfCoInstaller[^/]*$' }
    )
    if ($indexedLegacyBinaries.Count -gt 0) {
        $failures.Add("Forbidden legacy binaries are present in the index: $($indexedLegacyBinaries -join ', ')")
    }

    $modernProhibitedPattern = '(?i)(\.(inf|inx|cat|cer|crt|der|pem|pfx|p12|pvk|spc|key|snk|deployproj|vdproj|wapproj|appxmanifest)$|(^|/)[^/]*deploy[^/]*$)'
    $modernProhibited = @(
        $trackedFiles |
            Where-Object { $_ -like 'src/driver/*' -and $_ -match $modernProhibitedPattern }
    )
    if ($modernProhibited.Count -gt 0) {
        $failures.Add("Packaging, certificate, or deployment files exist in the modern source tree: $($modernProhibited -join ', ')")
    }

    $allowedGeneratedRoots = @(
        '.git', '.vs', 'artifacts', 'x64', 'Debug', 'Release', 'build', 'out', 'bin', 'obj',
        'legacy-source', 'audit-output', 'Downloads', 'stage2-source-review'
    )
    $generatedOutsideOutput = [System.Collections.Generic.List[string]]::new()
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $generatedPattern } |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
            $firstSegment = ($relativePath -split '[\\/]', 2)[0]
            if ($allowedGeneratedRoots -notcontains $firstSegment) {
                $generatedOutsideOutput.Add($relativePath.Replace('\', '/'))
            }
        }
    if ($generatedOutsideOutput.Count -gt 0) {
        $failures.Add("Generated build outputs exist outside approved ignored directories: $($generatedOutsideOutput -join ', ')")
    }

    & git merge-base --is-ancestor 6502452 HEAD 2>$null
    $ancestorExitCode = $LASTEXITCODE
    if ($ancestorExitCode -eq 0) {
        $failures.Add('Prohibited commit 6502452 is an ancestor of HEAD.')
    }
    elseif ($ancestorExitCode -ne 1) {
        $failures.Add("Unable to evaluate prohibited ancestry; git merge-base exited $ancestorExitCode.")
    }
}
finally {
    Pop-Location
}

if ($failures.Count -gt 0) {
    Write-Output 'REPOSITORY SAFETY: FAIL'
    foreach ($failure in $failures) {
        Write-Output "FAIL: $failure"
    }
    exit 1
}

Write-Output 'REPOSITORY SAFETY: PASS'
Write-Output 'PASS: no generated binaries are tracked'
Write-Output 'PASS: legacy/ matches origin/win11-port'
Write-Output 'PASS: no forbidden legacy binaries are indexed'
Write-Output 'PASS: modern source contains no packaging, certificate, or deployment files'
Write-Output 'PASS: no generated build outputs exist outside approved ignored directories'
Write-Output 'PASS: prohibited commit 6502452 is not an ancestor of HEAD'
exit 0
