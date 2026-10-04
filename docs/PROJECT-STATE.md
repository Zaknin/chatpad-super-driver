# Project State

Updated 2026-10-04 after reproducing the C4L2 scope rejection and adding exact-conflict diagnostics.

- Branch: `feature/chatpad-usermode-runner`; current committed base `349f2ea1777048022b9a95f29e2be91c551da83f`; scoped diagnostic changes are in the working tree.
- Live: the user repaired `ChatpadHidMaestroBroker` from package `build-broker-create-failure-299569e`; service is Running as LocalSystem. Two normal-user runs opened WinUSB and passed Chatpad activation, but both stopped before virtual-device creation with `virtual_scope_conflict`. XInput, controls, rumble callback, and clean shutdown remain unqualified.
- Package identity: previous installed runner/broker hashes matched that package exactly. The protected service log remains unchanged since 19:17 UTC (`Create first.`) and does not explain the later scope errors.
- Present-node discrepancy: immediate read-only checks after the 19:30 and 19:37 UTC failures found only `SWD\HIDMAESTRO\HM_622C184E37F6891E` with registry `ControllerIndex=0`; the same `CM_Locate_DevNodeW`/`CM_Get_DevNode_Status` test returned not-present (`CR_NO_SUCH_DEVNODE`). No matching present ROOT/SWD device was enumerated. The exact node observed at create time is not established.
- Diagnostic change: preserve the index-zero/present guard, but include the exact matching instance ID in `virtual_scope_conflict` detail. Also isolate the pipe-squatter self-test on a unique temporary pipe name so it remains testable while the production service owns its fixed pipe.
- Focused verification so far: pinned .NET 10 helper build succeeded with 0 warnings/errors; managed self-test reports 158 passed, 0 failed. The test now exercises exact conflict-ID reporting, and the pipe-squatter check passes without stopping the live service. Release package regeneration, full package hash readback, atomic publication, and another user-run service repair are pending.
- Safety: no service lifecycle/configuration change, device/driver/PnP/registry mutation, trust/security change, reboot, elevated bridge run, or HIDMaestro global cleanup was performed by the agent. `legacy/` is untouched.
