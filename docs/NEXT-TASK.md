# Next Task

## TASK 8J-R3-T1 — Upgrade once to 1.0.6 and live-test expected preamble stalls

### Starting state

- Use pushed branch `feature/chatpad-kmdf-live-activation-runtime` at the commit with parent `33dd9aabefe1a7529a6de04cff71548c9c7328cc` and subject `fix: accept required activation preamble stalls`.
- Installed `oem99.inf` is version 1.0.5.0. It preserves the controller and proves VHF/interface/pipe setup, but stops at the expected step-0 `STALL_PID`.
- The ignored signed 1.0.6 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact operator cleanup

Run once from an elevated PowerShell or Command Prompt:

```powershell
pnputil /delete-driver oem99.inf /uninstall /force
```

If cleanup alone requires an immediate reboot, reboot once and confirm the Microsoft controller is healthy before continuing.

### Exact single installation

Run exactly once from an elevated PowerShell or Command Prompt:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-r3-expected-preamble-stall-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat either command after success. A restart/reboot is expected for lower-filter replacement; if PnPUtil returns `3010` or requests reboot, reboot once before verification.

### Verification

- Confirm selected version 1.0.6.0 and exact Driver Store SYS identity.
- Confirm controller, IG_00, HID and VHF keyboard child problem codes remain 0 and stack order remains `xusb22 -> ChatpadFilter -> vhf`.
- Require activation steps 0-2 to record their raw stall results plus `ActivationStepNExpectedStall=1`, then require steps 3-5 to execute with their exact NTSTATUS, USBD status and byte counts.
- Inspect `ActivationCompleted`, reader start, first input completion, raw five-byte packet, decode result, queue/submission state, and any first optional failure.
- Verify normal Xbox controller operation and test ordinary, Shift, and two-key Chatpad input in Notepad.
- Claim functional success only if Chatpad keys produce keyboard input and the controller remains healthy.

### Restrictions

- No repeated cleanup/install, automatic retry, certificate/trust change, BCD change, rebuild, or resign.
- Do not infer functional success from expected-stall acceptance or activation return codes alone.
