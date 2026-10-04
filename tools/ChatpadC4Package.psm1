Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function New-ChatpadC4PackageRecord {
 [CmdletBinding()]
 param([Parameter(Mandatory)][string]$Role,[Parameter(Mandatory)][string]$Path)
 if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Missing C4 package payload: $Path"}
 [pscustomobject]@{Role=$Role;Path=(Resolve-Path -LiteralPath $Path).Path;SHA256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
}

function New-ChatpadC4PackagePayloadRecords {
 [CmdletBinding()]
 param([Parameter(Mandatory)][string]$PackageRoot)
 $root=(Resolve-Path -LiteralPath $PackageRoot).Path
 $setup=Join-Path $root 'ChatpadSetup.ps1'
 $runtime=@(Get-ChildItem -LiteralPath $root -File | Where-Object {$_.Extension -ne '.pdb' -and $_.Name -notin @('HIDMaestro.Core.xml','ChatpadSetup.ps1')})
 if(@($runtime | Where-Object Name -eq 'HIDMaestro.Core.dll').Count -ne 1){throw 'Pinned HIDMaestro runtime assembly is missing from the runner package.'}
 $records=@(New-ChatpadC4PackageRecord 'SetupTool' $setup)
 foreach($file in $runtime){$records+=New-ChatpadC4PackageRecord ('VirtualFile:'+ $file.Name) $file.FullName}
 return ,$records
}

function Get-ChatpadC4ReadinessPackageRoot {
 [CmdletBinding()]
 param([Parameter(Mandatory)][object]$Readiness)
 if([string]::IsNullOrWhiteSpace([string]$Readiness.PackageRoot)){throw 'C4 readiness is missing its package identity; regenerate the package and readiness together.'}
 [IO.Path]::GetFullPath([string]$Readiness.PackageRoot)
}

function Assert-ChatpadC4PackageIdentity {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)][object]$Readiness,
  [Parameter(Mandatory)][string]$PackageRoot,
  [Parameter(Mandatory)][string]$SetupScriptPath
 )
 $root=[IO.Path]::GetFullPath($PackageRoot).TrimEnd('\')
 $declaredRoot=Get-ChatpadC4ReadinessPackageRoot $Readiness
 if(-not $root.Equals($declaredRoot.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'Selected package root does not match the package identity recorded in C4 readiness.'}
 $files=@($Readiness.Files)
 foreach($role in @('Poc','VirtualBackend','SetupTool')){
  $matches=@($files|Where-Object Role -ceq $role)
  if($matches.Count -ne 1){throw "C4 readiness must contain exactly one $role package identity record."}
  $name=switch($role){'Poc'{'ChatpadBridge.exe'}'VirtualBackend'{'ChatpadVirtualXbox.exe'}'SetupTool'{'ChatpadSetup.ps1'}}
  $expectedPath=[IO.Path]::GetFullPath((Join-Path $root $name))
  if(-not([IO.Path]::GetFullPath([string]$matches[0].Path)).Equals($expectedPath,[StringComparison]::OrdinalIgnoreCase)){throw "C4 $role path does not belong to the selected package."}
 }
 if(@($files|Where-Object Role -ceq 'VirtualFile:ChatpadSetup.ps1').Count){throw 'ChatpadSetup.ps1 is setup tooling and must not be an installed runtime member.'}
 $packageRecords=@($files|Where-Object {$_.Role -in @('Poc','VirtualBackend','SetupTool') -or $_.Role -like 'VirtualFile:*'})
 $memberNames=@{}
 foreach($record in $packageRecords){
  $role=[string]$record.Role
  $name=if($role -like 'VirtualFile:*'){$role.Substring('VirtualFile:'.Length)}else{[IO.Path]::GetFileName([string]$record.Path)}
  if([string]::IsNullOrWhiteSpace($name) -or [IO.Path]::GetFileName($name) -cne $name){throw "Invalid C4 package member name in readiness role: $role"}
  if($role -like 'VirtualFile:*' -and $name -in @('ChatpadSetup.ps1','HIDMaestro.Core.xml')){throw "Non-runtime package file is incorrectly recorded as an installed runtime member: $name"}
  if($role -like 'VirtualFile:*'){
   if($memberNames.ContainsKey($name)){throw "Duplicate C4 package runtime member identity: $name"}
   $memberNames[$name]=$true
  }
  $expectedPath=[IO.Path]::GetFullPath((Join-Path $root $name))
  if(-not([IO.Path]::GetFullPath([string]$record.Path)).Equals($expectedPath,[StringComparison]::OrdinalIgnoreCase)){throw "C4 package member path does not belong to the selected package: $name"}
  if(-not(Test-Path -LiteralPath $expectedPath -PathType Leaf) -or (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash -ine [string]$record.SHA256){
   if($role -ceq 'SetupTool'){throw "SetupTool hash mismatch: packaged ChatpadSetup.ps1 is stale or changed."}
   throw "C4 package member hash mismatch: $name. Regenerate package and readiness from the same HEAD."
  }
 }
 $setupRecord=@($files|Where-Object Role -ceq 'SetupTool')[0]
 if(-not(Test-Path -LiteralPath $SetupScriptPath -PathType Leaf) -or (Get-FileHash -LiteralPath $SetupScriptPath -Algorithm SHA256).Hash -ine [string]$setupRecord.SHA256){throw 'SetupTool hash mismatch: the executing ChatpadSetup.ps1 differs from the package readiness identity.'}
 return $true
}

function Assert-ChatpadC4InstalledRuntimeMember {
 [CmdletBinding()]
 param([Parameter(Mandatory)][object]$Record,[Parameter(Mandatory)][string]$InstallRoot)
 if([string]$Record.Role -notlike 'VirtualFile:*'){throw 'Only VirtualFile records identify installed runtime members.'}
 $name=([string]$Record.Role).Substring('VirtualFile:'.Length)
 if([IO.Path]::GetFileName($name) -cne $name -or $name -in @('ChatpadSetup.ps1','HIDMaestro.Core.xml')){throw "Invalid installed runtime member identity: $name"}
 $path=Join-Path $InstallRoot $name
 if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ine [string]$Record.SHA256){throw "Installed helper runtime member hash mismatch: $name"}
 return $true
}

Export-ModuleMember -Function New-ChatpadC4PackageRecord,New-ChatpadC4PackagePayloadRecords,Get-ChatpadC4ReadinessPackageRoot,Assert-ChatpadC4PackageIdentity,Assert-ChatpadC4InstalledRuntimeMember
