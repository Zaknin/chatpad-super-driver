# Project State

*Last updated: 2026-07-13 (TASK 8J-R9 post-activation keep-alive correction)*

## Current truth

- **Branch / starting commit:** `feature/chatpad-kmdf-live-activation-runtime` at `e07e10930e965345fbfd454d8287f445d0ef1053`. The pending correction commit subject is `fix: sustain live chatpad input with keep-alives`.
- **Accepted live 1.0.11 installation:** `oem101.inf` version 1.0.11.0 is selected. The loaded SYS is 66,920 bytes / `31008FE885D0542D2DB1A5848B9E07704E13E58EB6EEFD8A1FF16EEA33E34371`, Valid under existing certificate `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`.
- **Healthy physical path:** `xusb22`, `ChatpadFilter`, and `vhf` run. The exact controller, IG_00, and HID nodes are `CM_PROB_NONE`; the physical stack is `xusb22 -> ChatpadFilter -> vhf`; no relevant Code Integrity rejection exists. The operator confirms the Xbox controller works normally and the Chatpad produces no keyboard input.
- **1.0.11 runtime result:** transport architecture 6 finds both configured pipes and observes a successful three-byte parent controller-input completion. All six activation transfers then complete successfully, including the revision-1.14 `09 00` write and final probe. `ActivationCompleted=1` and `ReaderStarted=1`.
- **First failing stage:** the first interface-2 input read expires with `STATUS_IO_TIMEOUT` (`0xC00000B5`), canceled USBD status `0xC0010000`, and zero bytes. No five-byte packet, decoder result, or key-bearing VHF submission follows.
- **Concrete protocol omission:** the retained working runtime immediately enters an alternating keep-alive loop after activation: zero-length setup `41 00 1F 00 02 00 00 00`, wait one second, `41 00 1E 00 02 00 00 00`, wait one second, repeat. Version 1.0.11 implemented activation and input reads but neither keep-alive, leaving the activated endpoint silent.
- **1.0.12 correction:** transport architecture 7 sends `0x001F` immediately after activation and alternates `0x001F`/`0x001E` every second from the existing passive input worker using endpoint zero, a null pipe, and `USBD_DEFAULT_PIPE_TRANSFER`. Between sends it retains the bounded 250 ms interface-2 reads. A keep-alive failure disables only the optional Chatpad path; controller forwarding and physical PnP/power success remain fail-open.
- **Diagnostics:** schema 3 resets each D0 generation and records the first keep-alive value, NTSTATUS, USBD status, byte count, and only the first eight attempt-count updates.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.12.0`; VHF child version `0x010C`.
- **Final ignored package:** `artifacts/task-8j-r9-chatpad-keepalive-package/final` contains exactly INF 1,591 bytes / `EB8D5D3926C6DC0ACCFCAA46C031A527ED376237362B48F5BEEB57199D3FC74A`; SYS 67,432 bytes / `06C5104FC9BEE32C416FA705D3543DAB9B28E4181492ABC49744AE9560191849`; CAT 2,961 bytes / `1139422F6F2B6798A1A2E2929C3DFBB7CBDC8D2311DADCF1A65D0C66A6511C5F`.
- **Signing:** final SYS and CAT are SHA-256 signed without timestamp by the existing certificate; Authenticode and exact INF/SYS catalog membership pass. No certificate was created or imported.
- **Validation:** Release x64 Universal KMDF build; focused runtime 36/36 in PowerShell 7 and Windows PowerShell; protocol/HID/activation/fail-open 736/736; lifecycle 109/109; request-owner model 5002/5002; KMDF guard 62/62; WDF setup; kernel compatibility; production linkage; canonical source contract 29/29 in both runtimes; repository safety; InfVerif; Inf2Cat; signatures and catalog membership pass. InfVerif warning 1384 remains intentional for mandatory VHF ordering.
- **Packaging correction:** an initial package attempt signed its copied SYS, then Inf2Cat rejected the postdated July 13 INF before generating a catalog. That ignored partial artifact was path-verified and deleted. The source date was corrected to July 12 and the final package was rebuilt cleanly.
- **Safety / functional status:** live inspection was read-only. Version 1.0.12 was not staged, installed, loaded, or executed. No device restart/reboot, certificate/trust, BCD, HVCI, or Secure Boot mutation occurred. Functional Chatpad success remains unclaimed pending one 1.0.12 installation and real key test.

## Next action

TASK 8J-R9-T1 — install exact 1.0.12 once, reboot once if requested, prove the keep-alive and first input/decode/HID stages, then test the controller and real Chatpad.
