# Next Task

## TASK 8J-R2-T1 — Clean residual 1.0.3 and live-test the 1.0.5 fail-open VHF package

### Starting state

- Use pushed branch `feature/chatpad-kmdf-live-activation-runtime` at the commit with parent `85fdc5258e8cad99ba59a99acd3c669bb0d4d5f7` and subject `fix: isolate VHF from Xbox device startup`.
- The Microsoft controller stack is operational after `oem100.inf` removal; residual `oem99.inf` version 1.0.3.0 remains selected.
- The ignored signed 1.0.5 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact operator cleanup

Run once from an elevated PowerShell or Command Prompt:

```powershell
pnputil /delete-driver oem99.inf /uninstall /force
```

Do not run the install command until PnPUtil confirms the old package is removed. If cleanup alone requires an immediate reboot, reboot once and confirm the Microsoft controller is healthy before continuing.

### Exact single installation

Run exactly once from an elevated PowerShell or Command Prompt:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-r2-fail-open-vhf-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat the command after success. A restart/reboot is expected for lower-filter replacement; if PnPUtil returns `3010` or requests reboot, reboot once before verification.

### Verification

- Confirm selected version 1.0.5.0 and exact Driver Store SYS identity.
- Confirm `xusb22` remains running, all controller descendants have problem code 0, and the physical stack order places `ChatpadFilter` above `vhf`.
- Read `HKLM\SYSTEM\CurrentControlSet\Services\ChatpadFilter\Parameters\ChatpadRuntimeDiagnostics`. If VHF is unavailable, require physical start success, controller forwarding, `CHATPAD_VIRTUAL_KEYBOARD_UNAVAILABLE`, and the exact first optional failure stage/status rather than Code 10.
- If VHF starts, inspect interface 2 / pipe 0, all six activation results, input completion/raw packet/decode, queue, forced release, and first keyboard submission.
- Verify normal Xbox controller operation and test ordinary, Shift, and two-key Chatpad input in Notepad.
- Claim functional success only if keyboard input appears and controller behavior remains healthy.

### Restrictions

- No repeated cleanup/install, automatic retry, certificate/trust change, BCD change, rebuild, or resign.
- Do not infer functional Chatpad success from physical start, VHF start, or native return codes alone.
