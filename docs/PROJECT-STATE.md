# Project State

*Last updated: 2026-07-12 (TASK 8J-R5 raw control-transfer transport)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the 1.0.8 correction commit has parent `f18dc2857f50f55fa255971ba750fa198834810f`, subject `fix: use raw control transfer URBs`, and final hash derived from Git after commit.
- **Accepted live 1.0.7 state:** selected `oem99.inf` is version 1.0.7.0. Loaded SYS is exactly 65,384 bytes / `89BE92CFDA93B9B172975CCE3E06D9F19F2122FA5A53255329F2C06D218F9927`, Valid under the existing certificate. `xusb22`, `ChatpadFilter`, and `vhf` are RUNNING; the physical stack remains `xusb22 -> ChatpadFilter -> vhf -> ACPI -> USBHUB3`; exact controller and VHF chain are healthy. The operator confirms normal Xbox operation and no Chatpad input. No relevant Code Integrity event exists.
- **First failing stage:** VHF, interface 2, pipe 0, and steps 0-3 execute; steps 0-3 record their zero-byte stalls as accepted. Exact step-4 setup `40 A1 0000 E416 0002` with outbound `09 00` then returns NTSTATUS `0xC0000001`, `USBD_STATUS_STALL_PID` (`0xC0000004`), zero bytes, and `ExpectedStall=0`. Optional stage 9 stops before the final probe, reader, input, decoder, or VHF keyboard submission.
- **Concrete cause:** all five requests attempted by versions 1.0.5-1.0.7 used specialized `URB_FUNCTION_VENDOR_DEVICE` URBs and all five stalled, including the activation write. The retained working driver used a generic raw setup-packet control transfer. Probe-policy exceptions cannot repair a rejected activation write; the transfer representation is the next concrete mismatch.
- **1.0.8 correction:** build `URB_FUNCTION_CONTROL_TRANSFER` directly, copy all eight authoritative setup bytes verbatim, and submit through the existing next-lower WDF target. Transport architecture is 3. The filter still does not create/reconfigure a WDF USB target, claim the configuration, retry, relax the activation write/final probe, or alter controller forwarding and fail-open behavior.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.8.0`; VHF child version `0x0108`.
- **Final ignored package:** `artifacts/task-8j-r5-raw-control-transfer-package/final` contains exactly: INF 1,590 bytes / `96222409A84EC76BC4EE9C447F181676D1147EA4062DA824DB7B8AB37F8BA642`; SYS 65,384 bytes / `C5A3FE785768C550211B61EBB35BA1D6FDA9D4884481EE62C1ACF4B526C6734E`; CAT 2,961 bytes / `B5DFD2787B8AB1D3BD164FA11CCB49E3A7AA8F791638C69015D136547A98E8BA`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; Authenticode and exact INF/SYS catalog membership pass. No certificate was created or imported.
- **Validation:** Release x64 Universal KMDF build; protocol/HID/activation/fail-open 731/731; focused runtime 30/30 in PowerShell 7 and Windows PowerShell; physical lifecycle 109/109; request-owner model 5002/5002 and KMDF guard 62/62; WDF setup; kernel compatibility; production linkage; canonical source contract 29/29 in both runtimes; repository safety; InfVerif; Inf2Cat; signatures and catalog membership pass. InfVerif warning 1384 remains intentional for mandatory VHF order.
- **Safety / functional status:** live 1.0.7 inspection was read-only. Version 1.0.8 was not staged, installed, loaded, or executed. No device restart/reboot, certificate/trust, BCD, HVCI, or Secure Boot mutation occurred. Functional Chatpad success remains unclaimed pending one 1.0.8 installation and real key test.

## Next action

TASK 8J-R5-T1 — remove installed 1.0.7 `oem99.inf`, install exact 1.0.8 once, reboot if requested, inspect raw-control activation and later input stages, then test the controller and real Chatpad.
