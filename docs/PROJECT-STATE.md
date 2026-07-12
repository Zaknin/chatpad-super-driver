# Project State

*Last updated: 2026-07-13 (TASK 8J-R7 endpoint-zero default-pipe correction)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the 1.0.10 correction commit has parent `83339991b27a2e86696132e81e09bf774e4ee0ef`, subject `fix: use endpoint-zero default pipe flag`, and final hash derived from Git after commit.
- **Accepted live 1.0.9 state:** selected `oem99.inf` is version 1.0.9.0. Exact loaded SYS is 65,896 bytes / `F850AA725AF40DBA62981B253C90036CC85A5A07698CE0BDF3ADD82BDBFB761D`, Valid under existing certificate `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`. `xusb22`, `ChatpadFilter`, and `vhf` are running; exact controller, IG_00, and HID nodes have `CM_PROB_NONE`; the physical stack contains `xusb22 -> ChatpadFilter -> vhf`; the operator confirms normal Xbox operation and no Chatpad input. No relevant Code Integrity rejection exists.
- **First failing stage:** transport architecture 4 reports `ControlPipeFound=0`. `ActivationAttemptGeneration` and `ActivationLastAttemptedStep` are absent, proving no 1.0.9 activation attempt was consumed. Persisted activation results belong to earlier versions and are not current evidence.
- **Concrete cause:** endpoint zero does not expose a configured non-null pipe handle. The WDK requires `UrbControlTransfer.PipeHandle=NULL` together with `USBD_DEFAULT_PIPE_TRANSFER`. Version 1.0.8 used null correctly but omitted the mandatory flag, causing `USBD_STATUS_INVALID_PIPE_HANDLE`; version 1.0.9 incorrectly waited for a non-null endpoint-zero handle that xusb22 never emits.
- **1.0.10 correction:** remove control-handle capture and its activation gate; keep xusb22's selected configuration and observed interface-2 interrupt pipe unchanged; submit each exact raw setup-packet activation URB with a null handle and `USBD_DEFAULT_PIPE_TRANSFER`. Transport architecture is 5 and bounded `DefaultPipeTransferFlag=1` identifies the correction. One-shot activation, strict write/final-probe policy, normal Xbox forwarding, VHF, input decoding, and teardown remain unchanged.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.10.0`; VHF child version `0x010A`.
- **Final ignored package:** `artifacts/task-8j-r7-default-pipe-flag-package/final` contains exactly: INF 1,591 bytes / `F58CBFE3C534826D4C6D93D208C3310362A0A2FBCFEFE45B6F10F547B6479D68`; SYS 65,384 bytes / `12890141238BDC54E0BDDE31A0B0A4CEA598D5889AFCFC524E5D215178CE20E3`; CAT 2,961 bytes / `9C98BE2E13B617384747886E7E4DF18F6681DFAB8971B9A1F57DF1B1E3838CE7`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by the existing certificate; Authenticode `/pa` and exact INF/SYS catalog membership pass. No certificate was created or imported.
- **Validation:** Release x64 Universal KMDF build; protocol/HID/activation/fail-open 731/731; focused runtime 31/31 in PowerShell 7 and Windows PowerShell; physical lifecycle 109/109; request-owner model 5002/5002 and KMDF guard 62/62; WDF setup; kernel compatibility; production linkage; canonical source contract 29/29 in both runtimes; repository safety; InfVerif; Inf2Cat; signatures and catalog membership pass. InfVerif warning 1384 remains intentional for mandatory VHF ordering.
- **Safety / functional status:** live 1.0.9 inspection was read-only. Version 1.0.10 was not staged, installed, loaded, or executed. No device restart/reboot, certificate/trust, BCD, HVCI, or Secure Boot mutation occurred. Functional Chatpad success remains unclaimed pending one 1.0.10 installation and real key test.

## Next action

TASK 8J-R7-T1 — install the exact 1.0.10 package once with the single PnPUtil upgrade command, reboot once if requested, inspect the current activation/input markers, and test the controller and real Chatpad.
