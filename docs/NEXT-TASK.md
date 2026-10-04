# Next Task

## TASK 8L-C4L2 — Package scope-conflict instance diagnostics and retry

- Branch: `feature/chatpad-usermode-runner`; starting commit `349f2ea1777048022b9a95f29e2be91c551da83f` plus uncommitted focused diagnostic changes.
- Two normal-user runs using `build-broker-create-failure-299569e` passed physical WinUSB and Chatpad activation, then failed virtual controller creation with `virtual_scope_conflict`. Immediately after both failures, read-only Configuration Manager queries found no present ROOT/SWD index-zero devnode; one stale HIDMaestro SWD Enum record remains non-present. Do not delete it or weaken the fail-closed guard.
- Implemented changes: include the exact conflicting instance ID in the guard fault; isolate the pipe-squatter test with a per-test temporary pipe name, retaining `FILE_FLAG_FIRST_PIPE_INSTANCE` behavior. Managed self-test passed 158/158 on pinned .NET 10.

### Offline release gate

1. Inspect the diff and append exact red/green, build, and live findings to `docs/WORKLOG.md`.
2. Commit implementation and continuity files; push only `origin/feature/chatpad-usermode-runner`.
3. Build a fresh package from that commit, run focused managed and native broker/client lifecycle checks, verify all package member SHA-256 values, and generate a truthful release-verification summary.
4. Use `tools/Publish-ChatpadC4L2.ps1` Prepare/Publish and its atomic publisher for a fresh UTC destination under `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\`; independently verify payload sidecars and receipt. Never publish a failed/partial verification as PASS.

### User live step

After the new package is published, ask the user to run the exact elevated `ChatpadSetup.ps1 -Mode RepairBroker` command for that package. Then have them launch `ChatpadBridge.exe run` from ordinary PowerShell. If `virtual_scope_conflict` repeats, the new fault detail must identify the exact node; stop before any device cleanup and investigate its presence and owner read-only.

Acceptance remains broker creation and service survival, XInput/buttons/sticks/triggers, Chatpad, physical rumble callback, clean shutdown, then reconnect/crash recovery. Do not run the bridge elevated or mutate devices/PnP/registry/trust, stop the service, or reboot.

Inspect first: latest TASK 8L-C4L2 entries in `docs/WORKLOG.md`, `tools/ChatpadVirtualXbox/EnumControllerIndexGuard.cs`, `HidMaestroBackend.cs`, `BrokerPipeServer.cs`, and `OfflineTests.cs`.
