# Project State

*Last updated: 2026-07-13 (TASK 8J-R10 first-packet key-data enable correction)*

## Current truth

- **Branch / starting commit:** `feature/chatpad-kmdf-live-activation-runtime` at `8cd5547468347d2a8a7348080069917dbb559774`. The pending correction commit subject is `fix: enable chatpad key data after first packet`.
- **Accepted live 1.0.12 installation:** `oem102.inf` version 1.0.12.0 is selected. Exact loaded SYS is 67,432 bytes / `06C5104FC9BEE32C416FA705D3543DAB9B28E4181492ABC49744AE9560191849`, Valid under existing certificate `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`.
- **Healthy physical path:** `ChatpadFilter`, `xusb22`, and `vhf` run. The exact controller, IG_00, and HID nodes are `CM_PROB_NONE`; physical stack is `xusb22 -> ChatpadFilter -> vhf`; no relevant Code Integrity rejection exists. Operator confirms normal controller operation and no Chatpad keyboard input.
- **1.0.12 progress:** transport architecture 7 reaches readiness, all six activation transfers, activation completion, reader start, and successful alternating keep-alives. The first keep-alive is `0x001F` with NTSTATUS/USBD/bytes `0/0/0`; bounded attempt count reaches eight.
- **First received packet:** interface 2 delivers exact five-byte packet `F0 03 00 01 01`. `FirstDecodeResult=5` is `CHATPAD_PARSE_UNSUPPORTED_TYPE`; this is correct because `0xF0` is a status packet rather than a key report.
- **Concrete protocol omission:** retained working source ignores `0xF0`, but after the first successful Chatpad message sends zero-length interface command `41 00 1B 00 02 00 00 00`. Its source states this is required for Chatpad key data to be received. Version 1.0.12 never sends it, so no key-bearing packet reaches the decoder.
- **1.0.13 correction:** transport architecture 8 retains status-packet rejection and sends `wValue=0x001B` exactly once after the first complete Chatpad packet, before parsing it. The command uses the same endpoint-zero/default-pipe interface-command helper. A failure disables only the optional Chatpad path and is not retried; controller forwarding remains fail-open.
- **Diagnostics:** schema 4 resets `BacklightCommandSent` each D0 generation and records command NTSTATUS, USBD status, and byte count.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.13.0`; VHF child version `0x010D`.
- **Final ignored package:** `artifacts/task-8j-r10-first-packet-backlight-package/final` contains exactly INF 1,591 bytes / `7B0B8831572EA9F0426F5CF7399049DC2EC286252C4B5BEF31898D5EA957F1BB`; SYS 67,944 bytes / `45A727CE2658A8A9B5F1CC0B8654DF0C7A929244C929200DF66BD97EBABA5ACD`; CAT 2,961 bytes / `B4319CA7FBB00692C705F893A16115987BC15318C5FC11A2913AEA54D268E678`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by the existing certificate; Authenticode and exact INF/SYS catalog membership pass. No certificate was created or imported.
- **Validation:** Release x64 Universal KMDF build; focused runtime 38/38 in PowerShell 7 and Windows PowerShell; protocol/HID/activation/fail-open 741/741; lifecycle 109/109; request-owner model 5002/5002; KMDF guard 62/62; WDF setup; kernel compatibility; production linkage; canonical source contract 29/29 in both runtimes; repository safety; InfVerif; Inf2Cat; signatures and catalog membership pass. InfVerif warning 1384 remains intentional for mandatory VHF ordering.
- **Safety / functional status:** live inspection was read-only. Version 1.0.13 was not staged, installed, loaded, or executed. No device restart/reboot, certificate/trust, BCD, HVCI, or Secure Boot mutation occurred. Functional Chatpad success remains unclaimed pending one 1.0.13 installation and real key test.

## Next action

TASK 8J-R10-T1 — install exact 1.0.13 once, reboot once if requested, prove the one-shot `0x001B` command and subsequent key packet/decode/HID stages, then test the controller and real Chatpad.
