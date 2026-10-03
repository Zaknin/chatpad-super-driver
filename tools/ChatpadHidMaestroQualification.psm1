Set-StrictMode -Version Latest

function Test-ChatpadHidMaestroPackageIdentity {
 [CmdletBinding()]
 param([Parameter(Mandatory)][string]$Directory,
       [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ExpectedFiles)
 $ErrorActionPreference='Stop'
 if($ExpectedFiles.Count -eq 0){throw 'An explicit nonempty pinned file contract is required.'}
 $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 foreach($file in $ExpectedFiles){
  if(-not $file.Name -or $file.Name -match '[\\/:]' -or $file.Name -in '.','..' -or
     -not $names.Add($file.Name) -or $file.SHA256 -notmatch '^[A-Fa-f0-9]{64}$'){
   throw 'Malformed or duplicate pinned file identity.'
  }
 }
 $files=@(foreach($file in $ExpectedFiles){
  $path=Join-Path $Directory $file.Name
  $hash=$null;$status='MISSING'
  if(Test-Path -LiteralPath $path -PathType Leaf){
   $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
   $status=if($hash -ieq $file.SHA256){'MATCH'}else{'MISMATCH'}
  }
  [pscustomobject]@{Name=$file.Name;ExpectedSHA256=$file.SHA256;ActualSHA256=$hash;Status=$status}
 })
 $unexpected=@(if(Test-Path -LiteralPath $Directory -PathType Container){
  Get-ChildItem -LiteralPath $Directory -Force | Where-Object {
   $_.PSIsContainer -or -not $names.Contains($_.Name) -or
   ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
  } | Select-Object -ExpandProperty Name
 })
 [pscustomobject]@{Matched=(@($files | Where-Object Status -ne 'MATCH').Count -eq 0 -and $unexpected.Count -eq 0);
  Files=$files;UnexpectedFiles=$unexpected;InstallationQualified=$false;Reason='File identity is separate from catalog membership, signature trust and live load acceptance.'}
}

Export-ModuleMember -Function Test-ChatpadHidMaestroPackageIdentity
