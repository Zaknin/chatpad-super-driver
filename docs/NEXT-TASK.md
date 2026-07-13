# Next Task

## TASK 8K-T1 — Physical 1.0.14 layer/configuration validation and idle-failure capture

### Starting state

- Use pushed branch `feature/chatpad-legacy-layers-configuration` at the TASK 8K commit recorded in Git and `docs/PROJECT-STATE.md`.
- The proven recovery baseline is installed `oem103.inf` version 1.0.13.0 with loaded SYS SHA-256 `45A727CE2658A8A9B5F1CC0B8654DF0C7A929244C929200DF66BD97EBABA5ACD`.
- The exact signed 1.0.14 package and companion identities are recorded in `docs/PROJECT-STATE.md`. Do not rebuild or resign before testing.

### Preconditions

1. Be physically present with a keyboard, mouse, controller, Chatpad, and a text editor available.
2. Record the current `oem103.inf` package, loaded SYS identity, device status, stack, and rollback command before mutation.
3. Verify the three 1.0.14 package file hashes and both signatures/catalog memberships against `docs/PROJECT-STATE.md`.
4. Install the exact package once with:

```powershell
pnputil /add-driver "C:\Dev\chatpad-super-driver\artifacts\task-8k-legacy-layers-configuration-package\final\ChatpadFilterExtension.inf" /install
```

Do not repeat a successful install. Reboot only if Windows explicitly requires it.

### Acceptance procedure

1. Confirm the selected extension is 1.0.14.0, the loaded SYS matches the signed package, and controller, IG_00, HID, `xusb22`, `ChatpadFilter`, and `vhf` remain healthy.
2. Confirm normal Xbox input and every existing Base key class: ordinary letters/numbers, Shift, Space, Backspace, Enter, arrows, comma, period, and simultaneous keys.
3. Test every documented deterministic Green mapping, every deterministic Orange mapping, and Orange+Shift Caps Lock against `docs/LEGACY-FEATURE-INVENTORY.md` and built-in profile output.
4. Test both release orders, two simultaneous mapped keys, repeated reports, held-key typematic, hot unplug/reconnect, three USB-port moves, and unplug while holding a layered key. No virtual key or modifier may remain stuck.
5. Run `ChatpadControl.exe status`, `config show`, and `diagnostics`; export the built-in profile; import/apply a valid modified profile; prove the change; reset to defaults; and prove the original mapping returns.
6. Attempt unsupported schema, duplicate property/mapping, partial, oversized, unknown-action, and invalid-HID profiles. Every attempt must fail without changing the prior active profile or Xbox behavior.
7. Reproduce the prolonged-idle/sleep loss only after the core matrix passes. If typing stops, preserve the failed state and collect read-only diagnostics before unplugging, restarting, rebooting, or applying another profile.
8. If controller health, base input, release safety, or configuration recovery fails, stop and roll back to the preserved `oem103.inf` 1.0.13 baseline.

### Restrictions

- Do not remove `oem103.inf` before 1.0.14 validation and rollback proof are complete.
- Do not change activation, keep-alive, USB transfer ownership, power/resume behavior, selective suspend, trust, BCD, Secure Boot, HVCI, Memory Integrity, or VBS while diagnosing.
- Do not claim Green/Orange physical success or an idle/sleep fix until the corresponding real-hardware evidence exists.
