[CmdletBinding(PositionalBinding = $false)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$supplementalPath = Join-Path $PSScriptRoot 'ExactInstance\NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.LiveApplyExtensions.cs'
$originalPath = Join-Path $PSScriptRoot 'ExactInstance\NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs'
$loaderPath = Join-Path $PSScriptRoot 'ExactInstance\ChatpadNativeInteropDeclarationLoader.psm1'
$sdkVersion = '10.0.26100.0'
$sdkRoot = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\Include\$sdkVersion"
$setupApiHeader = Join-Path $sdkRoot 'um\setupapi.h'
$devpropdefHeader = Join-Path $sdkRoot 'shared\devpropdef.h'
$devpkeyHeader = Join-Path $sdkRoot 'shared\devpkey.h'
$tests = [Collections.Generic.List[object]]::new()
$assertionCount = 0

function Assert-LiveApplyCondition {
    param([Parameter(Mandatory)][bool] $Condition, [Parameter(Mandatory)][string] $Message)
    $script:assertionCount++
    if (-not $Condition) { throw $Message }
}

function Invoke-LiveApplyTestCase {
    param([Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][scriptblock] $Body)
    try {
        & $Body
        $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'PASS' })
    }
    catch {
        $tests.Add([pscustomobject][ordered]@{ name = $Name; result = 'FAIL'; detail = $_.Exception.Message })
    }
}

function ConvertTo-LiveApplyNormalizedWhitespace {
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Text)
    [regex]::Replace($Text.Trim(), '\s+', ' ')
}

function Get-LiveApplyPInvokeRecords {
    param([Parameter(Mandatory)][string] $Text)
    $pattern = '(?ms)(?<import>\[DllImport\("[^"]+"[^\]]*\)\])\s*(?<marshal>\[return:\s*MarshalAs\(UnmanagedType\.Bool\)\]\s*)?internal\s+static\s+extern\s+(?<return>\w+)\s+(?<name>\w+)\s*\((?<parameters>.*?)\);'
    @([regex]::Matches($Text, $pattern) | ForEach-Object {
        [pscustomobject]@{
            import = ConvertTo-LiveApplyNormalizedWhitespace $_.Groups['import'].Value
            marshal = ConvertTo-LiveApplyNormalizedWhitespace $_.Groups['marshal'].Value
            return_type = $_.Groups['return'].Value
            name = $_.Groups['name'].Value
            parameters = ConvertTo-LiveApplyNormalizedWhitespace $_.Groups['parameters'].Value
        }
    })
}

function Get-LiveApplyConstantRecords {
    param([Parameter(Mandatory)][string] $Text)
    @([regex]::Matches($Text, '(?m)^\s*internal\s+const\s+uint\s+(?<name>\w+)\s*=\s*(?<value>0x[0-9A-Fa-f]+);') | ForEach-Object {
        [pscustomobject]@{ name = $_.Groups['name'].Value; value = $_.Groups['value'].Value.ToUpperInvariant() }
    })
}

function Test-LiveApplySupplementalText {
    param([Parameter(Mandatory)][string] $Text)
    $defects = [Collections.Generic.List[string]]::new()
    $records = @(Get-LiveApplyPInvokeRecords $Text)
    $expectedMethods = [ordered]@{
        SetupDiGetDeviceInstallParamsW = 'IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, ref SP_DEVINSTALL_PARAMS_W DeviceInstallParams'
        SetupDiSetDeviceInstallParamsW = 'IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, ref SP_DEVINSTALL_PARAMS_W DeviceInstallParams'
    }
    if ($records.Count -ne 2) { $defects.Add('pinvoke-count') }
    if ((@($records.name) -join '|') -cne (@($expectedMethods.Keys) -join '|')) { $defects.Add('pinvoke-inventory') }
    foreach ($name in $expectedMethods.Keys) {
        $record = @($records | Where-Object name -ceq $name)
        if ($record.Count -ne 1) { $defects.Add("pinvoke-cardinality:$name"); continue }
        if ($record[0].import -notmatch '^\[DllImport\("setupapi\.dll"') { $defects.Add("dll:$name") }
        if ($record[0].import -notmatch ('EntryPoint = "' + $name + '"')) { $defects.Add("entry:$name") }
        foreach ($attribute in @('ExactSpelling = true','CharSet = CharSet.Unicode','SetLastError = true','CallingConvention = CallingConvention.Winapi')) {
            if ($record[0].import -notmatch [regex]::Escape($attribute)) { $defects.Add("attribute:${name}:$attribute") }
        }
        if ($record[0].marshal -cne '[return: MarshalAs(UnmanagedType.Bool)]') { $defects.Add("bool-marshal:$name") }
        if ($record[0].return_type -cne 'bool') { $defects.Add("return:$name") }
        if ($record[0].parameters -cne $expectedMethods[$name]) { $defects.Add("parameters:$name") }
    }

    $expectedConstants = [ordered]@{
        SPDRP_DEVICEDESC='0X00000000'; SPDRP_HARDWAREID='0X00000001'; SPDRP_COMPATIBLEIDS='0X00000002'; SPDRP_SERVICE='0X00000004'
        SPDRP_CLASSGUID='0X00000008'; SPDRP_DRIVER='0X00000009'; SPDRP_MFG='0X0000000B'; SPDRP_FRIENDLYNAME='0X0000000C'
        DI_NEEDRESTART='0X00000080'; DI_NEEDREBOOT='0X00000100'; DI_ENUMSINGLEINF='0X00010000'; DI_FLAGSEX_SEARCH_PUBLISHED_INFS='0X80000000'
    }
    $constants = @(Get-LiveApplyConstantRecords $Text)
    if ((@($constants.name) -join '|') -cne (@($expectedConstants.Keys) -join '|')) { $defects.Add('constant-inventory') }
    foreach ($name in $expectedConstants.Keys) {
        $record = @($constants | Where-Object name -ceq $name)
        if ($record.Count -ne 1 -or $record[0].value -cne $expectedConstants[$name]) { $defects.Add("constant:$name") }
    }

    if ($Text -notmatch '(?m)^namespace Chatpad\.ExactInstance\.NativeInterop$') { $defects.Add('namespace') }
    if ([regex]::Matches($Text, '(?m)^\s*internal static class SetupApiNewdevLiveApplyExtensions$').Count -ne 1) { $defects.Add('type') }
    if ($Text -notmatch '(?s)internal static readonly DEVPROPKEY DEVPKEY_Device_ContainerId = new DEVPROPKEY\s*\{\s*fmtid = new Guid\("8c7ed206-3f8a-4827-b3ab-ae9e1faefc6c"\),\s*pid = 2\s*\};') { $defects.Add('container-key') }
    foreach ($name in @('SP_DEVINFO_DATA','SP_DEVINSTALL_PARAMS_W','SP_DRVINSTALL_PARAMS','SP_DRVINFO_DATA_W','SP_DRVINFO_DETAIL_DATA_W','DEVPROPKEY')) {
        if ($Text -match ('(?m)\b(?:class|struct)\s+' + [regex]::Escape($name) + '\b')) { $defects.Add("duplicated-type:$name") }
    }
    foreach ($token in @('Windows SDK 10.0.26100.0','um/setupapi.h','shared/devpropdef.h','shared/devpkey.h','WINSETUPAPI BOOL WINAPI','PSP_DEVINFO_DATA','PSP_DEVINSTALL_PARAMS_W','DEVPROP_TYPE_GUID','DWORD registry-property','Unicode W entry','Winapi calling convention','last-error state','pointer semantics')) {
        if (-not $Text.Contains($token)) { $defects.Add("provenance:$token") }
    }
    if ($Text -match '\bMain\s*\(' -or $Text -match 'static\s+SetupApiNewdevLiveApplyExtensions\s*\(') { $defects.Add('executable-initializer') }
    if ($Text -match '(?i)\bTODO\b|\bplaceholder\b|USB\\VID_|HID\\VID_|oem\d+\.inf|\.cat\b') { $defects.Add('placeholder-or-package-identity') }
    if ($Text -match '\bSetupDi(?:Get|Set)DeviceInstallParamsW\s*\([^;]*\)\s*\{') { $defects.Add('native-call-body') }
    @($defects)
}

function Test-LiveApplyLoaderText {
    param([Parameter(Mandatory)][string] $Text)
    $defects = [Collections.Generic.List[string]]::new()
    $required = @(
        "NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs"
        "NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.LiveApplyExtensions.cs"
        'E55E6E34BBB4DB40904F065292F23A76D48BE809D18E7EB76E0C3A7ECCA786F2'
        'B4D24BF374B391A36B4A3513B117A2FF50F8BC3D8795248808086AC984E874D9'
        'PREEXISTING_UNTRUSTED_DECLARATION_TYPE_STATE'
        'TASK 8H authorization validation'
        'atomic TASK 8H authorization consumption'
        'GetFullPath'
        'ReparsePoint'
        'Add-Type -TypeDefinition'
        'Export-ModuleMember -Function @()'
        'EXACT_PROCESS_LOCAL_LOAD_RECORD'
    )
    foreach ($token in $required) { if (-not $Text.Contains($token)) { $defects.Add("required:$token") } }
    foreach ($forbidden in @('Get-ChildItem','-Recurse','-OutputAssembly','-ReferencedAssemblies','Assembly.LoadFrom','ScriptBlock','Delegate','Callback','Get-PnpDevice','Get-CimInstance','Get-WmiObject','pnputil','devcon','Start-Process')) {
        if ($Text -match [regex]::Escape($forbidden)) { $defects.Add("forbidden:$forbidden") }
    }
    if ([regex]::Matches($Text, [regex]::Escape($script:SupplementalHashForValidation)).Count -ne 2) { $defects.Add('supplemental-hash') }
    if ([regex]::Matches($Text, "NativeInterop\\Chatpad\.NativeInterop\.SetupApiNewdev\.(?:Declarations|LiveApplyExtensions)\.cs").Count -ne 2) { $defects.Add('fixed-source-inventory') }
    if ([regex]::Matches($Text, '(?m)^\$script:\w+RelativeName\s*=').Count -ne 2) { $defects.Add('relative-name-inventory') }
    if ([regex]::Matches($Text, '\bAdd-Type\b').Count -ne 1) { $defects.Add('add-type-site-count') }
    if ($Text -notmatch '(?s)function Invoke-ChatpadNativeInteropDeclarationLoad\s*\{\s*\[CmdletBinding\(\)\]\s*param\(\)') { $defects.Add('loading-operation-parameters') }
    if ($Text -notmatch '(?s)function Invoke-ChatpadNativeInteropDeclarationLoad.*?Get-ChatpadDeclarationFileState.*?Find-ChatpadExpectedDeclarationTypes.*?Add-Type.*?Assert-ChatpadLoadedDeclarationInventory') { $defects.Add('load-order') }
    @($defects)
}

function Get-LiveApplySha256 {
    param([Parameter(Mandatory)][byte[]] $Bytes)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '') }
    finally { $algorithm.Dispose() }
}

function Get-LiveApplyFileIdentity {
    param([Parameter(Mandatory)][string] $LiteralName)
    $bytes = [IO.File]::ReadAllBytes($LiteralName)
    $utf8 = New-Object Text.UTF8Encoding($false, $true)
    $text = $utf8.GetString($bytes)
    $canonical = $utf8.GetBytes($text.Replace("`r`n", "`n").Replace("`r", "`n"))
    [pscustomobject]@{
        raw_size = $bytes.LongLength
        raw_sha256 = Get-LiveApplySha256 $bytes
        canonical_lf_size = $canonical.LongLength
        canonical_lf_sha256 = Get-LiveApplySha256 $canonical
    }
}

$supplementalText = [IO.File]::ReadAllText($supplementalPath)
$originalText = [IO.File]::ReadAllText($originalPath)
$loaderText = [IO.File]::ReadAllText($loaderPath)
$supplementalIdentity = Get-LiveApplyFileIdentity $supplementalPath
$originalIdentity = Get-LiveApplyFileIdentity $originalPath
$script:SupplementalHashForValidation = $supplementalIdentity.raw_sha256

Invoke-LiveApplyTestCase 'exact tracked paths and accepted source identities are fixed' {
    foreach ($path in @($originalPath,$supplementalPath,$loaderPath)) { Assert-LiveApplyCondition (Test-Path -LiteralPath $path -PathType Leaf) "missing path: $path" }
    Assert-LiveApplyCondition ($originalIdentity.raw_size -eq 10238) 'original raw size drifted'
    Assert-LiveApplyCondition ($originalIdentity.raw_sha256 -ceq 'E55E6E34BBB4DB40904F065292F23A76D48BE809D18E7EB76E0C3A7ECCA786F2') 'original raw hash drifted'
    Assert-LiveApplyCondition ($originalIdentity.canonical_lf_size -eq 10034) 'original canonical size drifted'
    Assert-LiveApplyCondition ($originalIdentity.canonical_lf_sha256 -ceq 'B4D24BF374B391A36B4A3513B117A2FF50F8BC3D8795248808086AC984E874D9') 'original canonical hash drifted'
}

Invoke-LiveApplyTestCase 'installed SDK headers prove every supplemental native value' {
    foreach ($path in @($setupApiHeader,$devpropdefHeader,$devpkeyHeader)) { Assert-LiveApplyCondition (Test-Path -LiteralPath $path -PathType Leaf) "missing SDK header: $path" }
    $setup = [IO.File]::ReadAllText($setupApiHeader)
    $devpropdef = [IO.File]::ReadAllText($devpropdefHeader)
    $devpkey = [IO.File]::ReadAllText($devpkeyHeader)
    Assert-LiveApplyCondition ($setup -match '(?s)BOOL\s+WINAPI\s+SetupDiGetDeviceInstallParamsW\(\s*_In_ HDEVINFO DeviceInfoSet,\s*_In_opt_ PSP_DEVINFO_DATA DeviceInfoData,\s*_Out_ PSP_DEVINSTALL_PARAMS_W DeviceInstallParams\s*\);') 'SDK get signature drifted'
    Assert-LiveApplyCondition ($setup -match '(?s)BOOL\s+WINAPI\s+SetupDiSetDeviceInstallParamsW\(\s*_In_ HDEVINFO DeviceInfoSet,\s*_In_opt_ PSP_DEVINFO_DATA DeviceInfoData,\s*_In_ PSP_DEVINSTALL_PARAMS_W DeviceInstallParams\s*\);') 'SDK set signature drifted'
    Assert-LiveApplyCondition ($devpropdef -match '(?s)typedef struct _DEVPROPKEY\s*\{\s*DEVPROPGUID fmtid;\s*DEVPROPID\s+pid;\s*\} DEVPROPKEY') 'SDK DEVPROPKEY drifted'
    Assert-LiveApplyCondition ($devpkey -match 'DEFINE_DEVPROPKEY\(DEVPKEY_Device_ContainerId,\s*0x8c7ed206, 0x3f8a, 0x4827, 0xb3, 0xab, 0xae, 0x9e, 0x1f, 0xae, 0xfc, 0x6c, 2\)') 'SDK ContainerId key drifted'
    foreach ($pair in @('SPDRP_DEVICEDESC:0x00000000','SPDRP_HARDWAREID:0x00000001','SPDRP_COMPATIBLEIDS:0x00000002','SPDRP_SERVICE:0x00000004','SPDRP_CLASSGUID:0x00000008','SPDRP_DRIVER:0x00000009','SPDRP_MFG:0x0000000B','SPDRP_FRIENDLYNAME:0x0000000C','DI_NEEDRESTART:0x00000080','DI_NEEDREBOOT:0x00000100','DI_ENUMSINGLEINF:0x00010000','DI_FLAGSEX_SEARCH_PUBLISHED_INFS:0x80000000')) {
        $parts = $pair.Split(':')
        Assert-LiveApplyCondition ($setup -match ('(?m)^#define\s+' + $parts[0] + '\s+\(?' + $parts[1] + 'L?\)?')) "SDK constant drifted: $($parts[0])"
    }
}

Invoke-LiveApplyTestCase 'supplemental source has the exact inert contract' {
    $defects = @(Test-LiveApplySupplementalText $supplementalText)
    Assert-LiveApplyCondition ($defects.Count -eq 0) "supplemental defects: $($defects -join ',')"
    Assert-LiveApplyCondition ($supplementalIdentity.raw_size -gt 0) 'supplemental source is empty'
    Assert-LiveApplyCondition ($supplementalIdentity.raw_sha256 -ceq $supplementalIdentity.canonical_lf_sha256) 'supplemental line endings are not canonical LF'
    Assert-LiveApplyCondition ($originalText -notmatch 'SetupDiSetDeviceInstallParamsW') 'supplemental API duplicated in original source'
}

Invoke-LiveApplyTestCase 'loader parses with a zero-export no-parameter loading surface' {
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($loaderPath, [ref]$tokens, [ref]$errors)
    Assert-LiveApplyCondition (@($errors).Count -eq 0) "loader parse errors: $(@($errors | ForEach-Object Message) -join ';')"
    $functionAsts = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true))
    $names = @($functionAsts.Name)
    $expected = @('Get-ChatpadSha256Hex','Get-ChatpadDeclarationFileState','Get-ChatpadNamedMatches','Assert-ChatpadExactNames','Assert-ChatpadDeclarationSourceInventory','Find-ChatpadExpectedDeclarationTypes','Assert-ChatpadLoadedDeclarationInventory','Invoke-ChatpadNativeInteropDeclarationLoad')
    Assert-LiveApplyCondition ((@($names) -join '|') -ceq ($expected -join '|')) 'private function inventory drifted'
    $loadFunctionAst = @($functionAsts | Where-Object Name -eq 'Invoke-ChatpadNativeInteropDeclarationLoad')[0]
    Assert-LiveApplyCondition (@($loadFunctionAst.Body.ParamBlock.Parameters).Count -eq 0) 'loading operation accepts parameters'
    $defects = @(Test-LiveApplyLoaderText $loaderText)
    Assert-LiveApplyCondition ($defects.Count -eq 0) "loader defects: $($defects -join ',')"
}

Invoke-LiveApplyTestCase 'loader import performs zero compilation loading invocation query or mutation' {
    $expectedTypes = @('Chatpad.ExactInstance.NativeInterop.SetupApiNewdevDeclarations','Chatpad.ExactInstance.NativeInterop.SetupApiNewdevLiveApplyExtensions')
    $beforeTypes = @([AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { foreach ($name in $expectedTypes) { if ($_.GetType($name, $false, $false)) { $name } } })
    Assert-LiveApplyCondition ($beforeTypes.Count -eq 0) 'declaration type was already loaded before import'
    $global:ChatpadLiveApplyAddTypeCalls = 0
    function global:Add-Type { $global:ChatpadLiveApplyAddTypeCalls++; throw 'TEST_BLOCKED_ADD_TYPE_INVOCATION' }
    try {
        Import-Module $loaderPath -Force -ErrorAction Stop
        $module = Get-Module ChatpadNativeInteropDeclarationLoader
        Assert-LiveApplyCondition ($null -ne $module) 'loader module did not import'
        Assert-LiveApplyCondition ($module.ExportedFunctions.Count -eq 0) 'loader exported a function'
        Assert-LiveApplyCondition ($global:ChatpadLiveApplyAddTypeCalls -eq 0) 'import executed Add-Type'
        $afterTypes = @([AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { foreach ($name in $expectedTypes) { if ($_.GetType($name, $false, $false)) { $name } } })
        Assert-LiveApplyCondition ($afterTypes.Count -eq 0) 'import loaded declaration types'
        $loadRecord = & $module { Get-Variable DeclarationLoadRecord -ValueOnly }
        Assert-LiveApplyCondition ($null -eq $loadRecord) 'import created a load record'
    }
    finally {
        Remove-Item Function:\global:Add-Type -Force -ErrorAction SilentlyContinue
        Remove-Variable ChatpadLiveApplyAddTypeCalls -Scope Global -Force -ErrorAction SilentlyContinue
        Remove-Module ChatpadNativeInteropDeclarationLoader -Force -ErrorAction SilentlyContinue
    }
}

Invoke-LiveApplyTestCase 'temporary source tampering rejects every required contract drift' {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('chatpad-8i-p1a-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($tempRoot)
    try {
        $cases = [ordered]@{
            'wrong-namespace'=$supplementalText.Replace('namespace Chatpad.ExactInstance.NativeInterop','namespace Wrong.Namespace')
            'wrong-type'=$supplementalText.Replace('SetupApiNewdevLiveApplyExtensions','WrongLiveApplyExtensions')
            'missing-api'=([regex]::Replace($supplementalText,'(?ms)\s*\[DllImport\("setupapi\.dll", EntryPoint = "SetupDiSetDeviceInstallParamsW".*?\);','',1))
            'added-api'=$supplementalText.Replace("    }`n}", "        [DllImport(`"setupapi.dll`")] internal static extern bool AddedApi();`n    }`n}")
            'signature-drift'=$supplementalText.Replace('ref SP_DEVINSTALL_PARAMS_W DeviceInstallParams);','out SP_DEVINSTALL_PARAMS_W DeviceInstallParams);')
            'wrong-container-key'=$supplementalText.Replace('8c7ed206-3f8a-4827-b3ab-ae9e1faefc6c','00000000-0000-0000-0000-000000000000')
            'wrong-spdrp-value'=$supplementalText.Replace('SPDRP_HARDWAREID = 0x00000001','SPDRP_HARDWAREID = 0x00000002')
            'wrong-di-flag'=$supplementalText.Replace('DI_ENUMSINGLEINF = 0x00010000','DI_ENUMSINGLEINF = 0x00020000')
            'missing-provenance'=$supplementalText.Replace('Windows SDK 10.0.26100.0','Windows SDK')
            'wrong-header'=$supplementalText.Replace('um/setupapi.h','um/wrong.h')
            'wrong-native-type'=$supplementalText.Replace('WINSETUPAPI BOOL WINAPI','WINSETUPAPI DWORD WINAPI')
            'wrong-managed-type'=$supplementalText.Replace('IntPtr DeviceInfoSet','int DeviceInfoSet')
            'wrong-unicode'=$supplementalText.Replace('CharSet = CharSet.Unicode','CharSet = CharSet.Ansi')
            'wrong-last-error'=$supplementalText.Replace('SetLastError = true','SetLastError = false')
            'wrong-parameter-order'=([regex]::Replace($supplementalText,'IntPtr DeviceInfoSet,\s+ref SP_DEVINFO_DATA DeviceInfoData,','ref SP_DEVINFO_DATA DeviceInfoData, IntPtr DeviceInfoSet,',1))
        }
        foreach ($case in $cases.GetEnumerator()) {
            $fixture = Join-Path $tempRoot ($case.Key + '.cs')
            [IO.File]::WriteAllText($fixture, [string]$case.Value, [Text.UTF8Encoding]::new($false))
            Assert-LiveApplyCondition (@(Test-LiveApplySupplementalText ([IO.File]::ReadAllText($fixture))).Count -gt 0) "tamper accepted: $($case.Key)"
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}

Invoke-LiveApplyTestCase 'temporary loader tampering rejects inventory identity and trust drift' {
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('chatpad-8i-loader-' + [Guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($tempRoot)
    try {
        $cases = [ordered]@{
            'missing-original'=$loaderText.Replace("'NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs'","'NativeInterop\Missing.cs'")
            'missing-supplemental'=$loaderText.Replace("'NativeInterop\Chatpad.NativeInterop.SetupApiNewdev.LiveApplyExtensions.cs'","'NativeInterop\Missing.cs'")
            'extra-source'=$loaderText.Replace('$script:SupplementalRelativeName =', "`$script:ExtraRelativeName = 'NativeInterop\Extra.cs'`n`$script:SupplementalRelativeName =")
            'wrong-original-hash'=$loaderText.Replace('E55E6E34BBB4DB40904F065292F23A76D48BE809D18E7EB76E0C3A7ECCA786F2','0' * 64)
            'wrong-supplemental-hash'=$loaderText.Replace($supplementalIdentity.raw_sha256,'F' * 64)
            'preexisting-trust-removed'=$loaderText.Replace("if (-not `$trustedReuse) { throw 'PREEXISTING_UNTRUSTED_DECLARATION_TYPE_STATE' }",'')
        }
        foreach ($case in $cases.GetEnumerator()) {
            $fixture = Join-Path $tempRoot ($case.Key + '.psm1')
            [IO.File]::WriteAllText($fixture, [string]$case.Value, [Text.UTF8Encoding]::new($false))
            Assert-LiveApplyCondition (@(Test-LiveApplyLoaderText ([IO.File]::ReadAllText($fixture))).Count -gt 0) "loader tamper accepted: $($case.Key)"
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
    }
}

Invoke-LiveApplyTestCase 'loader exposes no reusable native capability or secret sentinel pattern' {
    Assert-LiveApplyCondition ($loaderText -notmatch '(?i)\$script:\w*(?:secret|sentinel|capability)\w*\s*=') 'secret sentinel or capability variable present'
    Assert-LiveApplyCondition ($loaderText -notmatch 'MethodInfo|GetDelegateForFunctionPointer|NativeLibrary|LoadLibrary|GetProcAddress') 'reusable native capability surface present'
    Assert-LiveApplyCondition ($loaderText -match 'stores strings only') 'process-local record limitation missing'
    Assert-LiveApplyCondition ($loaderText -match "Status = 'FAILED'; Reason = 'DECLARATION_LOAD_CONTRACT_REJECTED'") 'fixed failure metadata missing'
}

$failed = @($tests | Where-Object result -ne 'PASS')
$report = [pscustomobject][ordered]@{
    schema_version = 'chatpad-native-interop-live-apply-extensions-static-test-v1'
    result = if ($failed.Count) { 'FAIL' } else { 'PASS' }
    test_count = $tests.Count
    assertion_count = $assertionCount
    failed_test_count = $failed.Count
    runtime = $PSVersionTable.PSEdition
    powershell_version = $PSVersionTable.PSVersion.ToString()
    sdk_version = $sdkVersion
    authoritative_headers = @($setupApiHeader,$devpropdefHeader,$devpkeyHeader)
    original_identity = $originalIdentity
    supplemental_identity = $supplementalIdentity
    loader_identity = Get-LiveApplyFileIdentity $loaderPath
    tests = @($tests)
    prohibited_operation_counters = [pscustomobject][ordered]@{
        csharp_compilations=0; declaration_loads=0; native_invocations=0; setupapi_newdev_invocations=0
        device_queries=0; pnp_queries=0; usb_queries=0; hid_queries=0; registry_queries=0; service_queries=0
        binding_operations=0; windows_mutations=0; driver_actions=0; binary_emissions=0
    }
}
Write-Output $report
if ($failed.Count) { exit 1 }
