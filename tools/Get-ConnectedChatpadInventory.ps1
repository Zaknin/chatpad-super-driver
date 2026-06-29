[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-ToStableValue {
    param([Parameter()][object]$Value)

    if ($null -eq $Value) {
        return $null
    }
    if ($Value -is [datetime]) {
        return $Value.ToUniversalTime().ToString('o')
    }
    if ($Value -is [System.Array]) {
        return @($Value | ForEach-Object { Convert-ToStableValue -Value $_ })
    }
    if ($Value -is [guid]) {
        return $Value.ToString('B').ToUpperInvariant()
    }
    return $Value
}

function Get-PropertyMap {
    param([Parameter(Mandatory)][string]$InstanceId)

    $map = @{}
    foreach ($property in @(Get-PnpDeviceProperty -InstanceId $InstanceId -ErrorAction SilentlyContinue)) {
        $map[[string]$property.KeyName] = Convert-ToStableValue -Value $property.Data
    }
    return $map
}

function Get-MapValue {
    param(
        [Parameter(Mandatory)][hashtable]$Map,
        [Parameter(Mandatory)][string]$Key
    )

    if ($Map.ContainsKey($Key)) {
        return $Map[$Key]
    }
    return $null
}

function Convert-ToStringArray {
    param([Parameter()][object]$Value)

    if ($null -eq $Value) {
        return @()
    }
    $unique = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Value)) {
        $text = [string]$item
        if ($text -ne '') {
            [void]$unique.Add($text)
        }
    }
    $result = [string[]]@($unique)
    [System.Array]::Sort($result, [System.StringComparer]::OrdinalIgnoreCase)
    return $result
}

function Get-RegistryValues {
    param([Parameter(Mandatory)][string]$LiteralPath)

    try {
        return Get-ItemProperty -LiteralPath $LiteralPath -ErrorAction Stop
    }
    catch {
        return $null
    }
}

function Get-ObjectValue {
    param(
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string]$Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }
    return $null
}

function Get-CandidateSignals {
    param([Parameter(Mandatory)][object]$Entity)

    $signals = [System.Collections.Generic.List[string]]::new()
    $identityText = @(
        [string]$Entity.Name,
        [string]$Entity.Caption,
        [string]$Entity.Description,
        [string]$Entity.PNPDeviceID,
        [string]$Entity.Manufacturer,
        [string]$Entity.Service,
        [string]$Entity.PNPClass,
        (@($Entity.HardwareID) -join ' '),
        (@($Entity.CompatibleID) -join ' ')
    ) -join ' '

    if ($identityText -match '(?i)Xbox|XUSB|Chatpad|Microsoft Common Controller') {
        $signals.Add('name-or-identity')
    }
    if ($identityText -match '(?i)VID_045E&PID_028E') {
        $signals.Add('controller-vid-pid')
    }
    if ($identityText -match '(?i)MS_COMP_XUSB|COMPAT_VID_045E') {
        $signals.Add('xusb-compatible-id')
    }
    if ([string]$Entity.Service -match '(?i)^xusb') {
        $signals.Add('xusb-service')
    }
    if ([string]$Entity.PNPClass -match '(?i)XnaComposite|HIDClass|USB') {
        $signals.Add('relevant-pnp-class')
    }
    if ([string]$Entity.Manufacturer -match '(?i)Microsoft') {
        $signals.Add('microsoft-manufacturer')
    }

    return @($signals | Sort-Object -Unique)
}

function Get-MinimalSnapshot {
    param([Parameter(Mandatory)][string[]]$InstanceIds)

    $entities = @{}
    foreach ($entity in @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop)) {
        $entities[[string]$entity.PNPDeviceID] = $entity
    }
    $pnpDevices = @{}
    foreach ($device in @(Get-PnpDevice -ErrorAction Stop)) {
        $pnpDevices[[string]$device.InstanceId] = $device
    }

    $snapshot = [System.Collections.Generic.List[object]]::new()
    foreach ($instanceId in @($InstanceIds | Sort-Object -Unique)) {
        $entity = if ($entities.ContainsKey($instanceId)) { $entities[$instanceId] } else { $null }
        $device = if ($pnpDevices.ContainsKey($instanceId)) { $pnpDevices[$instanceId] } else { $null }
        $driverInf = $null
        try {
            $driverInf = (Get-PnpDeviceProperty -InstanceId $instanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop).Data
        }
        catch {
            $driverInf = $null
        }
        $snapshot.Add([pscustomobject][ordered]@{
            InstanceId = $instanceId
            Status = if ($null -ne $device) { [string]$device.Status } elseif ($null -ne $entity) { [string]$entity.Status } else { $null }
            ProblemCode = if ($null -ne $entity) { [int]$entity.ConfigManagerErrorCode } else { $null }
            Service = if ($null -ne $entity) { [string]$entity.Service } else { $null }
            DriverInf = if ($null -ne $driverInf) { [string]$driverInf } else { $null }
            Present = if ($null -ne $entity) { [bool]$entity.Present } else { $false }
        })
    }
    return @($snapshot)
}

function Compare-MinimalSnapshots {
    param(
        [Parameter(Mandatory)][object[]]$Before,
        [Parameter(Mandatory)][object[]]$After
    )

    $afterById = @{}
    foreach ($item in $After) {
        $afterById[[string]$item.InstanceId] = $item
    }
    $differences = [System.Collections.Generic.List[object]]::new()
    foreach ($beforeItem in $Before) {
        $instanceId = [string]$beforeItem.InstanceId
        if (-not $afterById.ContainsKey($instanceId)) {
            $differences.Add([pscustomobject][ordered]@{
                InstanceId = $instanceId
                Field = 'SnapshotEntry'
                Before = 'Present'
                After = 'Missing'
            })
            continue
        }
        $afterItem = $afterById[$instanceId]
        foreach ($field in @('Status', 'ProblemCode', 'Service', 'DriverInf', 'Present')) {
            $beforeValue = $beforeItem.$field
            $afterValue = $afterItem.$field
            if ([string]$beforeValue -cne [string]$afterValue) {
                $differences.Add([pscustomobject][ordered]@{
                    InstanceId = $instanceId
                    Field = $field
                    Before = $beforeValue
                    After = $afterValue
                })
            }
        }
    }
    return @($differences)
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )

    $json = ConvertTo-Json -InputObject $Value -Depth 12
    Write-Utf8NoBom -Path $Path -Content ($json + [Environment]::NewLine)
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'AGENTS.md') -PathType Leaf)) {
    throw "Repository root could not be located from script path: $PSScriptRoot"
}

Import-Module PnpDevice -ErrorAction Stop

$generatedAtUtc = [datetime]::UtcNow
$timestamp = $generatedAtUtc.ToString('yyyyMMddTHHmmssfffZ')
$outputRoot = Join-Path $repoRoot 'artifacts\device-inventory'
$outputDirectory = Join-Path $outputRoot $timestamp
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$allEntities = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop)
$presentEntities = @($allEntities | Where-Object { $_.Present -eq $true })
$presentPnpDevices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop)
$presentPnpById = @{}
foreach ($device in $presentPnpDevices) {
    $presentPnpById[[string]$device.InstanceId] = $device
}

$candidateRecords = [System.Collections.Generic.List[object]]::new()
foreach ($entity in $presentEntities) {
    $signals = @(Get-CandidateSignals -Entity $entity)
    $identityText = @(
        [string]$entity.PNPDeviceID,
        [string]$entity.Name,
        [string]$entity.Service,
        (@($entity.HardwareID) -join ' '),
        (@($entity.CompatibleID) -join ' ')
    ) -join ' '
    $isCandidate = (
        $identityText -match '(?i)VID_045E&PID_028E|Xbox|XUSB|Chatpad|MS_COMP_XUSB' -or
        [string]$entity.Service -match '(?i)^xusb'
    )
    if ($isCandidate) {
        $candidateRecords.Add([pscustomobject][ordered]@{
            InstanceId = [string]$entity.PNPDeviceID
            FriendlyName = [string]$entity.Name
            PnpClass = [string]$entity.PNPClass
            Manufacturer = [string]$entity.Manufacturer
            Service = [string]$entity.Service
            Status = [string]$entity.Status
            Present = [bool]$entity.Present
            ProblemCode = [int]$entity.ConfigManagerErrorCode
            HardwareIds = @(Convert-ToStringArray -Value $entity.HardwareID)
            CompatibleIds = @(Convert-ToStringArray -Value $entity.CompatibleID)
            DiscoverySignals = $signals
        })
    }
}
$candidateRecords = @($candidateRecords | Sort-Object InstanceId -Unique)

$controllerCandidate = @($candidateRecords | Where-Object {
    $_.InstanceId -match '(?i)^USB\\VID_045E&PID_028E\\' -and
    ($_.PnpClass -eq 'XnaComposite' -or $_.Service -match '(?i)^xusb')
} | Select-Object -First 1)
if ($controllerCandidate.Count -ne 1) {
    throw "Expected exactly one present Xbox controller candidate; found $($controllerCandidate.Count)."
}
$controllerId = [string]$controllerCandidate[0].InstanceId
$targetInstanceIds = @(Convert-ToStringArray -Value @($candidateRecords | Where-Object {
    $_.InstanceId -match '(?i)VID_045E&PID_028E'
} | Select-Object -ExpandProperty InstanceId))
if ($targetInstanceIds.Count -eq 0) {
    throw 'No present VID_045E&PID_028E target nodes were found.'
}

# The baseline intentionally precedes full property, topology, interface, and driver collection.
$baseline = @(Get-MinimalSnapshot -InstanceIds $targetInstanceIds)

$propertyMaps = @{}
function Ensure-PropertyMap {
    param([Parameter(Mandatory)][string]$InstanceId)
    if (-not $propertyMaps.ContainsKey($InstanceId)) {
        $propertyMaps[$InstanceId] = Get-PropertyMap -InstanceId $InstanceId
    }
    return $propertyMaps[$InstanceId]
}

$relatedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($instanceId in $targetInstanceIds) {
    [void]$relatedIds.Add($instanceId)
}

$controllerMap = Ensure-PropertyMap -InstanceId $controllerId
foreach ($relationshipKey in @('DEVPKEY_Device_Parent', 'DEVPKEY_Device_Children', 'DEVPKEY_Device_Siblings')) {
    foreach ($relatedId in @(Convert-ToStringArray -Value (Get-MapValue -Map $controllerMap -Key $relationshipKey))) {
        [void]$relatedIds.Add($relatedId)
    }
}

$ancestorIds = [System.Collections.Generic.List[string]]::new()
$nextAncestor = [string](Get-MapValue -Map $controllerMap -Key 'DEVPKEY_Device_Parent')
$ancestorGuard = 0
while ($nextAncestor -and $ancestorGuard -lt 16) {
    if ($ancestorIds -contains $nextAncestor) {
        break
    }
    $ancestorIds.Add($nextAncestor)
    [void]$relatedIds.Add($nextAncestor)
    $ancestorMap = Ensure-PropertyMap -InstanceId $nextAncestor
    $nextAncestor = [string](Get-MapValue -Map $ancestorMap -Key 'DEVPKEY_Device_Parent')
    $ancestorGuard++
}

$descendantQueue = [System.Collections.Generic.Queue[string]]::new()
$descendantQueue.Enqueue($controllerId)
$visitedDescendants = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
while ($descendantQueue.Count -gt 0) {
    $currentId = $descendantQueue.Dequeue()
    if (-not $visitedDescendants.Add($currentId)) {
        continue
    }
    $currentMap = Ensure-PropertyMap -InstanceId $currentId
    foreach ($childId in @(Convert-ToStringArray -Value (Get-MapValue -Map $currentMap -Key 'DEVPKEY_Device_Children'))) {
        [void]$relatedIds.Add($childId)
        $descendantQueue.Enqueue($childId)
    }
}

$allSignedDrivers = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop)
$signedDriverById = @{}
foreach ($driver in $allSignedDrivers) {
    if ($driver.DeviceID) {
        $signedDriverById[[string]$driver.DeviceID] = $driver
    }
}
$allSystemDrivers = @(Get-CimInstance Win32_SystemDriver -ErrorAction Stop)
$systemDriverByName = @{}
foreach ($service in $allSystemDrivers) {
    if ($service.Name) {
        $systemDriverByName[[string]$service.Name] = $service
    }
}

$deviceRecords = [System.Collections.Generic.List[object]]::new()
$driverBindings = [System.Collections.Generic.List[object]]::new()
$relationshipEdges = [System.Collections.Generic.List[object]]::new()
$classGuids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($instanceId in @($relatedIds | Sort-Object)) {
    $map = Ensure-PropertyMap -InstanceId $instanceId
    $pnp = if ($presentPnpById.ContainsKey($instanceId)) { $presentPnpById[$instanceId] } else { $null }
    $classGuid = [string](Get-MapValue -Map $map -Key 'DEVPKEY_Device_ClassGuid')
    if ($classGuid) {
        [void]$classGuids.Add($classGuid)
    }
    $parentId = [string](Get-MapValue -Map $map -Key 'DEVPKEY_Device_Parent')
    if ($parentId) {
        $relationshipEdges.Add([pscustomobject][ordered]@{
            ParentInstanceId = $parentId
            ChildInstanceId = $instanceId
            Basis = 'DEVPKEY_Device_Parent'
        })
    }
    $deviceRecord = [pscustomobject][ordered]@{
        FriendlyName = if ($null -ne $pnp) { [string]$pnp.FriendlyName } else { [string](Get-MapValue -Map $map -Key 'DEVPKEY_NAME') }
        DeviceDescription = Get-MapValue -Map $map -Key 'DEVPKEY_Device_DeviceDesc'
        BusReportedDescription = Get-MapValue -Map $map -Key 'DEVPKEY_Device_BusReportedDeviceDesc'
        InstanceId = $instanceId
        Present = Get-MapValue -Map $map -Key 'DEVPKEY_Device_IsPresent'
        PnpStatus = if ($null -ne $pnp) { [string]$pnp.Status } else { $null }
        ProblemCode = Get-MapValue -Map $map -Key 'DEVPKEY_Device_ProblemCode'
        HasProblem = Get-MapValue -Map $map -Key 'DEVPKEY_Device_HasProblem'
        Manufacturer = Get-MapValue -Map $map -Key 'DEVPKEY_Device_Manufacturer'
        Enumerator = Get-MapValue -Map $map -Key 'DEVPKEY_Device_EnumeratorName'
        PnpClass = Get-MapValue -Map $map -Key 'DEVPKEY_Device_Class'
        ClassGuid = $classGuid
        HardwareIds = @(Convert-ToStringArray -Value (Get-MapValue -Map $map -Key 'DEVPKEY_Device_HardwareIds'))
        CompatibleIds = @(Convert-ToStringArray -Value (Get-MapValue -Map $map -Key 'DEVPKEY_Device_CompatibleIds'))
        Service = Get-MapValue -Map $map -Key 'DEVPKEY_Device_Service'
        DriverInf = Get-MapValue -Map $map -Key 'DEVPKEY_Device_DriverInfPath'
        DriverProvider = Get-MapValue -Map $map -Key 'DEVPKEY_Device_DriverProvider'
        DriverVersion = Get-MapValue -Map $map -Key 'DEVPKEY_Device_DriverVersion'
        DriverDate = Get-MapValue -Map $map -Key 'DEVPKEY_Device_DriverDate'
        MatchingDeviceId = Get-MapValue -Map $map -Key 'DEVPKEY_Device_MatchingDeviceId'
        ParentInstanceId = $parentId
        DirectChildInstanceIds = @(Convert-ToStringArray -Value (Get-MapValue -Map $map -Key 'DEVPKEY_Device_Children'))
        SiblingInstanceIds = @(Convert-ToStringArray -Value (Get-MapValue -Map $map -Key 'DEVPKEY_Device_Siblings'))
        ContainerId = Get-MapValue -Map $map -Key 'DEVPKEY_Device_ContainerId'
        LocationInformation = Get-MapValue -Map $map -Key 'DEVPKEY_Device_LocationInfo'
        LocationPaths = @(Convert-ToStringArray -Value (Get-MapValue -Map $map -Key 'DEVPKEY_Device_LocationPaths'))
        Address = Get-MapValue -Map $map -Key 'DEVPKEY_Device_Address'
        BusNumber = Get-MapValue -Map $map -Key 'DEVPKEY_Device_BusNumber'
        BusTypeGuid = Get-MapValue -Map $map -Key 'DEVPKEY_Device_BusTypeGuid'
        Capabilities = Get-MapValue -Map $map -Key 'DEVPKEY_Device_Capabilities'
        RemovalPolicy = Get-MapValue -Map $map -Key 'DEVPKEY_Device_RemovalPolicy'
        RemovalPolicyDefault = Get-MapValue -Map $map -Key 'DEVPKEY_Device_RemovalPolicyDefault'
        SafeRemovalRequired = Get-MapValue -Map $map -Key 'DEVPKEY_Device_SafeRemovalRequired'
        Stack = @(Convert-ToStringArray -Value (Get-MapValue -Map $map -Key 'DEVPKEY_Device_Stack'))
        DeviceUpperFilters = @(Convert-ToStringArray -Value (Get-MapValue -Map $map -Key 'DEVPKEY_Device_UpperFilters'))
        DeviceLowerFilters = @(Convert-ToStringArray -Value (Get-MapValue -Map $map -Key 'DEVPKEY_Device_LowerFilters'))
    }
    $deviceRecords.Add($deviceRecord)

    $signedDriver = if ($signedDriverById.ContainsKey($instanceId)) { $signedDriverById[$instanceId] } else { $null }
    $serviceName = [string]$deviceRecord.Service
    $systemDriver = if ($serviceName -and $systemDriverByName.ContainsKey($serviceName)) { $systemDriverByName[$serviceName] } else { $null }
    $driverBindings.Add([pscustomobject][ordered]@{
        InstanceId = $instanceId
        Service = $serviceName
        InfName = if ($null -ne $signedDriver) { [string]$signedDriver.InfName } else { [string]$deviceRecord.DriverInf }
        Provider = if ($null -ne $signedDriver) { [string]$signedDriver.DriverProviderName } else { [string]$deviceRecord.DriverProvider }
        Version = if ($null -ne $signedDriver) { [string]$signedDriver.DriverVersion } else { [string]$deviceRecord.DriverVersion }
        Date = if ($null -ne $signedDriver) { Convert-ToStableValue -Value $signedDriver.DriverDate } else { $deviceRecord.DriverDate }
        Signer = if ($null -ne $signedDriver) { [string]$signedDriver.Signer } else { $null }
        IsSigned = if ($null -ne $signedDriver) { [bool]$signedDriver.IsSigned } else { $null }
        MatchingDeviceId = [string]$deviceRecord.MatchingDeviceId
        SignedDriverHardwareId = if ($null -ne $signedDriver) { [string]$signedDriver.HardWareID } else { $null }
        ServiceDisplayName = if ($null -ne $systemDriver) { [string]$systemDriver.DisplayName } else { $null }
        ServiceState = if ($null -ne $systemDriver) { [string]$systemDriver.State } else { $null }
        ServiceStartMode = if ($null -ne $systemDriver) { [string]$systemDriver.StartMode } else { $null }
        DriverFilePath = if ($null -ne $systemDriver) { [string]$systemDriver.PathName } else { $null }
    })
}
$deviceRecords = @($deviceRecords | Sort-Object InstanceId)
$driverBindings = @($driverBindings | Sort-Object InstanceId)
$relationshipEdges = @($relationshipEdges | Sort-Object ParentInstanceId, ChildInstanceId -Unique)

$containerId = [string](Get-MapValue -Map $controllerMap -Key 'DEVPKEY_Device_ContainerId')
$containerNodes = @(Convert-ToStringArray -Value @($deviceRecords | Where-Object { $_.ContainerId -eq $containerId } | Select-Object -ExpandProperty InstanceId))
$directChildren = @(Convert-ToStringArray -Value (Get-MapValue -Map $controllerMap -Key 'DEVPKEY_Device_Children'))
$siblings = @(Convert-ToStringArray -Value (Get-MapValue -Map $controllerMap -Key 'DEVPKEY_Device_Siblings'))

$classFilters = [System.Collections.Generic.List[object]]::new()
foreach ($classGuid in @($classGuids | Sort-Object)) {
    $classPath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\$classGuid"
    $values = Get-RegistryValues -LiteralPath $classPath
    $classFilters.Add([pscustomobject][ordered]@{
        ClassGuid = $classGuid
        ClassName = if ($null -ne $values) { [string](Get-ObjectValue -InputObject $values -Name 'Class') } else { $null }
        ClassDescription = if ($null -ne $values) { [string](Get-ObjectValue -InputObject $values -Name 'ClassDesc') } else { $null }
        UpperFilters = if ($null -ne $values) { @(Convert-ToStringArray -Value (Get-ObjectValue -InputObject $values -Name 'UpperFilters')) } else { @() }
        LowerFilters = if ($null -ne $values) { @(Convert-ToStringArray -Value (Get-ObjectValue -InputObject $values -Name 'LowerFilters')) } else { @() }
    })
}
$classFilters = @($classFilters | Sort-Object ClassGuid)

$knownInterfaceClassNames = @{
    '{4D1E55B2-F16F-11CF-88CB-001111000030}' = 'GUID_DEVINTERFACE_HID'
    '{A5DCBF10-6530-11D2-901F-00C04FB951ED}' = 'GUID_DEVINTERFACE_USB_DEVICE'
    '{F18A0E88-C30C-11D0-8815-00A0C906BED8}' = 'GUID_DEVINTERFACE_USB_HUB'
}
$interfaces = [System.Collections.Generic.List[object]]::new()
$deviceClassesRoot = 'Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceClasses'
foreach ($interfaceClassKey in @(Get-ChildItem -LiteralPath $deviceClassesRoot -ErrorAction Stop)) {
    $interfaceClassGuid = $interfaceClassKey.PSChildName.ToUpperInvariant()
    foreach ($registrationKey in @(Get-ChildItem -LiteralPath $interfaceClassKey.PSPath -ErrorAction SilentlyContinue)) {
        $values = Get-RegistryValues -LiteralPath $registrationKey.PSPath
        $registeredDeviceInstance = if ($null -ne $values) { Get-ObjectValue -InputObject $values -Name 'DeviceInstance' } else { $null }
        if (-not $registeredDeviceInstance) {
            continue
        }
        $deviceInstance = [string]$registeredDeviceInstance
        if (-not $relatedIds.Contains($deviceInstance)) {
            continue
        }
        $encodedPath = [string]$registrationKey.PSChildName
        $symbolicPath = if ($encodedPath.StartsWith('##?#')) { '\\?\' + $encodedPath.Substring(4) } else { $encodedPath }
        $interfaces.Add([pscustomobject][ordered]@{
            DeviceInstanceId = $deviceInstance
            InterfaceClassGuid = $interfaceClassGuid
            InterfaceClassName = if ($knownInterfaceClassNames.ContainsKey($interfaceClassGuid)) { $knownInterfaceClassNames[$interfaceClassGuid] } else { $null }
            SymbolicPath = $symbolicPath
            Source = 'Cached DeviceClasses registry metadata for a present device node'
            InterfaceOpened = $false
        })
    }
}
$interfaces = @($interfaces | Sort-Object DeviceInstanceId, InterfaceClassGuid, SymbolicPath -Unique)

$relatedHidNodes = @(Convert-ToStringArray -Value @($deviceRecords | Where-Object {
    $_.PnpClass -eq 'HIDClass' -and $_.InstanceId -match '(?i)VID_045E&PID_028E'
} | Select-Object -ExpandProperty InstanceId))
$separateChatpadNodes = @(Convert-ToStringArray -Value @($presentEntities | Where-Object {
    (@([string]$_.Name, [string]$_.Description, [string]$_.PNPDeviceID, (@($_.HardwareID) -join ' ')) -join ' ') -match '(?i)Chatpad'
} | Select-Object -ExpandProperty PNPDeviceID))

$finalSnapshot = @(Get-MinimalSnapshot -InstanceIds $targetInstanceIds)
$stateDifferences = @(Compare-MinimalSnapshots -Before $baseline -After $finalSnapshot)
$stateUnchanged = ($stateDifferences.Count -eq 0)

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
$relationships = [pscustomobject][ordered]@{
    ControllerInstanceId = $controllerId
    ParentInstanceId = [string](Get-MapValue -Map $controllerMap -Key 'DEVPKEY_Device_Parent')
    DirectChildInstanceIds = $directChildren
    SiblingInstanceIds = $siblings
    AncestorInstanceIds = @($ancestorIds)
    ContainerId = $containerId
    ContainerNodeInstanceIds = $containerNodes
    ParentChildEdges = $relationshipEdges
}
$conclusions = [pscustomobject][ordered]@{
    ControllerInstanceId = $controllerId
    ControllerVidPid = 'VID_045E&PID_028E'
    SeparateChatpadNodeObserved = ($separateChatpadNodes.Count -gt 0)
    SeparateChatpadNodeInstanceIds = $separateChatpadNodes
    RelatedHidNodeInstanceIds = $relatedHidNodes
    ChatpadVisibility = if ($separateChatpadNodes.Count -gt 0) {
        'A separately Chatpad-labeled present PnP node was observed.'
    } else {
        'No separately Chatpad-labeled PnP node was observed. Related HID nodes exist, but cached inventory does not identify either as the Chatpad.'
    }
    EndpointLayoutAvailable = $false
    ActivationTransportTargetIdentified = $false
    AttachmentInference = 'The physical USB/XnaComposite controller node is the narrowest plausible future device-specific filter attachment point; inventory alone does not prove endpoint or control-transfer access.'
}

$inventory = [pscustomobject][ordered]@{
    SchemaVersion = 'connected-chatpad-device-inventory-v1'
    GeneratedAtUtc = $generatedAtUtc.ToString('o')
    RepositoryRoot = $repoRoot
    OutputDirectory = $outputDirectory
    PowerShell = [pscustomobject][ordered]@{
        Edition = [string]$PSVersionTable.PSEdition
        Version = [string]$PSVersionTable.PSVersion
    }
    OperatingSystem = [pscustomobject][ordered]@{
        Caption = [string]$os.Caption
        Version = [string]$os.Version
        BuildNumber = [string]$os.BuildNumber
        Architecture = [string]$os.OSArchitecture
    }
    SafetyBoundary = [pscustomobject][ordered]@{
        DeviceStateChanged = $false
        DeviceHandleOpened = $false
        InterfaceHandleOpened = $false
        NetworkRequested = $false
        DataSources = @('Get-PnpDevice', 'Get-PnpDeviceProperty', 'Win32_PnPEntity', 'Win32_PnPSignedDriver', 'Win32_SystemDriver', 'read-only registry metadata')
    }
    Discovery = [pscustomobject][ordered]@{
        CandidateCount = $candidateRecords.Count
        TargetInstanceIds = $targetInstanceIds
        ControllerInstanceId = $controllerId
    }
    BaselineSnapshot = $baseline
    CandidateDevices = $candidateRecords
    Devices = $deviceRecords
    Relationships = $relationships
    DriverBindings = $driverBindings
    Interfaces = $interfaces
    ClassFilters = $classFilters
    Conclusions = $conclusions
    FinalSnapshot = $finalSnapshot
    StateComparison = [pscustomobject][ordered]@{
        Unchanged = $stateUnchanged
        Differences = $stateDifferences
    }
}

$inventoryPath = Join-Path $outputDirectory 'inventory.json'
$textPath = Join-Path $outputDirectory 'inventory.txt'
$candidatePath = Join-Path $outputDirectory 'candidate-devices.json'
$relationshipsPath = Join-Path $outputDirectory 'relationships.json'
$driverBindingsPath = Join-Path $outputDirectory 'driver-bindings.json'
$interfacesPath = Join-Path $outputDirectory 'interfaces.json'

Write-JsonFile -Path $inventoryPath -Value $inventory
Write-JsonFile -Path $candidatePath -Value $candidateRecords
Write-JsonFile -Path $relationshipsPath -Value $relationships
Write-JsonFile -Path $driverBindingsPath -Value $driverBindings
Write-JsonFile -Path $interfacesPath -Value $interfaces

$controllerRecord = @($deviceRecords | Where-Object { $_.InstanceId -eq $controllerId })[0]
$controllerDriver = @($driverBindings | Where-Object { $_.InstanceId -eq $controllerId })[0]
$text = [System.Collections.Generic.List[string]]::new()
$text.Add('Connected Xbox 360 Controller and Chatpad read-only inventory')
$text.Add("Generated UTC: $($generatedAtUtc.ToString('o'))")
$text.Add("PowerShell: $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)")
$text.Add("Operating system: $($os.Caption) $($os.Version) build $($os.BuildNumber)")
$text.Add('')
$text.Add("Controller instance ID: $controllerId")
$text.Add("Hardware IDs: $($controllerRecord.HardwareIds -join '; ')")
$text.Add("Compatible IDs: $($controllerRecord.CompatibleIds -join '; ')")
$text.Add("Class: $($controllerRecord.PnpClass) $($controllerRecord.ClassGuid)")
$text.Add("Service: $($controllerRecord.Service)")
$text.Add("Driver: $($controllerDriver.InfName); $($controllerDriver.Provider); $($controllerDriver.Version); $($controllerDriver.Date); signer $($controllerDriver.Signer)")
$text.Add("Parent: $($relationships.ParentInstanceId)")
$text.Add("Direct children: $($relationships.DirectChildInstanceIds -join '; ')")
$text.Add("Container nodes: $($relationships.ContainerNodeInstanceIds -join '; ')")
$text.Add("Related HID nodes: $($relatedHidNodes -join '; ')")
$text.Add("Separate Chatpad node observed: $($conclusions.SeparateChatpadNodeObserved)")
$text.Add("Chatpad visibility: $($conclusions.ChatpadVisibility)")
$text.Add("Interface classes: $((@($interfaces.InterfaceClassGuid | Sort-Object -Unique)) -join '; ')")
$text.Add("Baseline versus final state unchanged: $stateUnchanged")
$text.Add('Device handles opened: False')
$text.Add('Device state changed: False')
$text.Add('Endpoint layout available from cached inventory: False')
$text.Add('Activation transport target identified from cached inventory: False')
Write-Utf8NoBom -Path $textPath -Content (($text -join [Environment]::NewLine) + [Environment]::NewLine)

Write-Output "Inventory JSON: $inventoryPath"
Write-Output "Inventory text: $textPath"
Write-Output "Candidate devices JSON: $candidatePath"
Write-Output "Relationships JSON: $relationshipsPath"
Write-Output "Driver bindings JSON: $driverBindingsPath"
Write-Output "Interfaces JSON: $interfacesPath"
Write-Output "Baseline versus final state unchanged: $stateUnchanged"

if (-not $stateUnchanged) {
    throw 'Target device state changed during inventory. No repair was attempted.'
}

exit 0
