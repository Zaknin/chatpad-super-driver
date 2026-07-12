# Project State

*Last updated: 2026-07-12 (TASK 8J live transport correction)*

## Current truth

- **Branch / commit:** `feature/chatpad-kmdf-live-activation-runtime`; the correction commit containing this state has subject `fix: correct live chatpad activation transport`, parent `f085d8642d4b4820970019d56f3d512a4a2783f9`, and its final hash is derived from Git after commit.
- **Observed TASK 8J live state:** `oem97.inf` version `1.0.1.0` is selected and its exact 55,656-byte SYS hash `2CCA4168ABC11F81B9A92B993AE038D3584E16178F42AB7AFE6BE64CD7E079C6` is in the Driver Store, but `ChatpadFilter` is stopped and absent from the physical controller stack. The exact controller remains started with problem code 0 and normal controller function. No Code Integrity rejection was found. Therefore requested runtime stage 3 is the first stage without successful evidence; stages 4-13 did not run or have recoverable evidence.
- **Cause and correction:** TASK 8J attempted to create a specialized WDF USB target and reselect the configuration from a lower filter under `xusb22`; failure of that ownership path was fatal to attachment and its transient debug output was not retained. Version `1.0.2.0` forwards the original select-configuration/select-interface URBs unchanged, observes their successful completions, captures only interface 2 pipe 0, and submits bounded vendor/input URBs through the next-lower I/O target without reconfiguration.
- **Diagnostics:** bounded per-device registry diagnostics now persist DeviceAdd, PrepareHardware, VHF, configuration/interface/pipe discovery, all six activation setups and NTSTATUS/USBD/byte results, activation completion, reader start, first input result/raw packet/decoder result, first keyboard submission, and cancellation state.
- **Runtime safety:** interface 0 and ordinary controller traffic remain owned by `xusb22`; all unowned internal IRPs are directly forwarded. One activation attempt is consumed per D0 generation. D0 exit/removal cancels and flushes all workers and emits all-keys-up.
- **Version:** canonical INF `DriverVer=07/12/2026,1.0.2.0`; VHF child version `0x0102`.
- **Final ignored package:** `artifacts/task-8j-live-transport-correction-package/final` contains exactly: INF 1,581 bytes / `2EE7FB3E68CAA55B6218DF86FF8726DEE0F59F6D220B38F5074070D09EAEB977`; SYS 61,288 bytes / `A6DEB72BFBE204AD76E5CB0F8783D3D6EF4D1D6D6E7EB4C22A6F2108FA0F8EC0`; CAT 2,951 bytes / `79EA0AA7DDEE96ABB9D615F35B765E1147292AA2B64F9A3904F4A8073C13E569`.
- **Signing:** SYS and CAT are SHA-256 signed without timestamp by existing certificate thumbprint `885ADDC8018AC58E19B14668ACDAC9072BB6AE15`; Authenticode verification and CAT membership for exact INF/SYS pass. No certificate or trust/BCD state was changed.
- **Validation:** Release x64 WDK build, InfVerif, Inf2Cat, protocol/HID/live-transfer 630/630, lifecycle 109/109, request-owner 62/62, live-runtime 22/22 in PowerShell 7 and Windows PowerShell 5.1, kernel compatibility, WDF setup, production linkage, canonical source contract 29/29, repository safety, signature, and catalog membership checks pass. The older runtime-instrumentation freeze guard remains inapplicable to this changed production runtime and reports its pre-existing frozen caller-count mismatch.
- **Safety:** the 1.0.2.0 package was not staged, installed, loaded, or executed. No device restart or reboot occurred during the correction. Installed `oem97.inf` remains unchanged.
- **Functional status:** TASK 8J is functionally incomplete. The correction is offline/package validated only; real Chatpad success requires operator installation, reboot if requested, and manual key testing.

## Next action

TASK 8J-T2 — install the single 1.0.2.0 correction package, reboot if PnPUtil requests it, inspect the bounded runtime diagnostics, and perform the real controller/Chatpad functional test.
