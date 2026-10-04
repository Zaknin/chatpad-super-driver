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
 $declaredMembers=@($packageRecords|Where-Object Role -like 'VirtualFile:*'|ForEach-Object {([string]$_.Role).Substring('VirtualFile:'.Length)}|Sort-Object -Unique)
 $actualMembers=@(Get-ChildItem -LiteralPath $root -File | Where-Object {$_.Name -notin @('ChatpadSetup.ps1','HIDMaestro.Core.xml') -and $_.Extension -ne '.pdb'}|ForEach-Object Name|Sort-Object -Unique)
 if(Compare-Object -ReferenceObject $declaredMembers -DifferenceObject $actualMembers -CaseSensitive){throw 'C4 package runtime member set differs from readiness; missing or unmanifested package files are not accepted.'}
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

function Test-ChatpadBrokerSetupIdentity {
 [CmdletBinding()]
 param([Parameter(Mandatory)][object]$Identity,[Parameter(Mandatory)][string]$AuthorizedUserSid)
 if($AuthorizedUserSid -notmatch '^S-1-5-21-(?:[0-9]+-){2}[0-9]+-[0-9]+$'){return $false}
 return [bool]$Identity.Elevated -and
  ([string]$Identity.UserSid -ceq $AuthorizedUserSid) -and
  ([int]$Identity.TokenSessionId -ge 0) -and
  ([int]$Identity.TokenSessionId -eq [int]$Identity.ActiveConsoleSessionId) -and
  ([int]$Identity.WtsProtocol -eq 0) -and
  ([string]$Identity.SessionState -ceq 'Active')
}

function Assert-ChatpadBrokerInstallRoot {
 [CmdletBinding()]
 param([Parameter(Mandatory)][string]$InstallRoot)
 $programRoot=[IO.Path]::GetFullPath($env:ProgramFiles)
 $isReparse=$false
 $candidate=[IO.Path]::GetFullPath($InstallRoot)
 if(Test-Path -LiteralPath $candidate){$isReparse=[bool]((Get-Item -LiteralPath $candidate -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)}
 if(-not(Test-ChatpadBrokerInstallRootIdentity $candidate $programRoot $isReparse)){throw 'Broker install root must be the non-reparse Program Files\ChatpadBridge directory.'}
 $root=$candidate.TrimEnd('\')
 return $root
}

function Test-ChatpadBrokerInstallRootIdentity {
 [CmdletBinding()]
 param([Parameter(Mandatory)][string]$InstallRoot,[Parameter(Mandatory)][string]$ProgramFilesRoot,[Parameter(Mandatory)][bool]$IsReparsePoint)
 if(-not[IO.Path]::IsPathRooted($InstallRoot) -or $IsReparsePoint){return $false}
 $expected=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetFullPath($ProgramFilesRoot)) 'ChatpadBridge')).TrimEnd('\')
 return [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\').Equals($expected,[StringComparison]::OrdinalIgnoreCase)
}

function Resolve-ChatpadBrokerPackageRoot {
 [CmdletBinding()]
 param([string]$RequestedPackageRoot,[Parameter(Mandatory)][string]$ReadinessPackageRoot)
 $readinessRoot=[IO.Path]::GetFullPath($ReadinessPackageRoot)
 if([string]::IsNullOrWhiteSpace($RequestedPackageRoot)){return $readinessRoot}
 $requested=[IO.Path]::GetFullPath($RequestedPackageRoot)
 if(-not $requested.Equals($readinessRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Explicit package root does not match the package identity recorded in C4 readiness.'}
 return $readinessRoot
}

function New-ChatpadBrokerServicePlan {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)][ValidateSet('InstallBroker','RepairBroker','UninstallBroker')][string]$Mode,
  [Parameter(Mandatory)][string]$InstallRoot,
  [Parameter(Mandatory)][object[]]$RuntimeRecords,
  [Parameter(Mandatory)][string]$AuthorizedUserSid
 )
 $root=Assert-ChatpadBrokerInstallRoot $InstallRoot
 if($AuthorizedUserSid -notmatch '^S-1-5-21-(?:[0-9]+-){2}[0-9]+-[0-9]+$'){throw 'Authorized interactive user SID is invalid.'}
 $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 $members=@()
 foreach($record in $RuntimeRecords){
  $role=[string]$record.Role
  if($role -notlike 'VirtualFile:*'){throw 'Broker runtime records must use VirtualFile:<name> roles.'}
  $name=$role.Substring('VirtualFile:'.Length)
  if([string]::IsNullOrWhiteSpace($name) -or [IO.Path]::GetFileName($name) -cne $name -or $name.Contains(':') -or $name -in @('.','..')){throw "Invalid service runtime member name: $name"}
  if(-not $names.Add($name)){throw "Duplicate service runtime member name: $name"}
  if([string]$record.SHA256 -notmatch '^[A-Fa-f0-9]{64}$'){throw "Invalid service runtime SHA-256: $name"}
  $members+=,[pscustomobject]@{Name=$name;SourcePath=[IO.Path]::GetFullPath([string]$record.Path);TargetPath=[IO.Path]::GetFullPath((Join-Path $root $name));SHA256=([string]$record.SHA256).ToUpperInvariant()}
 }
 foreach($required in @('ChatpadVirtualXbox.exe','HIDMaestro.Core.dll')){if(-not $names.Contains($required)){throw "Required service runtime member is missing: $required"}}
 $config=[ordered]@{version=1;authorizedUserSid=$AuthorizedUserSid}|ConvertTo-Json -Compress
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes($config)
 $algorithm=[Security.Cryptography.SHA256]::Create()
 try{$hash=([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-','')}finally{$algorithm.Dispose()}
 $exe=[IO.Path]::GetFullPath((Join-Path $root 'ChatpadVirtualXbox.exe'))
 [pscustomobject]@{
  Mode=$Mode;ServiceName='ChatpadHidMaestroBroker';Account='LocalSystem';StartType='Automatic'
  AuthorizedUserSid=$AuthorizedUserSid
  InstallRoot=$root;ExecutablePath=$exe;BinaryPathName=('"'+$exe+'" service')
  AuthorizationPath=[IO.Path]::GetFullPath((Join-Path $root 'BrokerAuthorization.json'))
  AuthorizationJson=$config;AuthorizationHash=$hash
  RuntimeRecords=@($members|Sort-Object Name)
  RecoveryActions=@([pscustomobject]@{Action='restart';DelayMilliseconds=5000},[pscustomobject]@{Action='restart';DelayMilliseconds=15000},[pscustomobject]@{Action='restart';DelayMilliseconds=30000})
  MutationScope='service-only'
 }
}

function New-ChatpadBrokerScArguments {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory)][ValidateSet('Create','Config','Failure','FailureFlag')][string]$Operation,
  [Parameter(Mandatory)][object]$Plan
 )
 switch($Operation){
  'Create' { return @('create',[string]$Plan.ServiceName,'binPath=',[string]$Plan.BinaryPathName,'start=','auto','obj=','LocalSystem','DisplayName=','Chatpad HIDMaestro Broker') }
  'Config' { return @('config',[string]$Plan.ServiceName,'binPath=',[string]$Plan.BinaryPathName,'start=','auto','obj=','LocalSystem') }
  'Failure' { return @('failure',[string]$Plan.ServiceName,'reset=','86400','actions=','restart/5000/restart/15000/restart/30000') }
  'FailureFlag' { return @('failureflag',[string]$Plan.ServiceName,'1') }
 }
}

function Assert-ChatpadBrokerInstalledRuntimeMember {
 [CmdletBinding()]
 param([Parameter(Mandatory)][object]$Record,[Parameter(Mandatory)][string]$InstallRoot)
 $root=Assert-ChatpadBrokerInstallRoot $InstallRoot
 $target=[IO.Path]::GetFullPath((Join-Path $root ([string]$Record.Name)))
 if(-not $target.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Installed broker member escaped Program Files\ChatpadBridge.'}
 if(-not(Test-Path -LiteralPath $target -PathType Leaf) -or ((Get-Item -LiteralPath $target -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ine [string]$Record.SHA256){throw "Installed broker runtime member hash mismatch: $($Record.Name)"}
 return $true
}

Export-ModuleMember -Function New-ChatpadC4PackageRecord,New-ChatpadC4PackagePayloadRecords,Get-ChatpadC4ReadinessPackageRoot,Assert-ChatpadC4PackageIdentity,Assert-ChatpadC4InstalledRuntimeMember,Test-ChatpadBrokerSetupIdentity,Test-ChatpadBrokerInstallRootIdentity,Resolve-ChatpadBrokerPackageRoot,Assert-ChatpadBrokerInstallRoot,New-ChatpadBrokerServicePlan,New-ChatpadBrokerScArguments,Assert-ChatpadBrokerInstalledRuntimeMember
