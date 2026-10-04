# Next Task

## TASK 8L-C4L2 — Install diagnostic broker package and identify live scope blocker

- Branch: `feature/chatpad-usermode-runner`; diagnostic implementation commit `b621b2714ec133f2875d25d00c900da22866a95f`; canonical release result/receipt identity commit `099da4ab13a6f46912e4993dec6c38415681680a`.
- The new diagnostic package is published under `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261004T194810Z`. Archive SHA-256: `05CD44BF7CE9A7A933DE078B5DD641992575F0874D4F3E097B3B5A610EBB0222`. Offline tests: managed 158/158, focused native 2/2, package 214/214 exact hashes, C4 setup and readiness checks PASS.
- Two earlier normal-user runs reached `RUNNING` and passed Chatpad activation but failed closed at the present ROOT/SWD index-zero guard. Read-only checks immediately after both runs found no matching present node, so the exact transient instance is still unknown. The new package includes the conflicting instance ID in the error response; the guard remains strict.

### Manual elevated setup

In elevated PowerShell, run:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-scope-conflict-id-b621b27\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

After it returns PASS, run in ordinary, non-elevated PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-scope-conflict-id-b621b27\package\ChatpadBridge.exe" run
```

If creation succeeds, qualify XInput/buttons/sticks/triggers, Chatpad, rumble callback, and Ctrl+C cleanup. If `virtual_scope_conflict` repeats, send the full error including its instance ID; inspect presence and ownership read-only. Do not delete devices/registry records, weaken the guard, stop the service, or reboot. Proceed to reconnect and crash-recovery testing only after the normal runtime succeeds.

Inspect first: latest C4L2 entries in `docs/WORKLOG.md`, package `build-manifest.json`, final `result-manifest.json`, and `publication-receipt.json`.
