# Next Task

## TASK 8L-C4L2 — Publish instance-diagnostic package, then retry live broker

- Implementation branch/commit: `feature/chatpad-usermode-runner` / `b621b2714ec133f2875d25d00c900da22866a95f`.
- Package: `artifacts/task-8lc4l2/build-scope-conflict-id-b621b27/package`; manifest has 214 members; independent path/length/SHA-256 readback is 214/214. Runner SHA-256 `3A0190A4A35982F78A4FDF7FD61C1088B71696D78A1A9EAB1305CB0EA7C0441D`; broker SHA-256 `28D9DA564EC7799F7DAFC2E9A0815712EF7B6976A1BF32E0027248D074F96B58`.
- Tests: managed 158/158; focused native broker/client and runner lifecycle 2/2; C4 setup and readiness checks passed; package/readiness/build identities match implementation commit.
- Prepared deterministic archive: `artifacts/task-8lc4l2/publication/20261004T194810Z/task-8l-c4l2-release.zip`, SHA-256 `05CD44BF7CE9A7A933DE078B5DD641992575F0874D4F3E097B3B5A610EBB0222`. Canonical destination is `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\20261004T194810Z`.
- Two normal-user runs with the previously installed package failed with `virtual_scope_conflict` after Chatpad activation. Immediate post-run device checks found no present ROOT/SWD index-zero device; exact transient instance remains unknown. New package includes that instance ID in the error while preserving fail-closed blocking.

### Remaining offline release steps

1. Commit and push the current continuity-only changes to `origin/feature/chatpad-usermode-runner`.
2. Run `tools/Publish-ChatpadC4L2.ps1 -Mode Publish -UtcTimestamp '20261004T194810Z' -BuildDirectory 'artifacts/task-8lc4l2/build-scope-conflict-id-b621b27' -VerificationSummaryPath 'artifacts/task-8lc4l2/build-scope-conflict-id-b621b27/release-verification.json'`.
3. Verify publication receipts, final `.sha256` sidecar, and canonical result manifest; append final path/hash evidence to continuity docs.

### Manual live step

After publication, user runs this from elevated PowerShell:

```powershell
& "C:\Dev\chatpad-super-driver\tools\ChatpadSetup.ps1" -Mode RepairBroker -PackageRoot "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\build-scope-conflict-id-b621b27\package" -ReadinessPath "C:\Dev\chatpad-super-driver\artifacts\task-8lc4l2\readiness-input.json"
```

Then launch the same package's `ChatpadBridge.exe run` in ordinary PowerShell. If `virtual_scope_conflict` repeats, capture the newly reported instance ID and investigate owner/presence read-only. Do not delete records/devices, weaken the guard, stop the service, or reboot. Continue acceptance only after successful virtual creation: XInput, controls, Chatpad, rumble, clean shutdown, then reconnect/crash recovery.

Inspect first: latest TASK 8L-C4L2 entries in `docs/WORKLOG.md`, the exact package build manifest, and the final publication receipt.
