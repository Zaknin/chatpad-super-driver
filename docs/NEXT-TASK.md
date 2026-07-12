# Next Task

## TASK 8J-R4-T1 — Upgrade once to 1.0.7 and reach the activation write

### Starting state

- Use pushed branch `feature/chatpad-kmdf-live-activation-runtime` at the commit with parent `c8e1aee56d77bdee268bd8614244e70aaa548c0c` and subject `fix: advance past stalled activation probe`.
- Installed `oem99.inf` is version 1.0.6.0. It preserves the controller, accepts activation steps 0-2, and stops on the zero-byte `STALL_PID` from initial read probe step 3 before sending `09 00`.
- The ignored signed 1.0.7 package identities are recorded in `docs/PROJECT-STATE.md`.

### Exact operator cleanup

Run once from an elevated PowerShell or Command Prompt:

```powershell
pnputil /delete-driver oem99.inf /uninstall /force
```

### Exact single installation

After successful cleanup, run exactly once:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-r4-initial-probe-stall-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat either successful command. If PnPUtil returns `3010` or requests reboot, reboot once before verification.

### Verification

- Confirm selected version 1.0.7.0 and exact Driver Store SYS identity.
- Confirm the controller chain remains healthy and the stack remains `xusb22 -> ChatpadFilter -> vhf`.
- Require steps 0-3 to retain their raw stall results and record `ActivationStepNExpectedStall=1`.
- Inspect exact step-4 `09 00` write and step-5 final-probe NTSTATUS, USBD status, and byte counts. Neither may be accepted as a stall.
- Inspect `ActivationCompleted`, reader start, first input completion/raw packet, decoder result, and first VHF keyboard submission.
- Verify normal Xbox operation and test ordinary, Shift, and two-key Chatpad input in Notepad.
- Claim functional success only if real Chatpad keys produce keyboard input and the controller remains healthy.

### Restrictions

- No repeated cleanup/install, automatic retry, certificate/trust change, BCD change, rebuild, or resign.
- Do not infer functional success from reaching the activation write, activation completion, or driver return codes alone.
