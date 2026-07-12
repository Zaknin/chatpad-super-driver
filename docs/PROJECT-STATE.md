# Project State

*Last updated: 2026-07-13 (TASK 8J-R6 xusb22 control-pipe reuse)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the 1.0.9 correction commit has parent `f9bb8b7a920c62af2ab5063ddb35de367d97ed44`, subject `fix: reuse xusb22 control pipe`, and final hash derived from Git after commit.
- **Accepted live 1.0.8 state:** selected `oem99.inf` is version 1.0.8.0. Exact loaded SYS is 65,384 bytes / `C5A3FE785768C550211B61EBB35BA1D6FDA9D4884481EE62C1ACF4B526C6734E`, Valid under the existing certificate. `xusb22`, `ChatpadFilter`, and `vhf` are RUNNING; the controller stack and exact device remain healthy; the operator confirms normal controller operation and no Chatpad input. Transport architecture is 3 and no relevant Code Integrity event exists.
- **First failing stage:** VHF/interface/input-pipe discovery succeed, but activation step 0 returns NTSTATUS `0xC000000D` and USBD `0x80000600` with zero bytes. WDK maps these to `STATUS_INVALID_PARAMETER` and `USBD_STATUS_INVALID_PIPE_HANDLE`; current optional stage 5 proves only step 0 ran. Registry values for later steps are stale from prior boots.
- **Concrete cause:** version 1.0.8 correctly built a generic raw setup-packet control URB but set `UrbControlTransfer.PipeHandle = NULL`. Generic control transfers require the configured default-control pipe handle. The retained WDF USB helper supplied that handle internally; the lower filter must observe and reuse xusb22's existing handle without claiming configuration ownership.
- **1.0.9 correction:** capture the first non-null control pipe from forwarded xusb22 control URBs, gate activation until it and interface-2 pipe 0 are known, and use it for all raw activation URBs. Transport architecture is 4. ReleaseHardware clears the handle. New bounded markers record `ControlPipeFound`, current activation generation, and last attempted step. Requests, strict write/final-probe policy, one-shot behavior, fail-open controller forwarding, VHF, and input decoding are unchanged.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.9.0`; VHF child version `0x0109`.
- **Final ignored package:** `artifacts/task-8j-r6-control-pipe-reuse-package/final` contains exactly: INF 1,590 bytes / `61EA24180806FA5095A2DC60A6527E4FC9077A50486B1F251CECB97D4EED4DDF`; SYS 65,896 bytes / `F850AA725AF40DBA62981B253C90036CC85A5A07698CE0BDF3ADD82BDBFB761D`; CAT 2,961 bytes / `780093B69E37E24F192DDA5077F9AB7EA0F761D5B654C810A28A6C2A25DA8A0E`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; Authenticode and exact INF/SYS catalog membership pass. No certificate was created or imported.
- **Validation:** Release x64 Universal KMDF build; protocol/HID/activation/fail-open 731/731; focused runtime 31/31 in PowerShell 7 and Windows PowerShell; physical lifecycle 109/109; request-owner model 5002/5002 and KMDF guard 62/62; WDF setup; kernel compatibility; production linkage; canonical source contract 29/29 in both runtimes; repository safety; InfVerif; Inf2Cat; signatures and catalog membership pass. InfVerif warning 1384 remains intentional for mandatory VHF order.
- **Safety / functional status:** live 1.0.8 inspection was read-only. Version 1.0.9 was not staged, installed, loaded, or executed. No device restart/reboot, certificate/trust, BCD, HVCI, or Secure Boot mutation occurred. Functional Chatpad success remains unclaimed pending one 1.0.9 installation and real key test.

## Next action

TASK 8J-R6-T1 — remove installed 1.0.8 `oem99.inf`, install exact 1.0.9 once, reboot if requested, verify control-pipe capture and current activation attempt, then test the controller and real Chatpad.
