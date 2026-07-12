# Project State

*Last updated: 2026-07-12 (TASK 8J-R4 initial activation-probe stall)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the 1.0.7 correction commit has parent `c8e1aee56d77bdee268bd8614244e70aaa548c0c`, subject `fix: advance past stalled activation probe`, and final hash derived from Git after commit.
- **Accepted live 1.0.6 state:** selected `oem99.inf` is version 1.0.6.0. The loaded 65,384-byte SYS SHA-256 is exactly `356547018A3E2324D54E0B9940235D292649C2EED76569AD1859C905286D8F13`. `xusb22`, `ChatpadFilter`, and `vhf` are RUNNING; the physical stack is `xusb22 -> ChatpadFilter -> vhf -> ACPI -> USBHUB3`. The exact controller, IG_00, HID descendant, VHF device, and VHF keyboard child are present with problem code 0. The operator confirms normal Xbox operation and no ordinary, Shift, or two-key Chatpad input.
- **First failing stage:** VHF create/start, interface 2 / interrupt pipe 0 discovery, and activation steps 0-2 all run. Steps 0-2 record their raw zero-byte `USBD_STATUS_STALL_PID` results and `ActivationStepNExpectedStall=1`. Exact step 3 setup `C0 A1 0000 E416 0002` then returns NTSTATUS `0xC0000001`, USBD `0xC0000004`, and zero bytes; first optional failure stage 8 stops before the `09 00` activation write, final probe, reader, input, decode, or keyboard submission.
- **Concrete cause:** version 1.0.6 made the initial two-byte read probe strictly successful even though this hardware stalls it before the activation write. The request bytes match the retained legacy sequence; the failure is the policy stopping on a non-mutating probe result, not a malformed setup packet or controller-stack failure.
- **1.0.7 correction:** accept a failed zero-byte `USBD_STATUS_STALL_PID` only on exact sequence steps 0-3 with their immutable expected lengths (zero for steps 0-2, two for step 3). Timeouts, cancellation, non-stall errors, unexpected bytes/lengths, the step-4 `09 00` activation write, and the step-5 final probe remain strict. There is no retry. Physical fail-open, VHF isolation, xusb22 forwarding, request ordering, and teardown are unchanged.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.7.0`; VHF child version `0x0107`.
- **Final ignored package:** `artifacts/task-8j-r4-initial-probe-stall-package/final` contains exactly: INF 1,590 bytes / `3D63E4A86351D89D4FF16E302A026FCB01787298AE0659E105ED4521134869C0`; SYS 65,384 bytes / `89BE92CFDA93B9B172975CCE3E06D9F19F2122FA5A53255329F2C06D218F9927`; CAT 2,961 bytes / `F55563E7D58D703ED4EB4DC9FE85E4F4ECA4721327B0CFFE5385DAFD443FFFD4`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; Authenticode and exact INF/SYS catalog membership pass. No certificate was created or imported.
- **Validation:** Release x64 Universal KMDF build; protocol/HID/activation/fail-open 731/731; focused runtime 30/30 in PowerShell 7 and Windows PowerShell; physical lifecycle 109/109; request-owner model 5002/5002 and KMDF guard 62/62; WDF setup; kernel compatibility; production linkage; canonical source contract 29/29 in both runtimes; repository safety; InfVerif; Inf2Cat; signatures and catalog membership pass. InfVerif warning 1384 remains intentional for mandatory VHF order.
- **Safety / functional status:** live 1.0.6 inspection was read-only. Version 1.0.7 was not staged, installed, loaded, or executed. No device restart/reboot, certificate/trust, BCD, HVCI, or Secure Boot mutation occurred. Functional Chatpad success remains unclaimed pending one 1.0.7 installation and real key test.

## Next action

TASK 8J-R4-T1 — remove installed 1.0.6 `oem99.inf`, install exact 1.0.7 once, reboot if requested, inspect the strict activation write/final probe and later input stages, then test the controller and real Chatpad.
