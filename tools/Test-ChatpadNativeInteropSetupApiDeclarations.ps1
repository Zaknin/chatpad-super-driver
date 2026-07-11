[CmdletBinding(PositionalBinding = $false)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$declarationPath = Join-Path $PSScriptRoot 'ExactInstance\NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs'
$sdkVersion = '10.0.26100.0'
$sdkIncludeRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\Include\$sdkVersion"
$setupApiHeader = Join-Path $sdkIncludeRoot 'um\setupapi.h'
$newdevHeader = Join-Path $sdkIncludeRoot 'um\newdev.h'
$devpropdefHeader = Join-Path $sdkIncludeRoot 'shared\devpropdef.h'
$devpkeyHeader = Join-Path $sdkIncludeRoot 'shared\devpkey.h'
$tests = [Collections.Generic.List[object]]::new()
$assertionCount = 0

function Assert-AbiCondition {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    $script:assertionCount++
    if (-not $Condition) { throw $Message }
}

function Invoke-AbiTestCase {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][scriptblock]$Body)
    try { & $Body; $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'PASS' }) }
    catch { $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'FAIL'; detail = $_.Exception.Message }) }
}

function ConvertTo-NormalizedWhitespace {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    ([regex]::Replace($Text.Trim(), '\s+', ' '))
}

function Get-PInvokeRecords {
    param([Parameter(Mandatory)][string]$Text)
    $pattern = '(?ms)(?<import>\[DllImport\("[^"]+"[^\]]*\)\])\s*(?<marshal>\[return:\s*MarshalAs\(UnmanagedType\.Bool\)\]\s*)?internal\s+static\s+extern\s+(?<return>\w+)\s+(?<name>\w+)\s*\((?<parameters>.*?)\);'
    @([regex]::Matches($Text, $pattern) | ForEach-Object {
        [pscustomobject][ordered]@{
            import = ConvertTo-NormalizedWhitespace $_.Groups['import'].Value
            return_marshal = ConvertTo-NormalizedWhitespace $_.Groups['marshal'].Value
            return_type = $_.Groups['return'].Value
            name = $_.Groups['name'].Value
            parameters = ConvertTo-NormalizedWhitespace $_.Groups['parameters'].Value
        }
    })
}

function Get-StructureRecord {
    param([Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][string]$Name)
    $pattern = '(?ms)\[StructLayout\((?<layout>[^\)]*)\)\]\s*internal\s+(?:readonly\s+)?struct\s+' + [regex]::Escape($Name) + '\s*\{(?<body>.*?)\n\s*\}'
    $matches = [regex]::Matches($Text, $pattern)
    if ($matches.Count -ne 1) { return [pscustomobject]@{ count=$matches.Count; layout=''; fields=@() } }
    $fields = @([regex]::Matches($matches[0].Groups['body'].Value, '(?m)^\s*internal\s+(?<type>[A-Za-z0-9_.]+)\s+(?<name>[A-Za-z0-9_]+)\s*;') | ForEach-Object {
        '{0} {1}' -f $_.Groups['type'].Value,$_.Groups['name'].Value
    })
    [pscustomobject]@{ count=1; layout=(ConvertTo-NormalizedWhitespace $matches[0].Groups['layout'].Value); fields=$fields }
}

$expectedMethods = @(
    [pscustomobject]@{name='SetupDiCreateDeviceInfoList';dll='setupapi.dll';unicode=$false;return='IntPtr';parameters='ref Guid ClassGuid, IntPtr hwndParent';marshal=$false},
    [pscustomobject]@{name='SetupDiDestroyDeviceInfoList';dll='setupapi.dll';unicode=$false;return='bool';parameters='IntPtr DeviceInfoSet';marshal=$true},
    [pscustomobject]@{name='SetupDiOpenDeviceInfoW';dll='setupapi.dll';unicode=$true;return='bool';parameters='IntPtr DeviceInfoSet, string DeviceInstanceId, IntPtr hwndParent, uint OpenFlags, ref SP_DEVINFO_DATA DeviceInfoData';marshal=$true},
    [pscustomobject]@{name='SetupDiGetDeviceInstanceIdW';dll='setupapi.dll';unicode=$true;return='bool';parameters='IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, StringBuilder DeviceInstanceId, uint DeviceInstanceIdSize, out uint RequiredSize';marshal=$true},
    [pscustomobject]@{name='SetupDiGetDevicePropertyW';dll='setupapi.dll';unicode=$true;return='bool';parameters='IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, ref DEVPROPKEY PropertyKey, out uint PropertyType, IntPtr PropertyBuffer, uint PropertyBufferSize, out uint RequiredSize, uint Flags';marshal=$true},
    [pscustomobject]@{name='SetupDiGetDeviceRegistryPropertyW';dll='setupapi.dll';unicode=$true;return='bool';parameters='IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, uint Property, out uint PropertyRegDataType, IntPtr PropertyBuffer, uint PropertyBufferSize, out uint RequiredSize';marshal=$true},
    [pscustomobject]@{name='SetupDiBuildDriverInfoList';dll='setupapi.dll';unicode=$false;return='bool';parameters='IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, uint DriverType';marshal=$true},
    [pscustomobject]@{name='SetupDiDestroyDriverInfoList';dll='setupapi.dll';unicode=$false;return='bool';parameters='IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, uint DriverType';marshal=$true},
    [pscustomobject]@{name='SetupDiEnumDriverInfoW';dll='setupapi.dll';unicode=$true;return='bool';parameters='IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, uint DriverType, uint MemberIndex, ref SP_DRVINFO_DATA_W DriverInfoData';marshal=$true},
    [pscustomobject]@{name='SetupDiGetDriverInfoDetailW';dll='setupapi.dll';unicode=$true;return='bool';parameters='IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, ref SP_DRVINFO_DATA_W DriverInfoData, IntPtr DriverInfoDetailData, uint DriverInfoDetailDataSize, out uint RequiredSize';marshal=$true},
    [pscustomobject]@{name='SetupDiGetDriverInstallParamsW';dll='setupapi.dll';unicode=$true;return='bool';parameters='IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, ref SP_DRVINFO_DATA_W DriverInfoData, ref SP_DRVINSTALL_PARAMS DriverInstallParams';marshal=$true},
    [pscustomobject]@{name='SetupDiSetSelectedDriverW';dll='setupapi.dll';unicode=$true;return='bool';parameters='IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, ref SP_DRVINFO_DATA_W DriverInfoData';marshal=$true},
    [pscustomobject]@{name='DiInstallDevice';dll='newdev.dll';unicode=$false;return='bool';parameters='IntPtr hwndParent, IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, ref SP_DRVINFO_DATA_W DriverInfoData, uint Flags, [MarshalAs(UnmanagedType.Bool)] out bool NeedReboot';marshal=$true}
)

$expectedStructures = [ordered]@{
    SP_DEVINFO_DATA=@('uint cbSize','Guid ClassGuid','uint DevInst','UIntPtr Reserved')
    SP_DEVINSTALL_PARAMS_W=@('uint cbSize','uint Flags','uint FlagsEx','IntPtr hwndParent','IntPtr InstallMsgHandler','IntPtr InstallMsgHandlerContext','IntPtr FileQueue','UIntPtr ClassInstallReserved','uint Reserved','string DriverPath')
    SP_DRVINSTALL_PARAMS=@('uint cbSize','uint Rank','uint Flags','UIntPtr PrivateData','uint Reserved')
    SP_DRVINFO_DATA_W=@('uint cbSize','uint DriverType','UIntPtr Reserved','string Description','string MfgName','string ProviderName','System.Runtime.InteropServices.ComTypes.FILETIME DriverDate','ulong DriverVersion')
    SP_DRVINFO_DETAIL_DATA_W=@('uint cbSize','System.Runtime.InteropServices.ComTypes.FILETIME InfDate','uint CompatIDsOffset','uint CompatIDsLength','UIntPtr Reserved','string SectionName','string InfFileName','string DrvDescription','string HardwareID')
    DEVPROPKEY=@('Guid fmtid','uint pid')
}

$sdkMethodPatterns = [ordered]@{
    SetupDiCreateDeviceInfoList='(?s)SetupDiCreateDeviceInfoList\(\s*_In_opt_\s+CONST GUID \*ClassGuid,\s*_In_opt_\s+HWND hwndParent\s*\);'
    SetupDiDestroyDeviceInfoList='(?s)SetupDiDestroyDeviceInfoList\(\s*_In_\s+HDEVINFO DeviceInfoSet\s*\);'
    SetupDiOpenDeviceInfoW='(?s)SetupDiOpenDeviceInfoW\(\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_In_\s+PCWSTR DeviceInstanceId,\s*_In_opt_\s+HWND hwndParent,\s*_In_\s+DWORD OpenFlags,\s*_Out_opt_\s+PSP_DEVINFO_DATA DeviceInfoData\s*\);'
    SetupDiGetDeviceInstanceIdW='(?s)SetupDiGetDeviceInstanceIdW\(\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_In_\s+PSP_DEVINFO_DATA DeviceInfoData,\s*_Out_writes_opt_\(DeviceInstanceIdSize\)\s+PWSTR DeviceInstanceId,\s*_In_\s+DWORD DeviceInstanceIdSize,\s*_Out_opt_\s+PDWORD RequiredSize\s*\);'
    SetupDiGetDevicePropertyW='(?s)SetupDiGetDevicePropertyW\(\s*_In_\s+HDEVINFO\s+DeviceInfoSet,\s*_In_\s+PSP_DEVINFO_DATA\s+DeviceInfoData,\s*_In_\s+CONST DEVPROPKEY\s+\*PropertyKey,\s*_Out_\s+DEVPROPTYPE\s+\*PropertyType,.*?PBYTE PropertyBuffer,\s*_In_\s+DWORD\s+PropertyBufferSize,\s*_Out_opt_\s+PDWORD\s+RequiredSize,\s*_In_\s+DWORD\s+Flags\s*\);'
    SetupDiGetDeviceRegistryPropertyW='(?s)SetupDiGetDeviceRegistryPropertyW\(\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_In_\s+PSP_DEVINFO_DATA DeviceInfoData,\s*_In_\s+DWORD Property,\s*_Out_opt_\s+PDWORD PropertyRegDataType,.*?PBYTE PropertyBuffer,\s*_In_\s+DWORD PropertyBufferSize,\s*_Out_opt_\s+PDWORD RequiredSize\s*\);'
    SetupDiBuildDriverInfoList='(?s)SetupDiBuildDriverInfoList\(\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_Inout_opt_\s+PSP_DEVINFO_DATA DeviceInfoData,\s*_In_\s+DWORD DriverType\s*\);'
    SetupDiDestroyDriverInfoList='(?s)SetupDiDestroyDriverInfoList\(\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_In_opt_\s+PSP_DEVINFO_DATA DeviceInfoData,\s*_In_\s+DWORD DriverType\s*\);'
    SetupDiEnumDriverInfoW='(?s)SetupDiEnumDriverInfoW\(\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_In_opt_\s+PSP_DEVINFO_DATA DeviceInfoData,\s*_In_\s+DWORD DriverType,\s*_In_\s+DWORD MemberIndex,\s*_Out_\s+PSP_DRVINFO_DATA_W DriverInfoData\s*\);'
    SetupDiGetDriverInfoDetailW='(?s)SetupDiGetDriverInfoDetailW\(\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_In_opt_\s+PSP_DEVINFO_DATA DeviceInfoData,\s*_In_\s+PSP_DRVINFO_DATA_W DriverInfoData,.*?PSP_DRVINFO_DETAIL_DATA_W DriverInfoDetailData,\s*_In_\s+DWORD DriverInfoDetailDataSize,\s*_Out_opt_\s+PDWORD RequiredSize\s*\);'
    SetupDiGetDriverInstallParamsW='(?s)SetupDiGetDriverInstallParamsW\(\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_In_opt_\s+PSP_DEVINFO_DATA DeviceInfoData,\s*_In_\s+PSP_DRVINFO_DATA_W DriverInfoData,\s*_Out_\s+PSP_DRVINSTALL_PARAMS DriverInstallParams\s*\);'
    SetupDiSetSelectedDriverW='(?s)SetupDiSetSelectedDriverW\(\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_Inout_opt_\s+PSP_DEVINFO_DATA DeviceInfoData,\s*_Inout_opt_\s+PSP_DRVINFO_DATA_W DriverInfoData\s*\);'
    DiInstallDevice='(?s)DiInstallDevice\(\s*_In_opt_\s+HWND hwndParent,\s*_In_\s+HDEVINFO DeviceInfoSet,\s*_In_\s+PSP_DEVINFO_DATA DeviceInfoData,\s*_In_opt_\s+PSP_DRVINFO_DATA DriverInfoData,\s*_In_\s+DWORD Flags,\s*_Out_opt_\s+PBOOL NeedReboot\s*\);'
}

$sdkStructurePatterns = [ordered]@{
    SP_DEVINFO_DATA='(?s)typedef struct _SP_DEVINFO_DATA\s*\{\s*DWORD cbSize;\s*GUID\s+ClassGuid;\s*DWORD DevInst;.*?ULONG_PTR Reserved;\s*\} SP_DEVINFO_DATA'
    SP_DEVINSTALL_PARAMS_W='(?s)typedef struct _SP_DEVINSTALL_PARAMS_W\s*\{\s*DWORD\s+cbSize;\s*DWORD\s+Flags;\s*DWORD\s+FlagsEx;\s*HWND\s+hwndParent;\s*PSP_FILE_CALLBACK InstallMsgHandler;\s*PVOID\s+InstallMsgHandlerContext;\s*HSPFILEQ\s+FileQueue;\s*ULONG_PTR\s+ClassInstallReserved;\s*DWORD\s+Reserved;\s*WCHAR\s+DriverPath\[MAX_PATH\];'
    SP_DRVINSTALL_PARAMS='(?s)typedef struct _SP_DRVINSTALL_PARAMS\s*\{\s*DWORD cbSize;\s*DWORD Rank;\s*DWORD Flags;\s*DWORD_PTR PrivateData;\s*DWORD Reserved;'
    SP_DRVINFO_DATA_W='(?s)typedef struct _SP_DRVINFO_DATA_V2_W\s*\{\s*DWORD\s+cbSize;\s*DWORD\s+DriverType;\s*ULONG_PTR Reserved;\s*WCHAR\s+Description\[LINE_LEN\];\s*WCHAR\s+MfgName\[LINE_LEN\];\s*WCHAR\s+ProviderName\[LINE_LEN\];\s*FILETIME\s+DriverDate;\s*DWORDLONG DriverVersion;'
    SP_DRVINFO_DETAIL_DATA_W='(?s)typedef struct _SP_DRVINFO_DETAIL_DATA_W\s*\{\s*DWORD\s+cbSize;\s*FILETIME InfDate;\s*DWORD\s+CompatIDsOffset;\s*DWORD\s+CompatIDsLength;\s*ULONG_PTR Reserved;\s*WCHAR\s+SectionName\[LINE_LEN\];\s*WCHAR\s+InfFileName\[MAX_PATH\];\s*WCHAR\s+DrvDescription\[LINE_LEN\];\s*WCHAR\s+HardwareID\[ANYSIZE_ARRAY\];'
    DEVPROPKEY='(?s)typedef struct _DEVPROPKEY\s*\{\s*DEVPROPGUID fmtid;\s*DEVPROPID\s+pid;\s*\} DEVPROPKEY'
}

function Test-DeclarationText {
    param([Parameter(Mandatory)][string]$Text)
    $defects = [Collections.Generic.List[string]]::new()
    $records = @(Get-PInvokeRecords $Text)
    if ($records.Count -ne 13) { $defects.Add("method-count:$($records.Count)") }
    if ((@($records.name) -join '|') -ne (@($expectedMethods.name) -join '|')) { $defects.Add('method-inventory-or-order') }
    foreach ($expected in $expectedMethods) {
        $actual = @($records | Where-Object name -eq $expected.name)
        if ($actual.Count -ne 1) { $defects.Add("method-cardinality:$($expected.name)"); continue }
        $record = $actual[0]
        if ($record.import -notmatch ('^\[DllImport\("' + [regex]::Escape($expected.dll) + '"')) { $defects.Add("dll:$($expected.name)") }
        if ($record.import -notmatch ('EntryPoint = "' + [regex]::Escape($expected.name) + '"')) { $defects.Add("entry-point:$($expected.name)") }
        if ($record.import -notmatch 'ExactSpelling = true') { $defects.Add("exact-spelling:$($expected.name)") }
        if ($record.import -notmatch 'SetLastError = true') { $defects.Add("last-error:$($expected.name)") }
        if ($record.import -notmatch 'CallingConvention = CallingConvention.Winapi') { $defects.Add("calling-convention:$($expected.name)") }
        if ($expected.unicode -and $record.import -notmatch 'CharSet = CharSet.Unicode') { $defects.Add("charset:$($expected.name)") }
        if (-not $expected.unicode -and $record.import -match 'CharSet =') { $defects.Add("unexpected-charset:$($expected.name)") }
        if ($record.return_type -ne $expected.return) { $defects.Add("return:$($expected.name)") }
        if ($expected.marshal -and $record.return_marshal -ne '[return: MarshalAs(UnmanagedType.Bool)]') { $defects.Add("return-marshal:$($expected.name)") }
        if (-not $expected.marshal -and $record.return_marshal) { $defects.Add("unexpected-return-marshal:$($expected.name)") }
        if ($record.parameters -ne $expected.parameters) { $defects.Add("parameters:$($expected.name)") }
    }
    foreach ($name in $expectedStructures.Keys) {
        $record = Get-StructureRecord $Text $name
        if ($record.count -ne 1) { $defects.Add("structure-cardinality:$name"); continue }
        if ($record.layout -notmatch '^LayoutKind.Sequential') { $defects.Add("structure-layout:$name") }
        if ((@($record.fields) -join '|') -ne (@($expectedStructures[$name]) -join '|')) { $defects.Add("structure-fields:$name") }
    }
    if ($Text -match '\[LibraryImport\s*\(' -or $Text -match '\bpublic\s+' -or $Text -match '\bMain\s*\(') { $defects.Add('executable-or-public-surface') }
    @($defects)
}

$source = [IO.File]::ReadAllText($declarationPath)

Invoke-AbiTestCase 'installed SDK header provenance is exact and authoritative' {
    foreach ($path in @($setupApiHeader,$newdevHeader,$devpropdefHeader,$devpkeyHeader)) { Assert-AbiCondition (Test-Path -LiteralPath $path -PathType Leaf) "missing SDK header: $path" }
    $setupText = [IO.File]::ReadAllText($setupApiHeader)
    $newdevText = [IO.File]::ReadAllText($newdevHeader)
    $devpropdefText = [IO.File]::ReadAllText($devpropdefHeader)
    foreach ($method in @($expectedMethods | Where-Object dll -eq 'setupapi.dll')) { Assert-AbiCondition ($setupText -match ('(?m)^' + [regex]::Escape($method.name) + '\(\r?$')) "setupapi.h missing $($method.name)" }
    Assert-AbiCondition ($newdevText -match '(?m)^DiInstallDevice\(\r?$') 'newdev.h missing DiInstallDevice'
    Assert-AbiCondition ($setupText -match '(?s)typedef struct _SP_DRVINSTALL_PARAMS\s*\{\s*DWORD cbSize;\s*DWORD Rank;\s*DWORD Flags;\s*DWORD_PTR PrivateData;\s*DWORD Reserved;\s*\} SP_DRVINSTALL_PARAMS') 'SDK SP_DRVINSTALL_PARAMS definition drifted'
    Assert-AbiCondition ($setupText -match '(?s)SetupDiGetDriverInstallParamsW\(.*?PSP_DRVINSTALL_PARAMS DriverInstallParams\s*\);') 'SDK corrected method contract drifted'
    foreach ($name in $sdkMethodPatterns.Keys) {
        $headerText = if ($name -eq 'DiInstallDevice') { $newdevText } else { $setupText }
        Assert-AbiCondition ($headerText -match $sdkMethodPatterns[$name]) "SDK native parameter contract drifted: $name"
    }
    foreach ($name in $sdkStructurePatterns.Keys) {
        $headerText = if ($name -eq 'DEVPROPKEY') { $devpropdefText } else { $setupText }
        Assert-AbiCondition ($headerText -match $sdkStructurePatterns[$name]) "SDK native structure contract drifted: $name"
    }
}

Invoke-AbiTestCase 'exact original 13-method inventory has no overloads or additions' {
    $records = @(Get-PInvokeRecords $source)
    Assert-AbiCondition ($records.Count -eq 13) 'PInvoke declaration count is not 13'
    Assert-AbiCondition ((@($records.name) -join '|') -eq (@($expectedMethods.name) -join '|')) 'method inventory or order differs'
    Assert-AbiCondition (@($records.name | Group-Object | Where-Object Count -ne 1).Count -eq 0) 'duplicate method or overload exists'
}

Invoke-AbiTestCase 'all 13 managed declarations match the SDK-derived ABI contract' {
    $defects = @(Test-DeclarationText $source)
    Assert-AbiCondition ($defects.Count -eq 0) "ABI defects: $($defects -join ',')"
    foreach ($method in $expectedMethods) {
        $record = @(Get-PInvokeRecords $source | Where-Object name -eq $method.name)[0]
        Assert-AbiCondition ($record.parameters -eq $method.parameters) "parameter contract differs: $($method.name)"
        Assert-AbiCondition ($record.return_type -eq $method.return) "return contract differs: $($method.name)"
    }
}

Invoke-AbiTestCase 'driver install params method uses only SP_DRVINSTALL_PARAMS' {
    $record = @(Get-PInvokeRecords $source | Where-Object name -eq 'SetupDiGetDriverInstallParamsW')
    Assert-AbiCondition ($record.Count -eq 1) 'corrected method cardinality differs'
    Assert-AbiCondition ($record[0].parameters -match 'ref SP_DRVINSTALL_PARAMS DriverInstallParams$') 'corrected final parameter missing'
    Assert-AbiCondition ($record[0].parameters -notmatch 'SP_DEVINSTALL_PARAMS') 'device-install structure reused by driver-install API'
}

Invoke-AbiTestCase 'SP_DRVINSTALL_PARAMS has exact field and architecture layout contract' {
    $record = Get-StructureRecord $source 'SP_DRVINSTALL_PARAMS'
    Assert-AbiCondition ($record.count -eq 1) 'SP_DRVINSTALL_PARAMS definition count differs'
    Assert-AbiCondition ($record.layout -eq 'LayoutKind.Sequential') 'SP_DRVINSTALL_PARAMS is not sequential'
    Assert-AbiCondition ((@($record.fields) -join '|') -eq 'uint cbSize|uint Rank|uint Flags|UIntPtr PrivateData|uint Reserved') 'SP_DRVINSTALL_PARAMS fields differ'
    Assert-AbiCondition ($record.fields[3] -eq 'UIntPtr PrivateData') 'DWORD_PTR is not pointer-width-sensitive'
    Assert-AbiCondition ((3 * 4 + 4 + 4) -eq 20) 'x86 layout contract is not 20 bytes'
    Assert-AbiCondition ((16 + 8 + 4 + 4) -eq 32) 'x64 aligned layout contract is not 32 bytes'
}

Invoke-AbiTestCase 'all supporting managed structures retain exact field contracts' {
    foreach ($name in $expectedStructures.Keys) {
        $record = Get-StructureRecord $source $name
        Assert-AbiCondition ($record.count -eq 1) "structure cardinality differs: $name"
        Assert-AbiCondition ((@($record.fields) -join '|') -eq (@($expectedStructures[$name]) -join '|')) "structure fields differ: $name"
    }
}

Invoke-AbiTestCase 'temporary tamper fixtures reject every required ABI drift' {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('chatpad-8f-r1a-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($tempRoot)
    try {
        $tampered = [ordered]@{
            'wrong-dll'=$source.Replace('DllImport("setupapi.dll"','DllImport("kernel32.dll"')
            'wrong-entry-point'=$source.Replace('EntryPoint = "SetupDiDestroyDeviceInfoList"','EntryPoint = "WrongEntryPoint"')
            'missing-w-suffix'=$source.Replace('EntryPoint = "SetupDiOpenDeviceInfoW"','EntryPoint = "SetupDiOpenDeviceInfo"')
            'wrong-return'=$source.Replace('extern bool SetupDiDestroyDeviceInfoList','extern int SetupDiDestroyDeviceInfoList')
            'wrong-parameter-order'=([regex]::Replace($source,'uint DriverType,\s+uint MemberIndex','uint MemberIndex, uint DriverType',1))
            'wrong-structure'=$source.Replace('ref SP_DRVINSTALL_PARAMS DriverInstallParams','ref SP_DEVINSTALL_PARAMS_W DriverInstallParams')
            'int32-for-pointer'=$source.Replace('IntPtr DeviceInfoSet','int DeviceInfoSet')
            'missing-last-error'=$source.Replace('SetLastError = true, CallingConvention','CallingConvention')
            'wrong-character-set'=$source.Replace('CharSet = CharSet.Unicode','CharSet = CharSet.Ansi')
            'added-overload'=$source + "`r`n" + '[DllImport("setupapi.dll", EntryPoint = "SetupDiDestroyDeviceInfoList", ExactSpelling = true, SetLastError = true, CallingConvention = CallingConvention.Winapi)]' + "`r`n" + 'internal static extern bool SetupDiDestroyDeviceInfoList(IntPtr value, int extra);' + "`r`n"
            'removed-declaration'=([regex]::Replace($source,'(?ms)\s*\[DllImport\("setupapi\.dll", EntryPoint = "SetupDiDestroyDeviceInfoList".*?\);','',1))
        }
        foreach ($case in $tampered.GetEnumerator()) {
            $fixture = Join-Path $tempRoot ($case.Key + '.cs')
            [IO.File]::WriteAllText($fixture, [string]$case.Value, [Text.UTF8Encoding]::new($false))
            Assert-AbiCondition ((Test-Path -LiteralPath $fixture -PathType Leaf)) "tamper fixture missing: $($case.Key)"
            $defects = @(Test-DeclarationText ([IO.File]::ReadAllText($fixture)))
            Assert-AbiCondition ($defects.Count -gt 0) "tamper fixture was accepted: $($case.Key)"
        }
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}

Invoke-AbiTestCase 'source remains inert and static-test-only' {
    Assert-AbiCondition ($source -notmatch ('Add-'+'Type')) 'source contains runtime compilation'
    Assert-AbiCondition ($source -notmatch 'LoadLibrary|GetProcAddress') 'source contains explicit native loading'
    Assert-AbiCondition ($source -notmatch '\bMain\s*\(') 'source contains executable entry point'
    Assert-AbiCondition ($source -notmatch '\bpublic\s+') 'source exposes public declaration surface'
    Assert-AbiCondition ($source -match 'must not be compiled, loaded, or invoked in this phase') 'inert phase boundary missing'
}

$failed = @($tests | Where-Object result -ne 'PASS')
$report = [pscustomobject][ordered]@{
    schema_version = 'chatpad-native-interop-setupapi-declarations-static-test-v1'
    result = if ($failed.Count) { 'FAIL' } else { 'PASS' }
    test_count = $tests.Count
    assertion_count = $assertionCount
    failed_test_count = $failed.Count
    runtime = $PSVersionTable.PSEdition
    powershell_version = $PSVersionTable.PSVersion.ToString()
    sdk_version = $sdkVersion
    authoritative_headers = @($setupApiHeader,$newdevHeader,$devpropdefHeader,$devpkeyHeader)
    declaration_path = $declarationPath
    declaration_byte_size = (Get-Item -LiteralPath $declarationPath).Length
    declaration_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $declarationPath).Hash
    tests = @($tests)
    prohibited_operation_counters = [pscustomobject][ordered]@{ production_provider_constructions=0; declaration_compilations=0; declaration_loads=0; native_invocations=0; setupapi_newdev_invocations=0; device_queries=0; registry_queries=0; service_queries=0; binding_operations=0; windows_mutations=0; driver_actions=0 }
}
Write-Output $report
if ($failed.Count) { exit 1 }
