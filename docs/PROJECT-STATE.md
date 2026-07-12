# Project State

*Last updated: 2026-07-12 (TASK 8J KMDF work-item correction)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the KMDF correction commit containing this state has parent `6b61111c3c30a03596c3d4ec67f082e4d5a5d097`, subject `fix: correct KMDF work-item attributes`, and final hash derived from Git after commit.
- **Observed 1.0.3 live state:** `oem99.inf` version 1.0.3.0 is selected. `vhf` is running and present beneath `xusb22`, but `ChatpadFilter` is stopped and absent. The controller chain remains present with `CM_PROB_NONE`, normal Xbox function is confirmed by the operator, and no relevant Code Integrity rejection exists.
- **Exact first failure:** service-level diagnostics prove DeviceAdd, hardware-ID query/match, and spin-lock creation succeeded. `WdfWorkItemCreate` for the activation worker returned `0xC0200211`, `STATUS_WDF_EXECUTION_LEVEL_INVALID`; initialization then failed and PnP removed the optional Chatpad filter.
- **1.0.4 correction:** removed `attributes.ExecutionLevel = WdfExecutionLevelPassive` from all three `WDFWORKITEM` object attributes. KMDF framework work-item objects do not accept that explicit object attribute; their callbacks execute through the system work-item mechanism. The valid device parent remains assigned.
- **VHF/transport:** ordered device lower filters remain `ChatpadFilter, vhf`. Configuration/interface IRPs are forwarded unchanged and observed on completion; existing interface 2 pipe 0 is used for bounded raw vendor/input URBs. Ordinary controller traffic remains direct pass-through.
- **Diagnostics:** early and runtime stage values persist at `Services\ChatpadFilter\Parameters\ChatpadRuntimeDiagnostics`.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.4.0`; VHF child version `0x0104`.
- **Final ignored package:** `artifacts/task-8j-kmdf-workitem-correction-package/final` contains exactly: INF 1,590 bytes / `2C138EECF6E1DA7E887276703BA55A11A17F2C56E3617CAC24E413D2EF9D928D`; SYS 61,288 bytes / `B40F46C06832C95F7DF0EE1BB0E4132B62E397E75BB365E63EA42E392114B9FF`; CAT 2,951 bytes / `5FC60BE5ACC5AC3A1BAE758C9777729E8D9AA35B36A281724AC3ED4BD3F63FDF`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; Authenticode and exact catalog membership pass. No certificate, trust, BCD, Secure Boot, or HVCI state changed.
- **Validation:** Release x64 WDK build, Inf2Cat, focused runtime 24/24, canonical source contract 29/29, production linkage, repository safety, signatures, and catalog membership pass. The broader protocol 630/630, lifecycle 109/109, request-owner 62/62, kernel compatibility, and WDF setup regressions remain passing from the immediately preceding 1.0.3 correction; the 1.0.4 change is confined to three invalid work-item attribute assignments and version identities. InfVerif continues to pass with intentional warning 1384 for mandatory ordered VHF registration.
- **Safety:** the 1.0.4 package was not staged, installed, loaded, or executed. Live inspection was read-only; no restart or reboot was performed by Codex.
- **Functional status:** TASK 8J remains functionally incomplete pending operator installation/reboot and real Chatpad testing.

## Next action

TASK 8J-T4 — install the single 1.0.4 KMDF correction, reboot if requested, then inspect the now-persistent work-item/VHF/configuration/activation/input stages and test real keys.
