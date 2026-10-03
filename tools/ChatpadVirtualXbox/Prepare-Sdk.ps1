[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReferenceRepository, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$output = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $root 'artifacts/task-8lc2r1/virtual/sdk-dependency' }
$pin = Get-Content (Join-Path $PSScriptRoot 'upstream.json') -Raw | ConvertFrom-Json
$head = & git -C $ReferenceRepository rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head -ne $pin.revision) { throw 'Reference checkout must be at the exact pinned revision.' }
$tag = & git -C $ReferenceRepository rev-list -n 1 $pin.tagInspected
if ($LASTEXITCODE -ne 0 -or $tag -ne $pin.revision) { throw 'Release tag must resolve to the exact pinned revision.' }
$dirty = & git -C $ReferenceRepository status --porcelain --untracked-files=no
if ($LASTEXITCODE -ne 0 -or $dirty) { throw 'Reference source checkout is dirty.' }
$license = Join-Path $ReferenceRepository 'LICENSE'
if ((Get-FileHash -LiteralPath $license -Algorithm SHA256).Hash -ne $pin.licenseSha256) { throw 'Pinned checkout license changed.' }
New-Item -ItemType Directory -Path $output -Force | Out-Null
$archive = Join-Path $output 'release.zip'
if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) { Invoke-WebRequest $pin.c2r1ReleaseUrl -OutFile $archive }
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $pin.c2r1ReleaseAssetSha256) { throw 'Official release archive hash mismatch.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    foreach ($name in @('HIDMaestro.Core.dll', 'LICENSE', 'THIRD-PARTY-NOTICES.txt')) {
        $entry = $zip.GetEntry($name)
        if (-not $entry) { throw "Official release member missing: $name" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $output $name), $true)
    }
} finally { $zip.Dispose() }
$sdk = Join-Path $output 'HIDMaestro.Core.dll'
if ((Get-FileHash -LiteralPath $sdk -Algorithm SHA256).Hash -ne $pin.c2r1ReleaseSdkSha256) { throw 'Official SDK DLL hash mismatch.' }
$normalize = { param($path) ([IO.File]::ReadAllText($path)).Replace("`r`n", "`n").TrimEnd() }
if ((& $normalize $license) -ne (& $normalize (Join-Path $output 'LICENSE'))) { throw 'Release MIT license differs from pinned source license.' }
$files = foreach ($name in @('HIDMaestro.Core.dll', 'LICENSE', 'THIRD-PARTY-NOTICES.txt')) {
    $file = Join-Path $output $name
    [ordered]@{ name=$name; path=$file; sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash }
}
$manifest = [ordered]@{ revision=$pin.revision; releaseTag=$pin.tagInspected; releaseUrl=$pin.c2r1ReleaseUrl;
    releaseSha256=$pin.c2r1ReleaseAssetSha256; license='MIT'; sourceLicenseSha256=$pin.licenseSha256;
    releaseLicenseEquivalentAfterLineEndingNormalization=$true; sourceVendored=$false; upstreamBuildInvoked=$false;
    embeddedDriverInstallerPayloadPresent=$true; payloadExecuted=$false; files=@($files) }
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $output 'dependency-manifest.json') -Encoding utf8
Write-Output "Pinned official external SDK verified: $sdk. No context, driver or installer was executed."
