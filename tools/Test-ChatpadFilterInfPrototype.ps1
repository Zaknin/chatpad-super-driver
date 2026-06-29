[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

trap {
    Write-Output ("FAIL: {0}" -f $_.Exception.Message)
    exit 1
}

function Get-InfActiveLines {
    param([Parameter(Mandatory)][string]$Path)

    $activeLines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($sourceLine in [System.IO.File]::ReadAllLines($Path)) {
        $builder = New-Object System.Text.StringBuilder
        $insideQuotes = $false
        foreach ($character in $sourceLine.ToCharArray()) {
            if ($character -eq '"') {
                $insideQuotes = -not $insideQuotes
                [void]$builder.Append($character)
                continue
            }
            if ($character -eq ';' -and -not $insideQuotes) {
                break
            }
            [void]$builder.Append($character)
        }

        $activeLine = $builder.ToString().Trim()
        if ($activeLine.Length -gt 0) {
            $activeLines.Add($activeLine)
        }
    }
    return @($activeLines)
}

function Get-InfSections {
    param([Parameter(Mandatory)][string[]]$ActiveLines)

    $sections = @{}
    $currentSection = $null
    foreach ($line in $ActiveLines) {
        if ($line -match '^\[([^\]]+)\]$') {
            $currentSection = $Matches[1]
            if (-not $sections.ContainsKey($currentSection)) {
                $sections[$currentSection] = New-Object 'System.Collections.Generic.List[string]'
            }
            continue
        }
        if ($null -eq $currentSection) {
            throw "Active INF content exists outside a section: $line"
        }
        $sections[$currentSection].Add($line)
    }
    return $sections
}

function Get-DirectiveValues {
    param(
        [Parameter(Mandatory)][object[]]$Lines,
        [Parameter(Mandatory)][string]$Name)

    $escapedName = [regex]::Escape($Name)
    return @(
        $Lines |
            Where-Object { $_ -match ("(?i)^\s*{0}\s*=" -f $escapedName) } |
            ForEach-Object { ($_ -split '=', 2)[1].Trim() }
    )
}

function Assert-Condition {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message)

    if (-not $Condition) {
        throw $Message
    }
}

function Get-FileSha256Hash {
    param([Parameter(Mandatory)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-NumericVersionDirectories {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return @()
    }
    return @(
        Get-ChildItem -LiteralPath $Path -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+(\.\d+){1,3}$' } |
            Sort-Object { [version]$_.Name } -Descending
    )
}

$repoRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..'))
$gitRootOutput = @(& git -C $repoRoot rev-parse --show-toplevel)
if ($LASTEXITCODE -ne 0 -or $gitRootOutput.Count -ne 1) {
    throw "Unable to locate repository root from $PSScriptRoot."
}
$gitRoot = [System.IO.Path]::GetFullPath([string]$gitRootOutput[0])
Assert-Condition `
    -Condition $repoRoot.TrimEnd('\', '/').Equals($gitRoot.TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase) `
    -Message "Script-derived repository root does not match Git root: $repoRoot vs $gitRoot"

$prototypeRoot = Join-Path $repoRoot 'prototypes\inf\ChatpadFilterExtension'
$infPath = Join-Path $prototypeRoot 'ChatpadFilterExtension.inf'
$readmePath = Join-Path $prototypeRoot 'README.md'
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$outputRoot = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::Combine($repoRoot, 'artifacts', 'inf-validation', $timestamp))
$htmlOutput = Join-Path $outputRoot 'annotated'
$helpLogPath = Join-Path $outputRoot 'infverif-help.txt'
$toolLogPath = Join-Path $outputRoot 'infverif-output.txt'
$infoLogPath = Join-Path $outputRoot 'infverif-info.txt'
$annotatedLogPath = Join-Path $outputRoot 'infverif-annotated.txt'
$semanticLogPath = Join-Path $outputRoot 'semantic-guards.txt'
New-Item -ItemType Directory -Path $htmlOutput -Force | Out-Null

$evidence = New-Object 'System.Collections.Generic.List[string]'
try {
    Assert-Condition -Condition (Test-Path -LiteralPath $infPath -PathType Leaf) -Message "Prototype INF is missing: $infPath"
    Assert-Condition -Condition (Test-Path -LiteralPath $readmePath -PathType Leaf) -Message "Prototype README is missing: $readmePath"

    $readmeText = [System.IO.File]::ReadAllText($readmePath)
    $requiredWarning = 'OFFLINE PROTOTYPE ' + [char]0x2014 + ' DO NOT INSTALL'
    Assert-Condition -Condition $readmeText.Contains($requiredWarning) -Message 'Prototype README is missing the exact installation warning.'

    $activeLines = @(Get-InfActiveLines -Path $infPath)
    $sections = Get-InfSections -ActiveLines $activeLines
    $activeText = $activeLines -join [Environment]::NewLine

    $requiredSections = @(
        'Version',
        'DestinationDirs',
        'SourceDisksNames',
        'SourceDisksFiles',
        'Manufacturer',
        'Models.NTamd64.10.0...22000',
        'ChatpadFilter_Install.NT',
        'ChatpadFilter_CopyFiles',
        'ChatpadFilter_Install.NT.Services',
        'ChatpadFilter_Service_Install',
        'ChatpadFilter_Install.NT.Wdf',
        'ChatpadFilter_Wdf',
        'ChatpadFilter_Install.NT.Filters',
        'ChatpadFilter_LowerFilter',
        'Strings')
    foreach ($sectionName in $requiredSections) {
        Assert-Condition -Condition $sections.ContainsKey($sectionName) -Message "Required INF section is missing: [$sectionName]"
    }
    $unexpectedSections = @($sections.Keys | Where-Object { $_ -notin $requiredSections })
    Assert-Condition -Condition ($unexpectedSections.Count -eq 0) -Message "Unexpected INF sections are prohibited: $($unexpectedSections -join ', ')"

    foreach ($sectionName in @($sections.Keys)) {
        Assert-Condition -Condition ($sectionName -notmatch '(?i)^DefaultInstall(\.|$)') -Message "DefaultInstall is prohibited: [$sectionName]"
        Assert-Condition -Condition ($sectionName -notmatch '(?i)^ClassInstall32(\.|$)') -Message "ClassInstall32 is prohibited: [$sectionName]"
        Assert-Condition -Condition ($sectionName -notmatch '(?i)\.CoInstallers$') -Message "Co-installer section is prohibited: [$sectionName]"
    }

    $versionLines = @($sections['Version'])
    $classValues = @(Get-DirectiveValues -Lines $versionLines -Name 'Class')
    $classGuidValues = @(Get-DirectiveValues -Lines $versionLines -Name 'ClassGuid')
    $extensionIdValues = @(Get-DirectiveValues -Lines $versionLines -Name 'ExtensionId')
    $pnpLockdownValues = @(Get-DirectiveValues -Lines $versionLines -Name 'PnpLockdown')
    $catalogValues = @(Get-DirectiveValues -Lines $versionLines -Name 'CatalogFile')
    Assert-Condition -Condition ($classValues.Count -eq 1) -Message 'Version Class is missing or duplicated.'
    Assert-Condition -Condition ($classValues[0] -eq 'Extension') -Message 'Prototype must use Class=Extension.'
    Assert-Condition -Condition ($classGuidValues.Count -eq 1 -and $classGuidValues[0] -eq '{E2F84CE7-8EFA-411C-AA69-97454CA4CB57}') -Message 'Prototype must use the Windows Extension class GUID.'
    Assert-Condition -Condition ($extensionIdValues.Count -eq 1 -and $extensionIdValues[0] -eq '{69E7CCD7-7011-4059-95D4-618974E126DD}') -Message 'Prototype ExtensionId changed unexpectedly.'
    Assert-Condition -Condition ($pnpLockdownValues.Count -eq 1 -and $pnpLockdownValues[0] -eq '1') -Message 'Prototype must use PnpLockdown=1.'
    Assert-Condition -Condition ($catalogValues.Count -eq 1 -and $catalogValues[0] -eq 'ChatpadFilterExtension.cat') -Message 'Prototype must declare only the future ChatpadFilterExtension.cat catalog identity.'

    $manufacturerLines = @($sections['Manufacturer'])
    Assert-Condition -Condition ($manufacturerLines.Count -eq 1 -and $manufacturerLines[0] -match '(?i)^%ProviderName%\s*=\s*Models\s*,\s*NTamd64\.10\.0\.\.\.22000$') -Message 'Manufacturer decoration must be exactly NTamd64.10.0...22000.'

    $destinationValues = @(Get-DirectiveValues -Lines @($sections['DestinationDirs']) -Name 'ChatpadFilter_CopyFiles')
    $sourceFileValues = @(Get-DirectiveValues -Lines @($sections['SourceDisksFiles']) -Name 'ChatpadFilter.sys')
    $installCopyValues = @(Get-DirectiveValues -Lines @($sections['ChatpadFilter_Install.NT']) -Name 'CopyFiles')
    $copyFileLines = @($sections['ChatpadFilter_CopyFiles'])
    Assert-Condition -Condition ($destinationValues.Count -eq 1 -and $destinationValues[0] -eq '13') -Message 'ChatpadFilter copy destination must be DIRID 13.'
    Assert-Condition -Condition ($sourceFileValues.Count -eq 1 -and $sourceFileValues[0] -eq '1,,') -Message 'SourceDisksFiles must contain only ChatpadFilter.sys on disk 1.'
    Assert-Condition -Condition ($installCopyValues.Count -eq 1 -and $installCopyValues[0] -eq 'ChatpadFilter_CopyFiles') -Message 'Device install section must copy only ChatpadFilter_CopyFiles.'
    Assert-Condition -Condition ($copyFileLines.Count -eq 1 -and $copyFileLines[0] -eq 'ChatpadFilter.sys') -Message 'CopyFiles section must contain only ChatpadFilter.sys.'

    $modelLines = @($sections['Models.NTamd64.10.0...22000'] | Where-Object { $_ -match '=' })
    Assert-Condition -Condition ($modelLines.Count -eq 1) -Message 'Prototype must contain exactly one device model.'
    $modelParts = @(($modelLines[0] -split '=', 2)[1] -split ',' | ForEach-Object { $_.Trim() })
    Assert-Condition -Condition ($modelParts.Count -eq 2) -Message 'Device model must contain one install section and one hardware ID.'
    Assert-Condition -Condition ($modelParts[0] -eq 'ChatpadFilter_Install') -Message 'Unexpected device install section.'
    Assert-Condition -Condition ($modelParts[1] -eq 'USB\VID_045E&PID_028E') -Message 'Hardware ID must be exactly USB\VID_045E&PID_028E.'

    $hardwareIds = New-Object 'System.Collections.Generic.List[string]'
    foreach ($match in [regex]::Matches($activeText, '(?i)\b(?:USB|HID|ROOT|SWD)\\[^,\s"]+')) {
        $hardwareIds.Add($match.Value)
    }
    Assert-Condition -Condition ($hardwareIds.Count -eq 1 -and $hardwareIds[0] -eq 'USB\VID_045E&PID_028E') -Message "Unexpected or broadened hardware IDs: $($hardwareIds -join ', ')"
    Assert-Condition -Condition ($activeText -notmatch '(?i)USB\\VID_045E&PID_028E\\') -Message 'Unique device-instance suffix is prohibited.'
    Assert-Condition -Condition ($activeText -notmatch '(?i)USB\\VID_045E&PID_028E&') -Message 'Revision, interface, or other broadened target suffix is prohibited.'

    $filterValues = @(Get-DirectiveValues -Lines @($sections['ChatpadFilter_Install.NT.Filters']) -Name 'AddFilter')
    Assert-Condition -Condition ($filterValues.Count -eq 1 -and $filterValues[0] -eq 'ChatpadFilter,,ChatpadFilter_LowerFilter') -Message 'AddFilter must register only ChatpadFilter.'
    $positionValues = @(Get-DirectiveValues -Lines @($sections['ChatpadFilter_LowerFilter']) -Name 'FilterPosition')
    $filterLevelValues = @(Get-DirectiveValues -Lines @($sections['ChatpadFilter_LowerFilter']) -Name 'FilterLevel')
    Assert-Condition -Condition ($positionValues.Count -eq 1 -and $positionValues[0] -eq 'Lower') -Message 'FilterPosition must be Lower.'
    Assert-Condition -Condition ($filterLevelValues.Count -eq 0) -Message 'No undocumented FilterLevel may be declared.'

    $serviceValues = @(Get-DirectiveValues -Lines @($sections['ChatpadFilter_Install.NT.Services']) -Name 'AddService')
    Assert-Condition -Condition ($serviceValues.Count -eq 1 -and $serviceValues[0] -eq 'ChatpadFilter,,ChatpadFilter_Service_Install') -Message 'AddService must register a non-associated ChatpadFilter service only.'
    $serviceLines = @($sections['ChatpadFilter_Service_Install'])
    $serviceTypeValues = @(Get-DirectiveValues -Lines $serviceLines -Name 'ServiceType')
    $startTypeValues = @(Get-DirectiveValues -Lines $serviceLines -Name 'StartType')
    $errorControlValues = @(Get-DirectiveValues -Lines $serviceLines -Name 'ErrorControl')
    $serviceBinaryValues = @(Get-DirectiveValues -Lines $serviceLines -Name 'ServiceBinary')
    Assert-Condition -Condition ($serviceTypeValues.Count -eq 1 -and $serviceTypeValues[0] -eq '1') -Message 'ServiceType must be SERVICE_KERNEL_DRIVER (1).'
    Assert-Condition -Condition ($startTypeValues.Count -eq 1 -and $startTypeValues[0] -eq '3') -Message 'StartType must be SERVICE_DEMAND_START (3).'
    Assert-Condition -Condition ($errorControlValues.Count -eq 1 -and $errorControlValues[0] -eq '1') -Message 'ErrorControl must be SERVICE_ERROR_NORMAL (1).'
    Assert-Condition -Condition ($serviceBinaryValues.Count -eq 1 -and $serviceBinaryValues[0] -eq '%13%\ChatpadFilter.sys') -Message 'ServiceBinary must use DIRID 13 and ChatpadFilter.sys.'

    $wdfValues = @(Get-DirectiveValues -Lines @($sections['ChatpadFilter_Install.NT.Wdf']) -Name 'KmdfService')
    $kmdfVersionValues = @(Get-DirectiveValues -Lines @($sections['ChatpadFilter_Wdf']) -Name 'KmdfLibraryVersion')
    Assert-Condition -Condition ($wdfValues.Count -eq 1 -and $wdfValues[0] -eq 'ChatpadFilter,ChatpadFilter_Wdf') -Message 'KmdfService must reference ChatpadFilter and its prototype WDF section.'
    Assert-Condition -Condition ($kmdfVersionValues.Count -eq 1 -and $kmdfVersionValues[0] -eq '1.15') -Message 'KmdfLibraryVersion must remain 1.15.'

    Assert-Condition -Condition ($activeText -notmatch '(?i)\b(?:LowerFilters|UpperFilters)\b') -Message 'Direct UpperFilters/LowerFilters mutation is prohibited.'
    Assert-Condition -Condition ($activeText -notmatch '(?im)^\s*(?:AddReg|DelReg|CopyINF|Include|Needs)\s*=') -Message 'Registry, INF-copy, and external-section directives are prohibited.'
    Assert-Condition -Condition ($activeText -notmatch '(?i)\bSPSVCINST_ASSOCSERVICE\b') -Message 'Associated function-service flags are prohibited.'
    Assert-Condition -Condition ($activeText -notmatch '(?i)\bxusb22\b') -Message 'Prototype must not claim or replace the xusb22 function service.'
    Assert-Condition -Condition ($activeText -notmatch '(?i)(?:[A-Z]:\\|\\\\)') -Message 'Absolute or network paths are prohibited.'
    Assert-Condition -Condition ($activeText -notmatch '(?i)(?:\.(?:exe|cmd|bat|ps1|vbs|js)\b|RunPreSetupCommands|RunPostSetupCommands|RegisterDlls|UnregisterDlls)') -Message 'Executable, script, or command directives are prohibited.'
    Assert-Condition -Condition ($activeText -notmatch '(?i)\b(?:HIDClass|XnaComposite|USBDevice)\b') -Message 'Prototype must not target HID, XnaComposite, or USB classes.'

    $prohibitedCompanions = @(
        Get-ChildItem -LiteralPath $prototypeRoot -Recurse -File |
            Where-Object { $_.Extension -match '(?i)^\.(?:cat|cer|crt|der|pem|pfx|p12|pvk|spc|key|snk|cab|msi|exe|dll|sys)$' }
    )
    $prohibitedCompanionPaths = @($prohibitedCompanions | ForEach-Object { $_.FullName })
    Assert-Condition -Condition ($prohibitedCompanions.Count -eq 0) -Message "Prototype directory contains package, signing, binary, or executable files: $($prohibitedCompanionPaths -join ', ')"

    $referenceExtensions = @('.ps1', '.psm1', '.cmd', '.bat', '.sln', '.vcxproj', '.props', '.targets', '.proj', '.csproj')
    $allowedReferenceFiles = @(
        [System.IO.Path]::GetFullPath($PSCommandPath),
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'tools\Test-RepositorySafety.ps1')))
    $unexpectedReferences = New-Object 'System.Collections.Generic.List[string]'
    Get-ChildItem -LiteralPath $repoRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension.ToLowerInvariant() -in $referenceExtensions -and
            -not $_.FullName.StartsWith((Join-Path $repoRoot 'artifacts'), [System.StringComparison]::OrdinalIgnoreCase) -and
            $allowedReferenceFiles -notcontains [System.IO.Path]::GetFullPath($_.FullName)
        } |
        ForEach-Object {
            $text = [System.IO.File]::ReadAllText($_.FullName)
            if ($text -match '(?i)ChatpadFilterExtension\.inf|prototypes[\\/]inf[\\/]ChatpadFilterExtension') {
                $unexpectedReferences.Add($_.FullName)
            }
        }
    Assert-Condition -Condition ($unexpectedReferences.Count -eq 0) -Message "Prototype INF is referenced by build/package/install tooling: $($unexpectedReferences -join ', ')"

    $filterProject = Join-Path $repoRoot 'src\driver\ChatpadFilter\ChatpadFilter.vcxproj'
    $filterProjectText = [System.IO.File]::ReadAllText($filterProject)
    Assert-Condition -Condition ($filterProjectText -notmatch '(?i)\.inf|ChatpadFilterExtension|prototypes[\\/]inf') -Message 'ChatpadFilter.vcxproj references the prototype INF.'
    & git -C $repoRoot diff --quiet -- $filterProject
    Assert-Condition -Condition ($LASTEXITCODE -eq 0) -Message 'ChatpadFilter.vcxproj has unstaged modifications.'
    & git -C $repoRoot diff --cached --quiet -- $filterProject
    Assert-Condition -Condition ($LASTEXITCODE -eq 0) -Message 'ChatpadFilter.vcxproj has staged modifications.'

    $programFilesX86 = [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
    $kitsRoot = Join-Path $programFilesX86 'Windows Kits\10'
    try {
        $installedRoots = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots'
        if ($installedRoots.KitsRoot10) {
            $kitsRoot = [string]$installedRoots.KitsRoot10
        }
    }
    catch {
        # The standard Program Files fallback remains read-only and deterministic.
    }

    $infVerifPath = $null
    foreach ($versionDirectory in (Get-NumericVersionDirectories -Path (Join-Path $kitsRoot 'Tools'))) {
        $candidate = Join-Path $versionDirectory.FullName 'x64\infverif.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $infVerifPath = $candidate
            break
        }
    }
    Assert-Condition -Condition ($null -ne $infVerifPath) -Message "Installed x64 InfVerif was not found beneath $kitsRoot."

    $helpOutput = @(& $infVerifPath '/?' 2>&1 | ForEach-Object { $_.ToString() })
    $helpExitCode = $LASTEXITCODE
    [System.IO.File]::WriteAllText($helpLogPath, (($helpOutput -join [Environment]::NewLine) + [Environment]::NewLine), [System.Text.Encoding]::UTF8)
    Assert-Condition -Condition ($helpExitCode -eq 0) -Message "InfVerif help exited $helpExitCode."
    $helpText = $helpOutput -join [Environment]::NewLine
    Assert-Condition -Condition ($helpText -match '(?i)/k\b') -Message 'Installed InfVerif does not advertise declarative-driver /k mode.'

    $validationArguments = New-Object 'System.Collections.Generic.List[string]'
    $validationArguments.Add('/k')
    if ($helpText -match '(?i)/v\b') {
        $validationArguments.Add('/v')
    }
    $validationArguments.Add($infPath)
    $toolOutput = @(& $infVerifPath @($validationArguments) 2>&1 | ForEach-Object { $_.ToString() })
    $validationExitCode = $LASTEXITCODE
    [System.IO.File]::WriteAllText($toolLogPath, (($toolOutput -join [Environment]::NewLine) + [Environment]::NewLine), [System.Text.Encoding]::UTF8)

    $infoArguments = New-Object 'System.Collections.Generic.List[string]'
    $infoOutput = @()
    $infoExitCode = 0
    if ($helpText -match '(?i)/info\b') {
        $infoArguments.Add('/k')
        $infoArguments.Add('/info')
        $infoArguments.Add($infPath)
        $infoOutput = @(& $infVerifPath @($infoArguments) 2>&1 | ForEach-Object { $_.ToString() })
        $infoExitCode = $LASTEXITCODE
        [System.IO.File]::WriteAllText($infoLogPath, (($infoOutput -join [Environment]::NewLine) + [Environment]::NewLine), [System.Text.Encoding]::UTF8)
    }

    $annotatedArguments = New-Object 'System.Collections.Generic.List[string]'
    $annotatedOutput = @()
    $annotatedExitCode = 0
    if ($helpText -match '(?i)/l\s+<path>') {
        $annotatedArguments.Add('/k')
        $annotatedArguments.Add('/l')
        $annotatedArguments.Add($htmlOutput)
        $annotatedArguments.Add($infPath)
        $annotatedOutput = @(& $infVerifPath @($annotatedArguments) 2>&1 | ForEach-Object { $_.ToString() })
        $annotatedExitCode = $LASTEXITCODE
        [System.IO.File]::WriteAllText($annotatedLogPath, (($annotatedOutput -join [Environment]::NewLine) + [Environment]::NewLine), [System.Text.Encoding]::UTF8)
    }

    $infVerifExitCode = $validationExitCode
    if ($infVerifExitCode -eq 0 -and $infoExitCode -ne 0) {
        $infVerifExitCode = $infoExitCode
    }
    if ($infVerifExitCode -eq 0 -and $annotatedExitCode -ne 0) {
        $infVerifExitCode = $annotatedExitCode
    }

    $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($infVerifPath)
    $infHash = Get-FileSha256Hash -Path $infPath
    $evidence.Add('Semantic guards: PASS')
    $evidence.Add('Target architecture: AMD64')
    $evidence.Add('Minimum target: Windows 11 build 22000 (NTamd64.10.0...22000)')
    $evidence.Add('Class: Extension')
    $evidence.Add('ExtensionId: {69E7CCD7-7011-4059-95D4-618974E126DD}')
    $evidence.Add('Hardware ID: USB\VID_045E&PID_028E')
    $evidence.Add('Filter directive: AddFilter=ChatpadFilter')
    $evidence.Add('Filter placement: FilterPosition=Lower; no named FilterLevel')
    $evidence.Add('Service section: non-associated ChatpadFilter kernel service, demand start, DIRID 13')
    $evidence.Add('KMDF version: 1.15')
    $evidence.Add('Class-wide filters: absent')
    $evidence.Add('Function-driver replacement: absent; xusb22 not referenced')
    $evidence.Add('Co-installers and install scripts: absent')
    $evidence.Add('Catalog declaration: ChatpadFilterExtension.cat; catalog/signing output absent')
    $evidence.Add("INF SHA-256: $infHash")
    $evidence.Add("InfVerif path: $infVerifPath")
    $evidence.Add("InfVerif version: $($versionInfo.FileVersion)")
    $evidence.Add("InfVerif validation arguments: $($validationArguments -join ' ')")
    $evidence.Add("InfVerif validation exit code: $validationExitCode")
    $evidence.Add("InfVerif info exit code: $infoExitCode")
    $evidence.Add("InfVerif annotated exit code: $annotatedExitCode")
    $evidence.Add("InfVerif exit code: $infVerifExitCode")
    [System.IO.File]::WriteAllText($semanticLogPath, (($evidence -join [Environment]::NewLine) + [Environment]::NewLine), [System.Text.Encoding]::UTF8)

    Write-Output "InfVerif: $infVerifPath"
    Write-Output "InfVerif version: $($versionInfo.FileVersion)"
    Write-Output "Validated INF: $infPath"
    Write-Output "INF SHA-256: $infHash"
    Write-Output "InfVerif validation arguments: $($validationArguments -join ' ')"
    $toolOutput | Write-Output
    if ($infoOutput.Count -gt 0) {
        Write-Output "InfVerif info arguments: $($infoArguments -join ' ')"
        $infoOutput | Write-Output
    }
    if ($annotatedOutput.Count -gt 0) {
        Write-Output "InfVerif annotated arguments: $($annotatedArguments -join ' ')"
        $annotatedOutput | Write-Output
    }
    Write-Output "InfVerif validation exit code: $validationExitCode"
    Write-Output "InfVerif info exit code: $infoExitCode"
    Write-Output "InfVerif annotated exit code: $annotatedExitCode"
    Write-Output "InfVerif exit code: $infVerifExitCode"
    Write-Output 'Semantic guards: PASS'
    Write-Output 'Target: AMD64, Windows 11 build 22000 and later'
    Write-Output 'Extension INF: PASS (Class=Extension and stable ExtensionId)'
    Write-Output 'Device association: PASS (only USB\VID_045E&PID_028E)'
    Write-Output 'Filter: PASS (AddFilter=ChatpadFilter, FilterPosition=Lower, no FilterLevel)'
    Write-Output 'Service: PASS (non-associated kernel service, demand start, DIRID 13, KMDF 1.15)'
    Write-Output 'Catalog declaration: ChatpadFilterExtension.cat (required by InfVerif); catalog file/signing output: ABSENT'
    Write-Output 'Class-wide filters, function-driver replacement, co-installers, install scripts: ABSENT'
    Write-Output "Help log: $helpLogPath"
    Write-Output "InfVerif log: $toolLogPath"
    if (Test-Path -LiteralPath $infoLogPath -PathType Leaf) {
        Write-Output "InfVerif info log: $infoLogPath"
    }
    if (Test-Path -LiteralPath $annotatedLogPath -PathType Leaf) {
        Write-Output "InfVerif annotated log: $annotatedLogPath"
    }
    Write-Output "Semantic log: $semanticLogPath"

    if ($infVerifExitCode -ne 0) {
        exit $infVerifExitCode
    }
}
catch {
    $failureText = "Semantic guards: FAIL`r`n$($_.Exception.Message)`r`n$($_.ScriptStackTrace)`r`n"
    [System.IO.File]::WriteAllText($semanticLogPath, $failureText, [System.Text.Encoding]::UTF8)
    Write-Output ("FAIL: {0}" -f $_.Exception.Message)
    Write-Output $_.ScriptStackTrace
    Write-Output "Semantic log: $semanticLogPath"
    exit 1
}

exit 0
