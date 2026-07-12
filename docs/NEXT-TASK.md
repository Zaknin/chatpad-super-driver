# Next Task

## TASK 8J-R9-T1 — Upgrade once to 1.0.12 and test the post-activation keep-alive runtime

### Starting state

- Use pushed branch `feature/chatpad-kmdf-live-activation-runtime` at the commit with parent `e07e10930e965345fbfd454d8287f445d0ef1053` and subject `fix: sustain live chatpad input with keep-alives`.
- Installed selected extension is `oem101.inf` version 1.0.11.0. The controller is healthy. Readiness and all six activation steps succeed, but the first Chatpad input read times out because the required alternating post-activation keep-alives are absent.
- Exact signed 1.0.12 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact single operator command

Run once from elevated PowerShell:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-r9-chatpad-keepalive-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat a successful command. If PnPUtil returns `3010` or requests a reboot, reboot once before verification.

### Verification

- Confirm the newly published INF is selected at version 1.0.12.0 and the Driver Store SYS has the exact signed identity from `docs/PROJECT-STATE.md`.
- Confirm the Xbox controller remains healthy and the stack still contains `xusb22`, `ChatpadFilter`, and `vhf`.
- Confirm transport architecture 7, readiness, and the current six-step activation remain successful.
- Confirm `KeepAliveAttemptCount` is nonzero, the first keep-alive value is `0x001F`, and its NTSTATUS/USBD/byte result is successful/successful/zero.
- Inspect first input/raw packet/decode and first key-bearing VHF submission evidence.
- Test ordinary, Shift, and two-key Chatpad input in Notepad while confirming normal Xbox operation.
- Claim functional success only from the real key test with a healthy controller.

### Restrictions

- No repeated install, automatic activation retry, alternate revision-1.10 payload, certificate/trust change, BCD change, rebuild, or resign.
- Do not infer functional success from activation, keep-alive, input, decoder, or VHF return codes alone.
