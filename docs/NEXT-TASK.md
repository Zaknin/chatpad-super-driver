# Next Task

## TASK 8J-R6-T1 — Upgrade once to 1.0.9 and test captured control-pipe activation

### Starting state

- Use pushed branch `feature/chatpad-kmdf-live-activation-runtime` at the commit with parent `f9bb8b7a920c62af2ab5063ddb35de367d97ed44` and subject `fix: reuse xusb22 control pipe`.
- Installed `oem99.inf` is version 1.0.8.0. Its step-0 generic control URB fails with `USBD_STATUS_INVALID_PIPE_HANDLE` because the pipe handle is null.
- The ignored signed 1.0.9 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact operator commands

Run each successful command once from elevated PowerShell:

```powershell
pnputil /delete-driver oem99.inf /uninstall /force
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-r6-control-pipe-reuse-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat either successful command. If PnPUtil returns `3010` or requests reboot, reboot once before verification.

### Verification

- Confirm selected version 1.0.9.0 and exact Driver Store SYS identity.
- Confirm controller health, stack order, transport architecture 4, and `ControlPipeFound=1`.
- Use `ActivationAttemptGeneration` and `ActivationLastAttemptedStep` to distinguish current results from stale registry values.
- Inspect all current six activation outcomes, `ActivationCompleted`, reader start, first packet/decode, and first VHF submission.
- Test ordinary, Shift, and two-key Chatpad input while confirming normal Xbox operation.
- Claim functional success only from the real key test with a healthy controller.

### Restrictions

- No repeated cleanup/install, automatic retry, certificate/trust change, BCD change, rebuild, or resign.
- Do not infer functional success from pipe capture or activation return codes alone.
