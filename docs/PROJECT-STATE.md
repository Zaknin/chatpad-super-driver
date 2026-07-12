# Project State

*Last updated: 2026-07-12 (TASK 8J VHF stack correction)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the VHF correction commit containing this state has parent `6d63deb907be5150baedc96fff3832a45f457b2b`, subject `fix: add required VHF lower filter`, and final hash derived from Git after commit.
- **Observed 1.0.2 live state:** after installation and reboot, `oem98.inf` version `1.0.2.0` is selected. Its Driver Store SYS is the exact signed 61,288-byte package binary, but `ChatpadFilter` remains stopped and absent from the exact physical stack. The exact controller and descendants are present with `CM_PROB_NONE`; normal `xusb22` operation is preserved. The declarative `ChatpadFilter` registration is present, no relevant Code Integrity rejection exists, and no runtime diagnostics key was created.
- **Concrete cause:** the 1.0.2 INF linked and called VHF but did not install the required Microsoft `vhf` lower filter beneath the Chatpad HID source driver. `VhfCreate` failure remained fatal in `PrepareHardware`, so PnP removed the optional Chatpad filter while leaving the healthy function-driver stack running. Microsoft documents `vhf.sys` as a mandatory lower filter for a VHF source driver.
- **1.0.3 correction:** the INF now uses one ordered, non-destructive `LowerFilters` append containing `ChatpadFilter` followed by `vhf`. Position-only declarative registration was removed because `xusb22` defines no named filter levels and Windows otherwise makes same-position ordering arbitrary. Diagnostics now use `Services\ChatpadFilter\Parameters\ChatpadRuntimeDiagnostics`, which is writable before device start.
- **Transport/runtime:** original configuration and interface URBs are forwarded unchanged and observed on completion; only the existing interface 2 pipe 0 handle is captured. Vendor/input URBs are submitted through the next-lower target. Ordinary controller traffic remains direct pass-through. One activation attempt is consumed per D0 generation and removal rundown is bounded.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.3.0`; VHF child version `0x0103`.
- **Final ignored package:** `artifacts/task-8j-vhf-stack-correction-package/final` contains exactly: INF 1,590 bytes / `62FBE1F25D1C36E867E26E26CE7B0DCDA890E8E4D53F1E62C0C646678596CCD7`; SYS 61,288 bytes / `8E577DB91FB5CB293B6D8AEBB486FC4C9FBE730B0F0D4A1062A6B6B7C7AA2388`; CAT 2,951 bytes / `617494A43BBD6598963DF96CD1293D92C3C129A554E4E371D230430619FBE662`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; Authenticode and exact INF/SYS catalog membership pass. No certificate, trust, BCD, Secure Boot, or HVCI state was changed.
- **Validation:** Release x64 WDK build, Inf2Cat, protocol/HID/live-transfer 630/630, lifecycle 109/109, request-owner 62/62, live-runtime 24/24, kernel compatibility, WDF setup, production linkage, canonical source contract 29/29, repository safety, signature, and catalog membership pass. InfVerif passes with warning 1384 because an Extension INF uses ordered legacy `LowerFilters`; this is intentional because Microsoft requires exact VHF-below-source ordering while the base `xusb22` INF exposes no named levels.
- **Safety:** the 1.0.3 package was not staged, installed, loaded, or executed. No device restart or reboot occurred during this correction. Installed `oem98.inf` remains unchanged.
- **Functional status:** TASK 8J remains functionally incomplete. Real success requires operator installation of 1.0.3, reboot if requested, live stack/diagnostic inspection, and manual key testing.

## Next action

TASK 8J-T3 — install the single 1.0.3 VHF-stack correction, reboot if requested, verify stack order `xusb22 -> ChatpadFilter -> vhf`, inspect persisted stages, and test real Chatpad keys.
