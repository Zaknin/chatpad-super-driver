# Next Task

## TASK 8J-T2 — Install and live-test the 1.0.2 transport correction

### Starting state

- Branch `feature/chatpad-kmdf-live-activation-runtime` contains the pushed correction commit with parent `f085d8642d4b4820970019d56f3d512a4a2783f9`.
- Installed `oem97.inf` version `1.0.1.0` is selected, but `ChatpadFilter` is stopped and absent from the exact controller stack.
- The ignored correction package contains the exact signed 1.0.2.0 INF/SYS/CAT identities recorded in `docs/PROJECT-STATE.md`.

### Exact operator action

From one elevated PowerShell or Command Prompt, run exactly once:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-live-transport-correction-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat the command after a successful add/install. A reboot is required if PnPUtil returns `3010` or says that a reboot is needed; reboot once before verification.

### Verification

- Confirm the selected published INF is version `1.0.2.0`, the loaded SYS matches the package, `ChatpadFilter` is running, and the exact controller stack contains both `xusb22` and `ChatpadFilter` with problem code 0.
- Read `HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_045E&PID_028E\1C21F10\ChatpadRuntimeDiagnostics`. Identify the first absent or failing stage from DeviceAdd through configuration/interface 2/pipe 0, VHF, six activation results, reader, first packet, decode, and HID submission.
- Confirm no relevant Code Integrity rejection and that the Xbox controller still works normally.
- In Notepad, test base letters, digits, Space, Enter, Backspace, Left/Right, Shift make/break, simultaneous two-key behavior, and key release.
- Classify functional success only from real keyboard input while the Xbox controller remains healthy. Green/Orange/People symbol layers remain outside this package.

### Restrictions

- Do not repeat certificate imports, create a certificate, modify BCD, rebuild, resign, or automatically retry installation.
- Do not claim functional success from package selection, driver load, activation status, input byte counts, or VHF submission alone.
- If keys remain inactive, use the persisted diagnostics to report the first concrete failing stage before changing code.
