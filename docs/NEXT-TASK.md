# Next Task

## TASK 8J-R10-T1 — Upgrade once to 1.0.13 and test key-data enable after the first Chatpad packet

### Starting state

- Use pushed branch `feature/chatpad-kmdf-live-activation-runtime` at the commit with parent `8cd5547468347d2a8a7348080069917dbb559774` and subject `fix: enable chatpad key data after first packet`.
- Installed selected extension is `oem102.inf` version 1.0.12.0. The controller is healthy. Activation and keep-alives succeed and a five-byte `F0 03 00 01 01` status packet is received, but the required post-first-packet `0x001B` key-data enable command is absent.
- Exact signed 1.0.13 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact single operator command

Run once from elevated PowerShell:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-r10-first-packet-backlight-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat a successful command. If PnPUtil returns `3010` or requests a reboot, reboot once before verification.

### Verification

- Confirm the newly published INF is selected at version 1.0.13.0 and the Driver Store SYS has the exact signed identity from `docs/PROJECT-STATE.md`.
- Confirm the Xbox controller remains healthy and the stack still contains `xusb22`, `ChatpadFilter`, and `vhf`.
- Confirm transport architecture 8, readiness, activation, keep-alive, and reader stages remain successful.
- Confirm `BacklightCommandSent=1` and its NTSTATUS/USBD/byte result is successful/successful/zero.
- Inspect the first packet after the command, the first accepted decoder result, and first key-bearing VHF submission.
- Test ordinary, Shift, and two-key Chatpad input in Notepad while confirming normal Xbox operation.
- Claim functional success only from the real key test with a healthy controller.

### Restrictions

- No repeated install, automatic activation or command retry, decoder relaxation for `0xF0`, alternate revision-1.10 payload, certificate/trust change, BCD change, rebuild, or resign.
- Do not infer functional success from command, packet, decoder, or VHF return codes alone.
