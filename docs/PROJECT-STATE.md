# Project State

*Last updated: 2026-07-12 (TASK 8J-R2 fail-open VHF redesign)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the correction commit has parent `85fdc5258e8cad99ba59a99acd3c669bb0d4d5f7`, subject `fix: isolate VHF from Xbox device startup`, and final hash derived from Git after commit.
- **Accepted recovered live state:** the operator removed failed `oem100.inf`; Microsoft `xusb22` and the controller work with all accepted controller descendants healthy. Residual `oem99.inf` version 1.0.3.0 remains selected until the operator performs the explicit next-task cleanup. Codex did not query or modify the live device during R2.
- **Confirmed 1.0.4 failure:** `VhfCreate` returned `0xC00000BB` (`STATUS_NOT_SUPPORTED`) because VHF requires `vhf.sys` below its HID source, while the legacy `ChatpadFilter, vhf` lower-filter list did not provide that live relationship. The optional error was then returned from physical `EvtDevicePrepareHardware`, producing Code 10.
- **1.0.5 architecture:** Microsoft supports a KMDF filter as the VHF source. The INF now orders `vhf, ChatpadFilter`; the physical filter WDFDEVICE remains the supported source, and the VHF keyboard is an optional sub-lifecycle with a dedicated passive worker and fixed eight-report queue. The physical USB filter continues to forward all unrelated traffic directly and only observes the xusb22-selected interface 2 / pipe 0.
- **Fail-open rule:** every Chatpad-only failure records its first stage, disables/degrades Chatpad output, preserves controller forwarding, and returns physical PrepareHardware/D0 success. VHF create/start, all workers, interface/pipe discovery, six activation steps, input reads, decoder policy, queueing, and keyboard submission cannot propagate into Xbox PnP/power startup. Teardown is bounded, flushes workers/queue, and attempts an all-keys-up report.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.5.0`; VHF child version `0x0105`.
- **Final ignored package:** `artifacts/task-8j-r2-fail-open-vhf-package/final` contains exactly: INF 1,590 bytes / `8A637884D43A6619314B3D8F234CACD2E71F6FAF3244BEBD8CC872679395CBE1`; SYS 64,360 bytes / `0E932A891E2B6EDEB88859D5EC4AF8634B2CC6ED333EBB13F42AE42EDA7248C7`; CAT 2,961 bytes / `3EA9F4164F18D3801BEC84BFDBE10BD396FDC26B36937F3B5B9036040E374861`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; Authenticode and exact INF/SYS catalog membership pass. No certificate was created or imported.
- **Validation:** Release x64 Universal KMDF build; protocol/HID/activation/fail-open 717/717; focused runtime 29/29; physical lifecycle 109/109; request-owner 5002/5002; WDF setup; kernel compatibility; production linkage; canonical source contract 29/29; repository safety; InfVerif; Inf2Cat; signatures and catalog membership pass. InfVerif warning 1384 remains intentional because xusb22 defines no declarative filter levels and the VHF relative order is mandatory.
- **Safety / functional status:** version 1.0.5 was not staged, installed, loaded, or executed. No trust, BCD, HVCI, Secure Boot, device, restart, or reboot mutation occurred. TASK 8J remains functionally incomplete until the operator cleans `oem99.inf`, installs 1.0.5 once, reboots, and tests the real controller and Chatpad.

## Next action

TASK 8J-R2-T1 — clean residual `oem99.inf`, install the single 1.0.5 fail-open package, reboot once if requested, verify the exact stack/diagnostics, and perform the real controller/Chatpad test.
