# Project State

Updated 2026-10-04 after broker handshake ordering correction.

- Branch: `feature/chatpad-usermode-runner`; implementation commit `f5d5885c73ec10d3d33ac30ad68eaf8ceb543290` is built locally; continuity and package handoff will be committed and pushed on the same branch.
- Live service: user manually repaired the previous package; the latest observed state was RUNNING as LocalSystem. No service lifecycle operation was performed for the current fix.
- Latest live runtime exposed the .NET pipe impersonation requirement. The server now reads the bounded initial frame before `RunAsClient`, then validates SID/active local console session, and dispatches the buffered frame only after authorization. The initial frame deadline is five seconds.
- Fresh package: `artifacts/task-8lc4l2/build-broker-read-before-impersonation-f5d5885/package`, from implementation commit `f5d5885c73ec10d3d33ac30ad68eaf8ceb543290`. All 214 member lengths/hashes matched. `ChatpadBridge.exe` SHA-256: `DE581D4343DAC51F5731E8C8E5BB7AD53BEE0B11683727222310C9A73F7F6934`; `ChatpadVirtualXbox.exe` SHA-256: `5E1AA2C384943064F9B9226D831C4A6296E1E239398E30329BD90F3448D0F41B`.
- Verification: C4 setup/package checks passed; focused native CTest `broker-client|runner-lifecycle` passed 2/2. Managed self-test reported 149 passed and one environment-limited failure: the pipe-squatter test cannot bind while the installed broker owns the fixed name. No service stop was attempted.
- Remaining acceptance: user-run elevated `RepairBroker` from this package, then normal-user broker create, XInput, controller/Chatpad input, rumble, graceful cleanup, reconnect, and crash recovery. Hard-client-crash physical rumble remains an accepted limitation.
- Safety: no service lifecycle/configuration operation, driver/PnP/registry/device mutation, trust/security change, reboot, elevated bridge run, or HIDMaestro global cleanup was performed for this fix. `legacy/` is untouched.
