# Project State

*Last updated: 2026-07-12 (TASK 8J live KMDF activation runtime)*

## Current truth

- **Branch / parent:** `feature/chatpad-kmdf-live-activation-runtime`; the current implementation is the single commit containing this state update, with parent `6ab488a970eb0e1817959bd752ce60b046064692` and subject `feat: connect chatpad protocol to KMDF runtime`.
- **Runtime:** the exact `USB\VID_045E&PID_028E` lower filter now reuses the parent `URB_FUNCTION_SELECT_CONFIGURATION` through `WdfUsbTargetDeviceSelectConfig`, directly forwards every other internal IRP to the next-lower driver, and uses only interface 2 pipe 0 for Chatpad traffic. Interface 0/controller reports remain owned by `xusb22`.
- **Activation:** one interlocked attempt is allowed per D0 generation. A passive work item sends the six authoritative vendor transfers in order with 1,000 ms per-step timeouts, exact byte-count validation, 12 ms post-step delays, final response validation, immediate failed-step termination, and no automatic retry.
- **Input:** a second passive worker performs bounded 250 ms reads, uses the existing five-byte parser, maps known base keys and Shift to boot-keyboard usages, and submits through VHF. Duplicate reports are suppressed; invalid/timeout/removal paths release all keys. Green, Orange, and People layers are deliberately rejected rather than mis-mapped and remain a known limitation.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.1.0`.
- **Final ignored package:** `artifacts/task-8j-chatpad-live-activation-package/final` contains exactly three files: INF 1,581 bytes / `FEB56DB8B19899E561CF671E90F8259B6278493A09B0D834ACEB7F36ED935AA1`; SYS 55,656 bytes / `2CCA4168ABC11F81B9A92B993AE038D3584E16178F42AB7AFE6BE64CD7E079C6`; CAT 2,961 bytes / `5FD9025AEC91150E91FF014E698F4CCE6C010C6930276796856BFA99DDD66D6E`.
- **Signing:** SYS and CAT are SHA-256 signed by existing thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; both report Authenticode `Valid`. CAT membership verification passes for exact INF and SYS. No certificate was created or trust/BCD state changed.
- **Validation:** Release x64 WDK build passes; protocol/HID/live-transfer tests pass 630/630; lifecycle passes 109/109; live-runtime source guard passes 16/16; kernel compatibility, WDF setup, request-owner ABI, production linkage, canonical source contract, InfVerif, Inf2Cat, repository safety, signature, and catalog-member checks pass.
- **Safety:** the new package was not staged, installed, loaded, or executed. No reboot or live device mutation occurred in TASK 8J. The installed `oem96.inf` remains the prior package until the operator explicitly upgrades it.
- **Functional status:** implementation/package validation is complete, but real Chatpad functionality is unproven until manual installation and key testing.

## Next action

TASK 8J-T1 — manually install the TASK 8J package from an elevated terminal, accept a required restart/reboot, then verify normal controller operation and real Chatpad make/break input.
