# Project State

*Last updated: 2026-07-12 (TASK 8J-R3 expected activation-preamble stalls)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the 1.0.6 correction commit has parent `33dd9aabefe1a7529a6de04cff71548c9c7328cc`, subject `fix: accept required activation preamble stalls`, and final hash derived from Git after commit.
- **Accepted live 1.0.5 state:** `oem99.inf` version 1.0.5.0 is selected. Exact 64,360-byte SYS SHA-256 `0E932A891E2B6EDEB88859D5EC4AF8634B2CC6ED333EBB13F42AE42EDA7248C7` is Valid and loaded. `xusb22`, `ChatpadFilter`, and `vhf` run in order `xusb22 -> ChatpadFilter -> vhf -> ACPI -> USBHUB3`; controller, IG_00, HID descendant, and VHF keyboard child have problem code 0. The operator confirms normal controller operation and no Chatpad input. No relevant Code Integrity event exists.
- **First failing stage:** VHF create/start, interface 2, and pipe 0 all succeed. Activation step 0 sends exact `40 A9 0C A3 23 44 00 00` and returns NTSTATUS `0xC0000001`, `USBD_STATUS_STALL_PID` (`0xC0000004`), zero bytes. Version 1.0.5 records optional stage 5 and stops before steps 1-5, reader, input, decode, or keyboard submission.
- **Concrete cause:** the retained legacy implementation explicitly states that the first three `40/A9` preamble requests produce stalls/failures but must still be issued before the real activation tail. Version 1.0.5 incorrectly applied its generic stop-on-failure rule to those expected stalls.
- **1.0.6 correction:** steps 0-2 accept only a failed, zero-byte `USBD_STATUS_STALL_PID` on their zero-length preamble requests and record `ActivationStepNExpectedStall=1`; ordinary success also advances. Non-stall failures, timeouts, cancellations, unexpected bytes/data lengths, and all failures on steps 3-5 remain fatal. There is no retry. Physical fail-open behavior, VHF isolation, xusb22 forwarding, and teardown are unchanged.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.6.0`; VHF child version `0x0106`.
- **Final ignored package:** `artifacts/task-8j-r3-expected-preamble-stall-package/final` contains exactly: INF 1,590 bytes / `BB6819BE3CC7140E7161683C7A5E105A7AC8E4E90A2D4E3B634FEE4D0C69A0A8`; SYS 65,384 bytes / `356547018A3E2324D54E0B9940235D292649C2EED76569AD1859C905286D8F13`; CAT 2,961 bytes / `9F1F022820A0D11B74B59CF55ABB7A84EA5F0D4AC3A2199E55763F594D13A485`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; Authenticode and exact INF/SYS catalog membership pass. No certificate was created or imported.
- **Validation:** Release x64 Universal KMDF build; protocol/HID/activation/fail-open 728/728; focused runtime 30/30 in PowerShell 7 and Windows PowerShell; physical lifecycle 109/109; request-owner 5002/5002; WDF setup; kernel compatibility; production linkage; canonical source contract 29/29 in both runtimes; repository safety; InfVerif; Inf2Cat; signatures and catalog membership pass. InfVerif warning 1384 remains intentional for mandatory VHF order.
- **Safety / functional status:** version 1.0.6 was not staged, installed, loaded, or executed. No live device mutation, restart, reboot, certificate/trust, BCD, HVCI, or Secure Boot change occurred. Functional Chatpad success remains unclaimed pending the operator's one-time 1.0.6 installation and real key test.

## Next action

TASK 8J-R3-T1 — remove installed 1.0.5 `oem99.inf`, install the exact 1.0.6 expected-stall package once, reboot if requested, inspect all six activation results and later input stages, then test the controller and real Chatpad.
