$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$setup=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ChatpadSetup.ps1') -Raw
$build=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Build-ChatpadBridge.ps1') -Raw
$cmake=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ChatpadWinUsbPoc/CMakeLists.txt') -Raw
$launcher=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ChatpadWinUsbPoc/ChatpadBridgeStart.cpp') -Raw
$main=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ChatpadWinUsbPoc/main.cpp') -Raw
$runner=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ChatpadWinUsbPoc/Runner.cpp') -Raw
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'ChatpadSetup.ps1'),[ref]$tokens,[ref]$parseErrors)
if(@($parseErrors).Count){throw 'ChatpadSetup.ps1 failed PowerShell AST parsing.'}
$functions=@{}
foreach($name in @('Enable-ChatpadAutostart','Disable-ChatpadAutostart','Get-ChatpadAutostartStatus')){
 $node=$ast.Find({param($item) $item -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $item.Name -ceq $name},$true)
 if(-not $node){throw "Missing autostart function: $name"};$functions[$name]=$node.Extent.Text
}
if($setup -notmatch "ValidateSet\([^\)]*'EnableAutostart'" -or $setup -notmatch "'EnableAutostart' \{Enable-ChatpadAutostart" -or $setup -notmatch "'DisableAutostart' \{Disable-ChatpadAutostart" -or $setup -notmatch "'AutostartStatus' \{Get-ChatpadAutostartStatus") {throw 'Autostart modes are not all wired through setup dispatch.'}
if($functions['Enable-ChatpadAutostart'] -match 'Require-Administrator|Start-Service|sc\.exe|RunAs'){throw 'Per-user autostart enable must not require elevation or mutate the service.'}
if($functions['Enable-ChatpadAutostart'] -notmatch 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run' -or $functions['Enable-ChatpadAutostart'] -notmatch 'UserAuthorized' -or $functions['Get-ChatpadAutostartStatus'] -notmatch 'AuthorizedUserSid') {throw 'Autostart must be limited to the broker-authorized user.'}
$quotedValueRegex=@'
\$expected\s*=\s*'"'\s*\+\s*\$status\.LauncherPath\s*\+\s*'"'
'@
if($functions['Enable-ChatpadAutostart'] -notmatch $quotedValueRegex){throw 'Autostart registry command must quote the protected launcher path.'}
if($functions['Disable-ChatpadAutostart'] -notmatch 'Remove-ItemProperty' -or $functions['Disable-ChatpadAutostart'] -notmatch 'HKCU:') {throw 'Autostart disable must remove only this user Run value.'}
if($setup -notmatch 'ChatpadBridgeStart\.exe' -or $setup -notmatch 'function Assert-RunnerStopped'){throw 'Protected launcher install/manual lifecycle checks are missing.'}
if($main -notmatch 'command=="start"' -or $main -notmatch 'command=="stop"' -or $main -notmatch 'Local\\\\ChatpadBridge\.Stop\.v1' -or $main -notmatch 'Local\\\\ChatpadBridge\.LauncherStop\.v1'){throw 'Manual hidden start/graceful stop commands are missing.'}
if($build -notmatch "build/Release/ChatpadBridgeStart\.exe" -or $cmake -notmatch 'add_executable\(ChatpadBridgeStart WIN32') {throw 'Release package must include a Windows-subsystem hidden launcher.'}
if($launcher -notmatch 'CREATE_NO_WINDOW' -or $launcher -notmatch 'ProgramFiles' -or $launcher -notmatch 'Local\\\\ChatpadBridge\.Launcher\.v1' -or $launcher -notmatch 'Local\\\\ChatpadBridge\.LauncherStop\.v1' -or $launcher -notmatch 'WaitForSingleObject\(launcherStop, backoffSeconds \* 1000\)' -or $launcher -notmatch 'launcher\.log') {throw 'Launcher must be protected-root scoped, hidden, single-instance, supervised, and logged.'}
$resetIndex=$launcher.IndexOf('ResetEvent(runnerStop)');$createIndex=$launcher.IndexOf('CreateProcessW(runner.c_str()')
if($resetIndex -lt 0 -or $createIndex -lt $resetIndex -or $runner -match 'ResetEvent\(stopEvent\)') {throw 'Launcher must clear its stop event before creating the child, and the child must not erase a concurrent stop request.'}
if($launcher -match 'ShellExecute|runas|powershell|ChatpadVirtualXbox\.exe'){throw 'Launcher must not elevate, invoke PowerShell, or run the broker executable.'}
if($setup -notmatch 'AuthorizedUserSid' -or $setup -notmatch 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\ChatpadHidMaestroBroker\\Parameters'){throw 'Broker repair must persist the authorized SID for current-user autostart validation.'}
Write-Output 'C5 autostart/launcher regressions: 11/11 PASS'
