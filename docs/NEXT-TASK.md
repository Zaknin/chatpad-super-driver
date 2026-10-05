# TASK 8L-C4L2 — Qualify client crash cleanup

## Current state

- Branch: `feature/chatpad-usermode-runner`; runner fix source commit `92a368830bb6ecfb0a990ba68051583b506d5dd0` is pushed. Current HEAD is this docs continuity closeout.
- Corrected package: `artifacts/task-8lc4l2/build-rumble-removal-reconnect/package`; package manifest has 214/214 verified files. Runner SHA-256: `860B27E194ADF6F449AC3B4B9C2B57CA77F95EE362CF6A18F7BA9460A8F3B88D`.
- Live normal-user test passed activation, broker/XInput creation, Chatpad input and rumble previously. In the corrected package, unplug yielded `zero-rumble cleanup deferred device_removed`, then `DEVICE_LOST` / `RECONNECTING`; after replug the runner reopened WinUSB, logged `unclean-session zero-rumble recovery succeeded`, and recreated the virtual Xbox. The user confirmed controller and Chatpad worked after reconnect.
- Graceful stop after reconnect passed: all four cleanup flags true, `clean_shutdown=true`, `reconnect_count=1`.
- Client hard-crash cleanup is the remaining live broker behavior. Do not repeat service repair; installed service payload is unchanged. The accepted limitation is that a hard client crash cannot stop physical rumble immediately.

## Next action

1. Start the package runner from ordinary, non-elevated PowerShell:

   ```powershell
   & "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-removal-reconnect\package\ChatpadBridge.exe" run
   ```

2. Wait for `virtual Xbox created and initial controller state submitted`. In a second ordinary PowerShell, stop only the process launched from that exact package path:

   ```powershell
   $expectedRunnerPath = 'C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-rumble-removal-reconnect\package\ChatpadBridge.exe'
   $matchingRunnerProcesses = @(Get-CimInstance Win32_Process -Filter "Name = 'ChatpadBridge.exe'" |
       Where-Object { $_.ExecutablePath -ieq $expectedRunnerPath })
   if ($matchingRunnerProcesses.Count -ne 1) { throw "Expected exactly one package runner; found $($matchingRunnerProcesses.Count). No process stopped." }
   $matchingRunnerProcesses | Select-Object ProcessId, ExecutablePath
   Stop-Process -Id $matchingRunnerProcesses[0].ProcessId -Force
   Start-Sleep -Seconds 3
   Get-PnpDevice -PresentOnly |
       Where-Object { $_.InstanceId -like 'ROOT\VID_045E&PID_028E&IG_00\*' } |
       Format-List Status, FriendlyName, InstanceId
   Get-Service -Name ChatpadHidMaestroBroker | Format-List Status, StartType
   ```

   The target virtual Xbox PnP node should be absent and `ChatpadHidMaestroBroker` should still be Running. Return the PID/path, PnP result, and service result. If multiple matching processes appear, do not stop any; return the listing.

3. Start the same bridge again as a normal user. Acceptance requires `unclean_previous_session=true`, successful startup zero-rumble recovery, and creation of a fresh virtual Xbox. Stop it with Ctrl+C and return the full output.

## Safety and remaining acceptance

- The forced termination intentionally simulates only a `ChatpadBridge.exe` client crash. Match and stop exactly one process by full executable path; do not kill the LocalSystem helper or service.
- No elevated bridge, service install/repair, driver binding, PnP mutation, registry/trust/boot change, or global HIDMaestro cleanup.
- On hard client crash, physical motor stop is not expected; that limitation was explicitly accepted. Broker cleanup must still neutralize and destroy the virtual controller.
- After client-crash PASS, rerun final focused verification, bind readiness to final HEAD, and use the atomic publisher for canonical TASK-8L-C4L2 artifacts. Report PASS/PARTIAL and remaining untested items honestly.

## Inspect first

Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the latest `docs/WORKLOG.md`; check branch/HEAD/status and verify the package manifest/readiness before the live test.
