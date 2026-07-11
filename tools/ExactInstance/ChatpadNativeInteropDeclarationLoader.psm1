Set-StrictMode -Version Latest

# Dormant declaration loader contract. The loading operation is private and may
# be called only after TASK 8H authorization validation and
# atomic TASK 8H authorization consumption. This ordering is architectural; no module-scope
# value is a sentinel, capability, or substitute for authorization.

$script:OriginalRelativeName = 'NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs'
$script:SupplementalRelativeName = 'NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.LiveApplyExtensions.cs'
$script:OriginalRawSize = 10238L
$script:OriginalRawSha256 = 'E55E6E34BBB4DB40904F065292F23A76D48BE809D18E7EB76E0C3A7ECCA786F2'
$script:OriginalCanonicalLfSize = 10034L
$script:OriginalCanonicalLfSha256 = 'B4D24BF374B391A36B4A3513B117A2FF50F8BC3D8795248808086AC984E874D9'
$script:SupplementalRawSize = 4021L
$script:SupplementalRawSha256 = '5DF2A728416FA3855684979481507A766309B2853F9BDCBB1A551BA18B849EA5'
$script:SupplementalCanonicalLfSize = 4021L
$script:SupplementalCanonicalLfSha256 = '5DF2A728416FA3855684979481507A766309B2853F9BDCBB1A551BA18B849EA5'

$script:ExpectedTypeNames = @(
    'Chatpad.ExactInstance.NativeInterop.SetupApiNewdevDeclarations'
    'Chatpad.ExactInstance.NativeInterop.ChatpadDeviceInfoSetHandleToken'
    'Chatpad.ExactInstance.NativeInterop.SP_DEVINFO_DATA'
    'Chatpad.ExactInstance.NativeInterop.SP_DEVINSTALL_PARAMS_W'
    'Chatpad.ExactInstance.NativeInterop.SP_DRVINSTALL_PARAMS'
    'Chatpad.ExactInstance.NativeInterop.SP_DRVINFO_DATA_W'
    'Chatpad.ExactInstance.NativeInterop.SP_DRVINFO_DETAIL_DATA_W'
    'Chatpad.ExactInstance.NativeInterop.DEVPROPKEY'
    'Chatpad.ExactInstance.NativeInterop.SetupApiNewdevLiveApplyExtensions'
)

$script:ExpectedOriginalMethods = @(
    'SetupDiCreateDeviceInfoList'
    'SetupDiDestroyDeviceInfoList'
    'SetupDiOpenDeviceInfoW'
    'SetupDiGetDeviceInstanceIdW'
    'SetupDiGetDevicePropertyW'
    'SetupDiGetDeviceRegistryPropertyW'
    'SetupDiBuildDriverInfoList'
    'SetupDiDestroyDriverInfoList'
    'SetupDiEnumDriverInfoW'
    'SetupDiGetDriverInfoDetailW'
    'SetupDiGetDriverInstallParamsW'
    'SetupDiSetSelectedDriverW'
    'DiInstallDevice'
)
$script:ExpectedSupplementalMethods = @(
    'SetupDiGetDeviceInstallParamsW'
    'SetupDiSetDeviceInstallParamsW'
)
$script:ExpectedOriginalConstants = @(
    'MaxPath'
    'LineLength'
    'AnySizeArray'
    'SPDIT_COMPATDRIVER'
    'DIGCF_PRESENT'
    'ERROR_INSUFFICIENT_BUFFER'
    'ERROR_NO_MORE_ITEMS'
    'INVALID_HANDLE_VALUE'
)
$script:ExpectedSupplementalConstants = @(
    'SPDRP_DEVICEDESC'
    'SPDRP_HARDWAREID'
    'SPDRP_COMPATIBLEIDS'
    'SPDRP_SERVICE'
    'SPDRP_CLASSGUID'
    'SPDRP_DRIVER'
    'SPDRP_MFG'
    'SPDRP_FRIENDLYNAME'
    'DI_NEEDRESTART'
    'DI_NEEDREBOOT'
    'DI_ENUMSINGLEINF'
    'DI_FLAGSEX_SEARCH_PUBLISHED_INFS'
)
$script:ExpectedSupplementalFields = @('DEVPKEY_Device_ContainerId')
$script:ExpectedStructureFields = [ordered]@{
    'Chatpad.ExactInstance.NativeInterop.ChatpadDeviceInfoSetHandleToken' = @('<Value>k__BackingField')
    'Chatpad.ExactInstance.NativeInterop.SP_DEVINFO_DATA' = @('cbSize','ClassGuid','DevInst','Reserved')
    'Chatpad.ExactInstance.NativeInterop.SP_DEVINSTALL_PARAMS_W' = @('cbSize','Flags','FlagsEx','hwndParent','InstallMsgHandler','InstallMsgHandlerContext','FileQueue','ClassInstallReserved','Reserved','DriverPath')
    'Chatpad.ExactInstance.NativeInterop.SP_DRVINSTALL_PARAMS' = @('cbSize','Rank','Flags','PrivateData','Reserved')
    'Chatpad.ExactInstance.NativeInterop.SP_DRVINFO_DATA_W' = @('cbSize','DriverType','Reserved','Description','MfgName','ProviderName','DriverDate','DriverVersion')
    'Chatpad.ExactInstance.NativeInterop.SP_DRVINFO_DETAIL_DATA_W' = @('cbSize','InfDate','CompatIDsOffset','CompatIDsLength','Reserved','SectionName','InfFileName','DrvDescription','HardwareID')
    'Chatpad.ExactInstance.NativeInterop.DEVPROPKEY' = @('fmtid','pid')
}

function Get-ChatpadSha256Hex {
    param([Parameter(Mandatory = $true)][byte[]] $Bytes)

    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '')
    }
    finally {
        $algorithm.Dispose()
    }
}

function Get-ChatpadDeclarationFileState {
    param(
        [Parameter(Mandatory = $true)][string] $Candidate,
        [Parameter(Mandatory = $true)][string] $ExpectedLeaf,
        [Parameter(Mandatory = $true)][long] $ExpectedRawSize,
        [Parameter(Mandatory = $true)][string] $ExpectedRawHash,
        [Parameter(Mandatory = $true)][long] $ExpectedCanonicalSize,
        [Parameter(Mandatory = $true)][string] $ExpectedCanonicalHash
    )

    $root = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\', '/')
    $fullName = [System.IO.Path]::GetFullPath($Candidate)
    $requiredPrefix = $root + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullName.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'DECLARATION_PATH_OUTSIDE_FIXED_ROOT'
    }
    if ([System.IO.Path]::GetFileName($fullName) -cne $ExpectedLeaf) {
        throw 'DECLARATION_LEAF_NAME_MISMATCH'
    }
    if (-not [System.IO.File]::Exists($fullName)) {
        throw 'DECLARATION_FILE_MISSING'
    }

    $item = Get-Item -LiteralPath $fullName -Force -ErrorAction Stop
    if ($item.PSIsContainer -or (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw 'DECLARATION_FILE_NOT_REGULAR'
    }
    $ancestor = $item.Directory
    while ($null -ne $ancestor -and $ancestor.FullName.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        if (($ancestor.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'DECLARATION_PARENT_REPARSE_POINT'
        }
        $ancestor = $ancestor.Parent
    }

    $bytes = [System.IO.File]::ReadAllBytes($fullName)
    $rawHash = Get-ChatpadSha256Hex -Bytes $bytes
    $utf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $text = $utf8.GetString($bytes)
    $canonicalText = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $canonicalBytes = $utf8.GetBytes($canonicalText)
    $canonicalHash = Get-ChatpadSha256Hex -Bytes $canonicalBytes

    if ($bytes.LongLength -ne $ExpectedRawSize -or $rawHash -cne $ExpectedRawHash -or
        $canonicalBytes.LongLength -ne $ExpectedCanonicalSize -or $canonicalHash -cne $ExpectedCanonicalHash) {
        throw 'DECLARATION_IDENTITY_MISMATCH'
    }

    [pscustomobject]@{
        FullName = $fullName
        Text = $text
        RawSize = $bytes.LongLength
        RawSha256 = $rawHash
        CanonicalLfSize = $canonicalBytes.LongLength
        CanonicalLfSha256 = $canonicalHash
    }
}

function Get-ChatpadNamedMatches {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [Parameter(Mandatory = $true)][string] $Pattern
    )

    @([regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline) |
        ForEach-Object { $_.Groups['name'].Value })
}

function Assert-ChatpadExactNames {
    param(
        [Parameter(Mandatory = $true)][string[]] $Actual,
        [Parameter(Mandatory = $true)][string[]] $Expected,
        [Parameter(Mandatory = $true)][string] $FailureCode
    )

    if ($Actual.Count -ne $Expected.Count) { throw $FailureCode }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($Actual[$index] -cne $Expected[$index]) { throw $FailureCode }
    }
}

function Assert-ChatpadDeclarationSourceInventory {
    param(
        [Parameter(Mandatory = $true)][string] $OriginalText,
        [Parameter(Mandatory = $true)][string] $SupplementalText
    )

    $namespacePattern = '(?m)^namespace\s+Chatpad\.ExactInstance\.NativeInterop\s*$'
    if ([regex]::Matches($OriginalText, $namespacePattern).Count -ne 1 -or
        [regex]::Matches($SupplementalText, $namespacePattern).Count -ne 1) {
        throw 'DECLARATION_NAMESPACE_INVENTORY_MISMATCH'
    }

    $originalMethods = Get-ChatpadNamedMatches -Text $OriginalText -Pattern '(?m)^\s*internal\s+static\s+extern\s+\S+\s+(?<name>\w+)\s*\('
    $supplementalMethods = Get-ChatpadNamedMatches -Text $SupplementalText -Pattern '(?m)^\s*internal\s+static\s+extern\s+\S+\s+(?<name>\w+)\s*\('
    $originalConstants = Get-ChatpadNamedMatches -Text $OriginalText -Pattern '(?m)^\s*internal\s+const\s+\S+\s+(?<name>\w+)\s*='
    $supplementalConstants = Get-ChatpadNamedMatches -Text $SupplementalText -Pattern '(?m)^\s*internal\s+const\s+\S+\s+(?<name>\w+)\s*='
    $supplementalFields = Get-ChatpadNamedMatches -Text $SupplementalText -Pattern '(?m)^\s*internal\s+static\s+readonly\s+\S+\s+(?<name>\w+)\s*='

    Assert-ChatpadExactNames -Actual $originalMethods -Expected $script:ExpectedOriginalMethods -FailureCode 'ORIGINAL_METHOD_INVENTORY_MISMATCH'
    Assert-ChatpadExactNames -Actual $supplementalMethods -Expected $script:ExpectedSupplementalMethods -FailureCode 'SUPPLEMENTAL_METHOD_INVENTORY_MISMATCH'
    Assert-ChatpadExactNames -Actual $originalConstants -Expected $script:ExpectedOriginalConstants -FailureCode 'ORIGINAL_CONSTANT_INVENTORY_MISMATCH'
    Assert-ChatpadExactNames -Actual $supplementalConstants -Expected $script:ExpectedSupplementalConstants -FailureCode 'SUPPLEMENTAL_CONSTANT_INVENTORY_MISMATCH'
    Assert-ChatpadExactNames -Actual $supplementalFields -Expected $script:ExpectedSupplementalFields -FailureCode 'SUPPLEMENTAL_FIELD_INVENTORY_MISMATCH'

    $declaredTypes = @(
        Get-ChatpadNamedMatches -Text ($OriginalText + "`n" + $SupplementalText) -Pattern '(?m)^\s*internal\s+(?:readonly\s+)?(?:static\s+class|struct)\s+(?<name>\w+)'
    )
    $expectedShortTypes = @($script:ExpectedTypeNames | ForEach-Object { $_.Substring($_.LastIndexOf('.') + 1) })
    Assert-ChatpadExactNames -Actual $declaredTypes -Expected $expectedShortTypes -FailureCode 'DECLARATION_TYPE_INVENTORY_MISMATCH'
}

function Find-ChatpadExpectedDeclarationTypes {
    $found = @{}
    foreach ($assembly in [AppDomain]::CurrentDomain.GetAssemblies()) {
        foreach ($fullName in $script:ExpectedTypeNames) {
            $candidate = $assembly.GetType($fullName, $false, $false)
            if ($null -ne $candidate) {
                if ($found.ContainsKey($fullName)) { throw 'DUPLICATE_DECLARATION_TYPE_STATE' }
                $found[$fullName] = $candidate
            }
        }
    }
    return $found
}

function Assert-ChatpadLoadedDeclarationInventory {
    param([Parameter(Mandatory = $true)][hashtable] $Found)

    if ($Found.Count -ne $script:ExpectedTypeNames.Count) { throw 'LOADED_TYPE_INVENTORY_MISMATCH' }
    $binding = [System.Reflection.BindingFlags]'Static,Instance,Public,NonPublic,DeclaredOnly'
    $originalType = $Found['Chatpad.ExactInstance.NativeInterop.SetupApiNewdevDeclarations']
    $supplementalType = $Found['Chatpad.ExactInstance.NativeInterop.SetupApiNewdevLiveApplyExtensions']
    $originalMethods = @($originalType.GetMethods($binding) | Where-Object { $_.IsStatic } | ForEach-Object Name | Sort-Object)
    $supplementalMethods = @($supplementalType.GetMethods($binding) | Where-Object { $_.IsStatic } | ForEach-Object Name | Sort-Object)
    Assert-ChatpadExactNames -Actual $originalMethods -Expected @($script:ExpectedOriginalMethods | Sort-Object) -FailureCode 'LOADED_ORIGINAL_METHOD_INVENTORY_MISMATCH'
    Assert-ChatpadExactNames -Actual $supplementalMethods -Expected @($script:ExpectedSupplementalMethods | Sort-Object) -FailureCode 'LOADED_SUPPLEMENTAL_METHOD_INVENTORY_MISMATCH'

    $originalFields = @($originalType.GetFields($binding) | ForEach-Object Name | Sort-Object)
    $supplementalFields = @($supplementalType.GetFields($binding) | ForEach-Object Name | Sort-Object)
    Assert-ChatpadExactNames -Actual $originalFields -Expected @($script:ExpectedOriginalConstants | Sort-Object) -FailureCode 'LOADED_ORIGINAL_FIELD_INVENTORY_MISMATCH'
    Assert-ChatpadExactNames -Actual $supplementalFields -Expected @(($script:ExpectedSupplementalConstants + $script:ExpectedSupplementalFields) | Sort-Object) -FailureCode 'LOADED_SUPPLEMENTAL_FIELD_INVENTORY_MISMATCH'

    foreach ($fullName in $script:ExpectedStructureFields.Keys) {
        $actualFields = @($Found[$fullName].GetFields($binding) | ForEach-Object Name | Sort-Object)
        Assert-ChatpadExactNames -Actual $actualFields -Expected @($script:ExpectedStructureFields[$fullName] | Sort-Object) -FailureCode 'LOADED_STRUCTURE_FIELD_INVENTORY_MISMATCH'
    }

    $assemblyNames = @($Found.Values | ForEach-Object { $_.Assembly.FullName } | Select-Object -Unique)
    if ($assemblyNames.Count -ne 1) { throw 'LOADED_ASSEMBLY_INVENTORY_MISMATCH' }
    $assembly = @($Found.Values)[0].Assembly
    $actualTypeNames = @($assembly.GetTypes() | Where-Object Namespace -ceq 'Chatpad.ExactInstance.NativeInterop' | ForEach-Object FullName | Sort-Object)
    Assert-ChatpadExactNames -Actual $actualTypeNames -Expected @($script:ExpectedTypeNames | Sort-Object) -FailureCode 'LOADED_NAMESPACE_TYPE_INVENTORY_MISMATCH'
}

function Invoke-ChatpadNativeInteropDeclarationLoad {
    [CmdletBinding()]
    param()

    $compilationAttempted = $false
    try {
        $originalCandidate = Join-Path $PSScriptRoot $script:OriginalRelativeName
        $supplementalCandidate = Join-Path $PSScriptRoot $script:SupplementalRelativeName
        $original = Get-ChatpadDeclarationFileState -Candidate $originalCandidate -ExpectedLeaf 'Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs' -ExpectedRawSize $script:OriginalRawSize -ExpectedRawHash $script:OriginalRawSha256 -ExpectedCanonicalSize $script:OriginalCanonicalLfSize -ExpectedCanonicalHash $script:OriginalCanonicalLfSha256
        $supplemental = Get-ChatpadDeclarationFileState -Candidate $supplementalCandidate -ExpectedLeaf 'Chatpad.NativeInterop.SetupApiNewdev.LiveApplyExtensions.cs' -ExpectedRawSize $script:SupplementalRawSize -ExpectedRawHash $script:SupplementalRawSha256 -ExpectedCanonicalSize $script:SupplementalCanonicalLfSize -ExpectedCanonicalHash $script:SupplementalCanonicalLfSha256
        Assert-ChatpadDeclarationSourceInventory -OriginalText $original.Text -SupplementalText $supplemental.Text

        $before = Find-ChatpadExpectedDeclarationTypes
        if ($before.Count -gt 0) {
            return [pscustomobject]@{
                Status = 'FAILED'
                Reason = 'PREEXISTING_DECLARATION_TYPE_REJECTED'
                ExpectedTypeNames = @($script:ExpectedTypeNames)
                PresentTypeNames = @($before.Keys | Sort-Object)
                CompilationAttempted = $false
            }
        }

        # Future-only dormant compilation. No output assembly path is supplied.
        $compilationAttempted = $true
        $null = Add-Type -TypeDefinition ($original.Text + "`n" + $supplemental.Text) -Language CSharp -ErrorAction Stop
        $after = Find-ChatpadExpectedDeclarationTypes
        Assert-ChatpadLoadedDeclarationInventory -Found $after
        $assemblyNames = @($after.Values | ForEach-Object { $_.Assembly.FullName } | Select-Object -Unique)
        if ($assemblyNames.Count -ne 1) { throw 'LOADED_ASSEMBLY_INVENTORY_MISMATCH' }

        return [pscustomobject]@{ Status = 'LOADED'; Reason = 'EXACT_FIXED_SOURCES_VALIDATED'; OriginalRawSha256 = $script:OriginalRawSha256; SupplementalRawSha256 = $script:SupplementalRawSha256; CompilationAttempted = $true }
    }
    catch {
        return [pscustomobject]@{ Status = 'FAILED'; Reason = 'DECLARATION_LOAD_CONTRACT_REJECTED'; OriginalRawSha256 = $script:OriginalRawSha256; SupplementalRawSha256 = $script:SupplementalRawSha256; CompilationAttempted = $compilationAttempted }
    }
}

Export-ModuleMember -Function @()
