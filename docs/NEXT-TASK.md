# Next Task

## TASK 8L-C4L1 — Capture the exact normal-user virtual-backend failure stage

Current branch: `feature/chatpad-usermode-runner`; diagnostic implementation commit `ff6dcad52aaa2da486fbe5f354d6923bc412ab39` is pushed to origin. Verified package: `artifacts/task-8lc4/build-task-8lc4l1-normal-user-phase5-final`.

The user has already confirmed controller buttons, sticks, triggers, Chatpad input, and physical rumble. Their 14:16Z run also passed graceful cleanup (`keysReleased=true`, `virtualNeutral=true`, `virtualReleased=true`, `motorsStopped=true`, `clean_shutdown=true`). Phase 5 ordinary-user operation remains unqualified: an earlier non-elevated run reached `RUNNING`, then reported `backend_create_failed:Access is denied` with no SDK call-stage context. Do not rerun Phase 1 research or the previously accepted Phase 4 test.

The current source adds a phase prefix to unexpected SDK creation exceptions. The user's 14:40Z foreground diagnostic launch opened WinUSB but received no complete controller report, repeated `DEVICE_LOST` 30 times, and stopped with `clean_shutdown=true`; it never reached backend creation. Their output showed `unclean_previous_session=false`. A stale marker from the separate Codex execution-profile attempt is not evidence about the user's runtime path.

The verified package identifies branch `feature/chatpad-usermode-runner` and commit `ff6dcad52aaa2da486fbe5f354d6923bc412ab39`; independent verification passed all 27 package manifest hashes/lengths, the exact package file set, and 18 readiness hashes. In a normal non-elevated foreground PowerShell, first press Xbox or A to wake the controller, then run:

```powershell
& "C:\Dev\chatpad-super-driver\artifacts\task-8lc4\build-task-8lc4l1-normal-user-phase5-final\package\ChatpadBridge.exe" run
```

Wake the controller with Xbox or A before launch. If it reaches `RUNNING`, qualify buttons, both sticks, both triggers, Chatpad ordinary/Shift/Green/Orange/Space/Backspace/Enter, physical rumble, and simultaneous input; stop gracefully with Ctrl+C. If helper creation fails, preserve the complete output including the `phase:ExceptionType:message` prefix. If no full controller report arrives despite waking the controller, stop and investigate the physical read path separately; do not interpret that as a backend failure.

Use the exact failure phase to investigate the operation and normal-user rights. Do not weaken the metadata/index guards, alter ACLs, elevate the runner, or add a privileged broker without a source-backed root cause and separately scoped design. Continue the remaining lifecycle phases only after normal-user core runtime is qualified. Keep the completed 14:16Z graceful-stop evidence; the interrupted diagnostic run is not an accepted lifecycle result.

Still within TASK 8L-C4L1 after Phase 5: lifecycle unplug/start and three reconnect tests, held-state disconnect, unexpected process-kill cleanup, repeated physical rumble, and resource sampling; investigate the known Xbox player LED command only after those core tests. Then perform the authorized exact Microsoft `xusb22` recovery once near the end and restore the intended WinUSB state. Publish the requested sanitized evidence atomically with sidecar last, include ZIP and useful standalone files, update continuity docs, commit/push the requested branch, and do not start reboot/sleep/long-idle testing.

Preconditions and safety:

- Use only the exact qualified package built from the committed HEAD; no installed Program Files runner fallback.
- Preserve `TESTSIGNING=false`, `HVCI=true`, strict physical/runtime identity guards, and the original recovery material.
- Do not remove unrelated PnP devices, change trust/security policy, or run the virtual runner elevated to bypass Phase 5.
- No reboot/sleep/long-idle test during this continuation.

Inspect first: `docs/PROJECT-STATE.md`, this file, the latest `docs/WORKLOG.md` entry, `tools/ChatpadVirtualXbox/HidMaestroBackend.cs`, and the exact build manifest/readiness/package hashes.
