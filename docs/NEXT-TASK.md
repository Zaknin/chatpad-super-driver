# Next Task

## TASK 8J-T3 — Install and live-test the 1.0.3 VHF-stack correction

### Starting state

- Start from the pushed `feature/chatpad-kmdf-live-activation-runtime` VHF correction commit whose parent is `6d63deb907be5150baedc96fff3832a45f457b2b`.
- Installed `oem98.inf` version `1.0.2.0` is selected, but both `ChatpadFilter` and `vhf` are stopped and absent from the exact physical stack.
- The ignored 1.0.3 package contains the exact signed INF/SYS/CAT identities recorded in `docs/PROJECT-STATE.md`.

### Exact operator action

From one elevated PowerShell or Command Prompt, run exactly once:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-vhf-stack-correction-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat the command after success. If PnPUtil returns `3010` or requests a reboot, reboot once before verification.

### Verification

- Confirm the new selected extension is version `1.0.3.0` and its Driver Store SYS matches the package.
- Confirm both `ChatpadFilter` and `vhf` are loaded and the exact physical stack places `ChatpadFilter` above `vhf`, beneath `xusb22`; all exact device-chain problem codes must remain 0.
- Read `HKLM\SYSTEM\CurrentControlSet\Services\ChatpadFilter\Parameters\ChatpadRuntimeDiagnostics` and report the first absent or failing stage through configuration, interface 2/pipe 0, six activation transfers, reader, raw packet, decode, and VHF submission.
- Confirm no relevant Code Integrity rejection and verify the Xbox controller still operates normally.
- In Notepad, test ordinary keys, digits, Space, Enter, Backspace, arrows, Shift make/break, simultaneous two-key behavior, and release behavior.
- Claim functional success only if real keyboard input appears and the Xbox controller remains healthy.

### Restrictions

- Do not repeat certificate imports, create a certificate, modify BCD, rebuild, resign, or automatically retry installation.
- Do not claim functional success from stack loading, activation results, raw packets, or VHF submission alone.
- If the Chatpad remains inactive, report the first persisted failing stage before another code change.
