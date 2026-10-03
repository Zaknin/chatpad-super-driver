[CmdletBinding()]
param([ValidateSet('Debug', 'Release')][string]$Configuration = 'Release',
    [string]$DotnetPath = 'dotnet', [string]$ArtifactsDirectory)
$ErrorActionPreference = 'Stop'
$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$destination = if ($ArtifactsDirectory) { [IO.Path]::GetFullPath($ArtifactsDirectory) } else { Join-Path $root 'artifacts/task-8lc2/virtual' }
$assembly = Join-Path $destination "bin/ChatpadVirtualXbox/$($Configuration.ToLowerInvariant())/ChatpadVirtualXbox.dll"
if (-not (Test-Path -LiteralPath $assembly -PathType Leaf)) { throw 'Build the offline helper first.' }
$results = [Collections.Generic.List[object]]::new()
function Invoke-Fixture([string]$Name, [string]$Backend, [byte[]]$Bytes, [bool]$CloseInput, [int]$ExpectedExit, [string]$ExpectedText) {
    $start = [Diagnostics.ProcessStartInfo]::new($DotnetPath)
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @($assembly, 'helper', '--backend', $Backend, '--duration-ms', '1500', '--idle-ms', '250')) { $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    if ($Bytes.Length) { $process.StandardInput.BaseStream.Write($Bytes); $process.StandardInput.BaseStream.Flush() }
    if ($CloseInput) { $process.StandardInput.Close() }
    $finished = $process.WaitForExit(5000)
    if (-not $finished) { $process.Kill($true); $process.WaitForExit() }
    $stdout = $outTask.GetAwaiter().GetResult()
    $stderr = $errTask.GetAwaiter().GetResult()
    $passed = $finished -and $process.ExitCode -eq $ExpectedExit -and $stdout.Contains($ExpectedText)
    $results.Add([ordered]@{ name = $Name; passed = $passed; finiteExit = $finished; exitCode = $process.ExitCode; expectedExit = $ExpectedExit; stdout = $stdout; stderr = $stderr })
    $process.Dispose()
}
$utf8 = [Text.UTF8Encoding]::new($false)
Invoke-Fixture 'mock create submit disconnect reconnect quit' 'mock' ($utf8.GetBytes("{`"id`":1,`"op`":`"create`"}`n{`"id`":2,`"op`":`"submit`",`"buttons`":4096,`"leftTrigger`":255,`"rightTrigger`":0,`"lx`":0,`"ly`":0,`"rx`":0,`"ry`":0}`n{`"id`":3,`"op`":`"disconnect`"}`n{`"id`":4,`"op`":`"create`"}`n{`"id`":5,`"op`":`"quit`"}`n")) $true 0 '"id":5,"ok":true'
Invoke-Fixture 'explicit unavailable' 'unavailable' ($utf8.GetBytes("{`"id`":1,`"op`":`"create`"}`n")) $true 0 'backend_unavailable'
Invoke-Fixture 'hidmaestro rejects create without live permission or runtime' 'hidmaestro' ($utf8.GetBytes("{`"id`":1,`"op`":`"create`"}`n")) $true 0 '"ok":false'
Invoke-Fixture 'finite idle with open pipe' 'mock' ([byte[]]@()) $false 4 'deadline_or_cancellation'
Invoke-Fixture 'finite partial line with open pipe' 'mock' ($utf8.GetBytes('{"id":1')) $false 4 'deadline_or_cancellation'
Invoke-Fixture 'unterminated EOF' 'mock' ($utf8.GetBytes('{"id":1')) $true 4 'unterminated_request'
Invoke-Fixture 'oversized request' 'mock' ($utf8.GetBytes(('x' * 4097))) $true 4 'line_too_long'
$passed = @($results | Where-Object { $_.passed }).Count
$failed = $results.Count - $passed
$report = [ordered]@{ suite = 'virtual-helper-process'; passed = $passed; failed = $failed; liveBackendCreated = $false; fixtures = @($results) }
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $destination "process-tests-$Configuration.json") -Encoding utf8
Write-Output "Helper process fixtures: $passed/$($results.Count) passed; $failed failed."
if ($failed) { throw 'Helper process tests failed; inspect generated JSON.' }
