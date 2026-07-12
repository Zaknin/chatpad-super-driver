# Project State

*Last updated: 2026-07-13 (TASK 8J-R8 controller-input readiness correction)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the 1.0.11 correction commit has parent `5317f5ff21e755910d3ada247b2faad59ab4b417`, subject `fix: wait for live controller traffic before activation`, and final hash derived from Git after commit.
- **Accepted live 1.0.10 state:** `oem100.inf` version 1.0.10.0 is the selected extension. Exact loaded SYS is 65,384 bytes / `12890141238BDC54E0BDDE31A0B0A4CEA598D5889AFCFC524E5D215178CE20E3`, Valid under existing certificate `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`. `xusb22`, `ChatpadFilter`, and `vhf` run; exact controller, IG_00, and HID nodes are `CM_PROB_NONE`; the controller works normally; the Chatpad produces no input; no relevant Code Integrity rejection exists.
- **First failing stage:** transport architecture 5 reaches a current generation-1 activation attempt. Steps 0-3 return their accepted zero-byte `USBD_STATUS_STALL_PID` results. Exact step 4 (`40 A1 0000 E416 0002` plus `09 00`) returns NTSTATUS `0xC0000001`, `USBD_STATUS_STALL_PID`, zero bytes, and strict optional stage 9. `ActivationCompleted=0` and `ReaderStarted=0`; no input, decode, or keyboard submission follows.
- **Revision/payload check:** the physical controller reports `USB\VID_045E&PID_028E&REV_0114`. Independent xboxdrv protocol/source records `09 00` for revision 1.14 and `01 02` only for revision 1.10, so changing this unit to the alternate payload is rejected.
- **Concrete lifecycle defect:** version 1.0.10 consumes its only attempt directly from D0/configuration readiness, without evidence that xusb22 has completed normal controller initialization traffic. The retained working Windows route activates later from user mode, and its earlier readiness detector observed completed controller input. A fixed delay or retry would not prove readiness.
- **1.0.11 correction:** retain the exact configured interface-0 input pipe identity without reading or owning it. D0 arms but cannot consume activation. The first successful, non-empty parent xusb22 transfer completion on that exact pipe atomically records `ControllerInputReady=1` and queues the unchanged one-shot activation. All parent traffic is forwarded unchanged. Transport architecture is 6; diagnostics include controller pipe discovery and the first readiness completion status/USBD/byte count.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.11.0`; VHF child version `0x010B`.
- **Final ignored package:** `artifacts/task-8j-r8-controller-input-readiness-package/final` contains exactly: INF 1,591 bytes / `1899E01EE570BE24CFC41BA7B974F897E9CA64CF96175FD282AB2B0FBD06BACE`; SYS 66,920 bytes / `31008FE885D0542D2DB1A5848B9E07704E13E58EB6EEFD8A1FF16EEA33E34371`; CAT 2,961 bytes / `881EB20954665647AD7A366D74BD654EE40D34C34A23EF94C00156645BA0CD9F`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by the existing certificate; Authenticode `/pa` and exact INF/SYS catalog membership pass. No certificate was created or imported.
- **Validation:** Release x64 Universal KMDF build; protocol/HID/activation/fail-open 731/731; focused runtime 32/32 in PowerShell 7 and Windows PowerShell; physical lifecycle 109/109; request-owner model 5002/5002 and KMDF guard 62/62; WDF setup; kernel compatibility; production linkage; canonical source contract 29/29 in both runtimes; repository safety; InfVerif; Inf2Cat; signatures and catalog membership pass. InfVerif warning 1384 remains intentional for mandatory VHF ordering.
- **Safety / functional status:** live 1.0.10 inspection was read-only. Version 1.0.11 was not staged, installed, loaded, or executed. No device restart/reboot, certificate/trust, BCD, HVCI, or Secure Boot mutation occurred. Functional Chatpad success remains unclaimed pending one 1.0.11 installation and real key test.

## Next action

TASK 8J-R8-T1 — install exact 1.0.11 once, reboot once if requested, prove controller-input readiness precedes the current activation attempt, then test the controller and real Chatpad.
