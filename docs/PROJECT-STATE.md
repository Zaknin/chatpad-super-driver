# Project State

*Last updated: 2026-07-13 (TASK 8K legacy layers and configuration)*

## Current truth

- **Branch / base:** `feature/chatpad-legacy-layers-configuration` from exact known-good commit `dc246d29389ff52bd87f4dcd7751bd7c4693e009`. The TASK 8K commit is pending with subject `feat: add chatpad layers and configuration`.
- **Proven installed baseline:** `oem103.inf` version 1.0.13.0 remains installed and recoverable. Its loaded SYS SHA-256 is `45A727CE2658A8A9B5F1CC0B8654DF0C7A929244C929200DF66BD97EBABA5ACD`. Physical activation, keep-alive, `0x001B`, five-byte input, VHF submission, base keys, Shift, Space, Backspace, Enter, white backlight, Xbox coexistence, hotplug, USB-port moves, and held-key unplug release are proven.
- **TASK 8K mapping:** complete built-in Base mappings remain behavior-identical. A stateful mapper adds the deterministic standard-HID Green subset, Orange subset, and Orange+Shift Caps Lock while latching held actions across modifier release, supporting two keys, and clearing safely on malformed/unsupported input and forced release.
- **Configuration:** schema/ABI 1 uses fixed-size Base/Green/Orange arrays, QWERTY/QWERTZ/AZERTY profile labels, and People action `Disabled`. The KMDF surface exposes five fixed METHOD_BUFFERED IOCTLs with access bits; validation and apply are bounded and atomic. Invalid profiles preserve the active mapping. Unknown device-control requests continue unchanged to xusb22.
- **Companion:** native x64 `ChatpadControl.exe` supports status, config show/reset, profile list/apply/import/export, and diagnostics. Profiles are strict JSON under `%LOCALAPPDATA%\ChatpadSuperDriver\profiles\`; discovery requires exactly one active control interface.
- **Deferred:** layout-dependent Unicode legends, People actions beyond Disabled, full mouse mode, GUI/tray work, and the unresolved prolonged-idle/sleep loss remain deferred. Activation, keep-alive, USB ownership, power, reader lifecycle, and resume behavior were not changed for the idle issue.
- **Version:** canonical INF `DriverVer=07/13/2026,1.0.14.0`; VHF child version `0x010E`.
- **Final ignored package:** `artifacts/task-8k-legacy-layers-configuration-package/final` contains exactly INF 1,591 bytes / `FE35416537D432CDB37B0B9C967298F86B2EE636F02937DE3AAB0F1E91FFB274`; SYS 73,576 bytes / `16151F574AB93BEA556B08623D8450E48AF5F3308FA82E40FD5CFADBBA76E8C0`; CAT 2,961 bytes / `6D9724DF174383F37EB9DFC13C2A096BD067BD98F037F7C0A29F8292DD8F0732`.
- **Signing:** SYS and CAT are Valid SHA-256 signatures without timestamps from existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; exact INF/SYS catalog membership passes. No certificate was created, exported, imported, or trusted.
- **Companion artifact:** `artifacts/bin/x64/Release/ChatpadControl/ChatpadControl.exe`, 115,200 bytes / `1B55B5B5B132E7ADCC4D4222F0958CDFA7326F5EC98E0DB5CDCE4441FDF144C1`.
- **Validation:** Release x64 Universal KMDF build; protocol/layer tests 904/904; control/profile tests 15/15; focused runtime 42/42; lifecycle 109/109; request-owner model 5002/5002; KMDF guard 62/62; WDF setup; kernel compatibility; production linkage; owner initialization SourceOnly; canonical source contract 29/29 in PowerShell 7 and Windows PowerShell; repository safety; InfVerif; Inf2Cat; Authenticode and catalog membership pass. InfVerif warning 1384 remains the accepted consequence of mandatory ordered VHF filter registration.
- **Safety / functional status:** 1.0.14.0 was built and signed offline only. It was not staged, installed, loaded, or executed against hardware. No device query/restart, reboot, trust-store, BCD, Secure Boot, HVCI, VBS, or USB power mutation occurred. Green/Orange live functionality and any idle/sleep improvement are not claimed.

## Next action

TASK 8K-T1 — while physically present, preserve the 1.0.13 `oem103.inf` rollback identity, install exact signed 1.0.14 once, verify the healthy controller stack, exhaustively test Base/Green/Orange/configuration behavior, and preserve any idle/sleep failure state for diagnostics before rollback or recovery.
