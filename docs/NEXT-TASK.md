# Next Task

## TASK 8J-R7-T1 — Upgrade once to 1.0.10 and test endpoint-zero activation

### Starting state

- Use pushed branch `feature/chatpad-kmdf-live-activation-runtime` at the commit with parent `83339991b27a2e86696132e81e09bf774e4ee0ef` and subject `fix: use endpoint-zero default pipe flag`.
- Installed `oem99.inf` is version 1.0.9.0. The Xbox controller is healthy, but `ControlPipeFound=0` proves its impossible non-null endpoint-zero handle gate prevented a current activation attempt.
- The exact signed 1.0.10 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact single operator command

Run once from elevated PowerShell:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-r7-default-pipe-flag-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat a successful command. If PnPUtil returns `3010` or requests a reboot, reboot once before verification.

### Verification

- Confirm the newly published INF is selected at version 1.0.10.0 and the Driver Store SYS has the exact signed identity from `docs/PROJECT-STATE.md`.
- Confirm the Xbox controller remains healthy and the physical stack still contains `xusb22`, `ChatpadFilter`, and `vhf`.
- Confirm transport architecture 5 and `DefaultPipeTransferFlag=1`.
- Use `ActivationAttemptGeneration` and `ActivationLastAttemptedStep` to distinguish the current attempt from stale persisted values.
- Inspect all current activation NTSTATUS/USBD/byte results, `ActivationCompleted`, reader start, first input/raw packet/decode, and first VHF submission.
- Test ordinary, Shift, and two-key Chatpad input in Notepad while confirming normal Xbox operation.
- Claim functional success only from the real key test with a healthy controller.

### Restrictions

- No repeated install, automatic retry, certificate/trust change, BCD change, rebuild, or resign.
- Do not infer functional success from activation return codes alone.
