# Next Task

## TASK 8J-T1 — Manual package upgrade and live functional verification

### Starting state

- Start from the published `feature/chatpad-kmdf-live-activation-runtime` implementation commit whose parent is `6ab488a970eb0e1817959bd752ce60b046064692`.
- The existing installed package is `oem96.inf`; the TASK 8J package is not staged or installed.
- The ignored final package directory contains exactly the signed 1.0.1.0 INF/SYS/CAT identities recorded in `docs/PROJECT-STATE.md`.

### Operator action

From one elevated PowerShell or Command Prompt, run exactly once:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8j-chatpad-live-activation-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat the command if PnPUtil reports success with exit code `3010`. A device restart or full reboot is expected because the old lower-filter binary can remain loaded until the controller stack is rebuilt; if Windows requests a reboot, reboot once.

### Verification

- Confirm the newly published INF is version `1.0.1.0`, the `ChatpadFilter` service uses the new signed SYS, the exact controller node has `CM_PROB_NONE`, and the physical stack still contains both `xusb22` and `ChatpadFilter`.
- Confirm no Code Integrity rejection and inspect bounded `ChatpadLive` diagnostics for device match, configuration, six successful activation steps, activation completion, and first valid input.
- Verify the Xbox controller still functions normally.
- In Notepad, test multiple base letters, digits, Space, Enter, Backspace, Left/Right, Shift make/break, simultaneous two-key behavior, and release behavior.
- Classify functional success only from the operator's real key test. Green/Orange/People symbol layers are not implemented in this package.

### Restrictions

- Do not reinstall automatically, create a certificate, repeat trust imports, modify BCD, resign, rebuild, or claim functional success from signatures, driver load, or activation return codes alone.
- If activation fails, report the first failing step, NTSTATUS, transferred bytes, and relevant bounded diagnostics before changing code.
