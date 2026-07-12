# Next Task

## TASK 8J-R8-T1 — Upgrade once to 1.0.11 and test readiness-gated activation

### Starting state

- Use pushed branch `feature/chatpad-kmdf-live-activation-runtime` at the commit with parent `5317f5ff21e755910d3ada247b2faad59ab4b417` and subject `fix: wait for live controller traffic before activation`.
- Installed selected extension is `oem100.inf` version 1.0.10.0. The controller is healthy; the correct revision-1.14 `09 00` activation write stalls because the one shot runs without a completed-parent-controller-traffic readiness gate.
- Exact signed 1.0.11 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact single operator command

Run once from elevated PowerShell:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-r8-controller-input-readiness-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat a successful command. If PnPUtil returns `3010` or requests a reboot, reboot once before verification.

### Verification

- Confirm the newly published INF is selected at version 1.0.11.0 and the Driver Store SYS has the exact signed identity from `docs/PROJECT-STATE.md`.
- Confirm the Xbox controller remains healthy and the stack still contains `xusb22`, `ChatpadFilter`, and `vhf`.
- Confirm transport architecture 6, `ControllerInputPipeFound=1`, `ControllerInputReady=1`, successful controller-input completion status/USBD, and a nonzero completion byte count.
- Confirm `ActivationAttemptGeneration` is current and inspect all actually attempted activation results, `ActivationCompleted`, reader start, first input/raw packet/decode, and first VHF submission.
- Test ordinary, Shift, and two-key Chatpad input in Notepad while confirming normal Xbox operation.
- Claim functional success only from the real key test with a healthy controller.

### Restrictions

- No repeated install, automatic retry, alternate revision-1.10 payload, certificate/trust change, BCD change, rebuild, or resign.
- Do not infer functional success from readiness or activation return codes alone.
