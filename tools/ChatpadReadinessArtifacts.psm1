Set-StrictMode -Version Latest
function New-ChatpadDeterministicArchive {
 [CmdletBinding()]
 param([Parameter(Mandatory)][string]$SourceDirectory,[Parameter(Mandatory)][string]$Destination)
 $ErrorActionPreference='Stop'
 $root=(Resolve-Path -LiteralPath $SourceDirectory).Path
 $files=@(Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName)
 if(@($files | Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0}).Count){throw 'Archive refuses reparse-point files.'}
 $stream=[IO.File]::Open($Destination,[IO.FileMode]::CreateNew)
 try{
  $zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
  try{
   foreach($file in $files){
    $name=$file.FullName.Substring($root.Length).TrimStart('\','/').Replace('\','/')
    $entry=$zip.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
    $entry.LastWriteTime=[DateTimeOffset]::new(2000,1,1,0,0,0,[TimeSpan]::Zero)
    $output=$entry.Open();$input=[IO.File]::OpenRead($file.FullName)
    try{$input.CopyTo($output)}finally{$input.Dispose();$output.Dispose()}
   }
  }finally{$zip.Dispose()}
 }finally{$stream.Dispose()}
 return (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
}
function Protect-ChatpadEvidenceText {
 [CmdletBinding()]
 param([AllowEmptyString()][string]$Text,[AllowEmptyCollection()][string[]]$PrivateValues)
 foreach($value in $PrivateValues){
  if(-not [string]::IsNullOrEmpty($value)){
   $Text=$Text.Replace($value.Replace('\','\\'),'<redacted>').Replace($value,'<redacted>')
  }
 }
 return $Text
}
Export-ModuleMember -Function New-ChatpadDeterministicArchive,Protect-ChatpadEvidenceText
