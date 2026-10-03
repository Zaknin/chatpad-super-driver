function Publish-ChatpadArtifact {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$SourcePath,
          [Parameter(Mandatory)][string]$DestinationDirectory,
          [Parameter(Mandatory)][string]$FileName)
    $ErrorActionPreference='Stop'
    if($FileName -ne [IO.Path]::GetFileName($FileName) -or $FileName -match '[\\/:]' -or $FileName -in '.','..' -or -not $FileName){throw 'Artifact name must be a single filename.'}
    if(-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)){throw 'Source artifact missing.'}
    New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
    $sourceHash=(Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    $final=Join-Path $DestinationDirectory $FileName
    $part=$final+'.part';$marker=$final+'.sha256';$markerPart=$marker+'.part'
    foreach($candidate in @($final,$part,$marker,$markerPart)){if(Test-Path -LiteralPath $candidate){throw "Refusing to overwrite publication: $candidate"}}
    Copy-Item -LiteralPath $SourcePath -Destination $part
    # Independently reopen the destination; Copy-Item completion alone is not proof.
    $partHash=(Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash
    if($partHash -cne $sourceHash){throw 'Partial read-back SHA mismatch; no completion marker committed.'}
    [IO.File]::Move($part,$final)
    $finalHash=(Get-FileHash -LiteralPath $final -Algorithm SHA256).Hash
    if($finalHash -cne $sourceHash){throw 'Final read-back SHA mismatch; no completion marker committed.'}
    $content=$sourceHash+'  '+$FileName+"`n"
    [IO.File]::WriteAllText($markerPart,$content,[Text.UTF8Encoding]::new($false))
    if([IO.File]::ReadAllText($markerPart) -cne $content){throw 'Sidecar read-back mismatch.'}
    # Sidecar is the completion marker, and is committed last.
    [IO.File]::Move($markerPart,$marker)
    if([IO.File]::ReadAllText($marker) -cne $content){throw 'Completion marker final read-back mismatch.'}
    [pscustomobject]@{Name=$FileName;Path=$final;SHA256=$sourceHash;PartReadbackSHA256=$partHash;FinalReadbackSHA256=$finalHash;Verified=$true;SidecarCommittedLast=$true}
}
Export-ModuleMember -Function Publish-ChatpadArtifact
