# Next Task

## TASK 8J-T4 — Install and live-test the 1.0.4 KMDF work-item correction

### Starting state

- Start from the pushed correction commit on `feature/chatpad-kmdf-live-activation-runtime` whose parent is `6b61111c3c30a03596c3d4ec67f082e4d5a5d097`.
- Installed `oem99.inf` version 1.0.3.0 correctly loads `vhf`, but `ChatpadFilter` is removed after activation-work-item creation returns `STATUS_WDF_EXECUTION_LEVEL_INVALID`.
- The ignored signed 1.0.4 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact operator action

Run exactly once from an elevated PowerShell or Command Prompt:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-kmdf-workitem-correction-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat the command after success. If PnPUtil returns `3010` or requests reboot, reboot once before verification.

### Verification

- Confirm selected version 1.0.4.0 and exact Driver Store SYS identity.
- Confirm `ChatpadFilter` and `vhf` are both running and the physical stack contains `xusb22`, `ChatpadFilter`, and `vhf` with all problem codes 0.
- Read `HKLM\SYSTEM\CurrentControlSet\Services\ChatpadFilter\Parameters\ChatpadRuntimeDiagnostics`; report the first absent or failing value after `ActivationWorkerCreateNtStatus` through VHF, configuration/interface 2/pipe 0, six activation transfers, reader, raw packet, decode, and HID submission.
- Verify normal Xbox controller operation and test real Chatpad keys in Notepad.
- Claim functional success only if keyboard input appears and controller behavior remains healthy.

### Restrictions

- No repeated install, certificate/trust change, BCD change, automatic retry, rebuild, or resign.
- Do not infer functional success from stack loading or diagnostics alone.
