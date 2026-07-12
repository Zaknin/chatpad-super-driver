# Next Task

## TASK 8J-R5-T1 — Upgrade once to 1.0.8 and test raw control-transfer activation

### Starting state

- Use pushed branch `feature/chatpad-kmdf-live-activation-runtime` at the commit with parent `f18dc2857f50f55fa255971ba750fa198834810f` and subject `fix: use raw control transfer URBs`.
- Installed `oem99.inf` is version 1.0.7.0. It preserves the controller but its specialized vendor-device URB for the step-4 `09 00` write returns zero-byte `STALL_PID`.
- The ignored signed 1.0.8 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact operator commands

Run each successful command once from elevated PowerShell:

```powershell
pnputil /delete-driver oem99.inf /uninstall /force
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-r5-raw-control-transfer-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat either successful command. If PnPUtil returns `3010` or requests reboot, reboot once before verification.

### Verification

- Confirm selected version 1.0.8.0 and exact Driver Store SYS identity.
- Confirm the controller chain remains healthy and transport architecture is 3.
- Inspect all six setup/result records, especially strict step-4 `09 00` write and step-5 final probe.
- Inspect `ActivationCompleted`, reader start, first input completion/raw packet, decoder result, and first VHF keyboard submission.
- Verify normal Xbox operation and test ordinary, Shift, and two-key Chatpad input in Notepad.
- Claim functional success only if real Chatpad keys produce keyboard input and the controller remains healthy.

### Restrictions

- No repeated cleanup/install, automatic retry, certificate/trust change, BCD change, rebuild, or resign.
- Do not infer functional success from activation completion or driver return codes alone.
