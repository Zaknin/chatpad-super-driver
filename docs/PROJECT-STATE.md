# Project State

Updated 2026-10-05 during TASK 8L-C4L2 XInput/rumble diagnosis.

- Branch: `feature/chatpad-usermode-runner`; XUSB success-gate source commit `2c554fe118eec879fbe41ee925fbc188e36dc436` is pushed. Build package only after reading the current HEAD following this continuity update.
- Live status: normal-user WinUSB, Chatpad, HID input and controller values work. The user's XInput scan found no connected slot; `XInputSetState` returned 1167, so rumble is not qualified. The broker service was last read as Running under LocalSystem.
- Diagnosis: the expected `hmswd` log is absent from the service's actual temp directory, `C:\Program Files\ChatpadBridge\Temp\HIDMaestro`. Pinned HIDMaestro 1.10.1 source waits for the XUSB interface and XInput slot but does not fail controller creation when those waits time out. The broker therefore could report virtual creation after HID-only setup.
- Source correction: broker success now requires the exact present XUSB interface class `{EC87F1E3-C13B-4100-B5F7-8B84D54260CB}` for the HIDMaestro controller token. Failure is surfaced as `xusb_companion_unavailable` and triggers normal owned-controller cleanup. It does not verify interactive-session XInput slot visibility; live confirmation is still required.
- Focused verification so far: managed offline helper 168/168; focused native CTest `broker-client` and `runner-lifecycle` 2/2. No live service repair or runtime was performed by the agent.
- Package/readiness: source correction is committed and pushed; package/readiness from the final current HEAD is pending. The previous `build-readiness-current-head` package predates this correction and must not be used for the next repair.
- Safety: no service lifecycle/configuration mutation, PnP/registry/device mutation, trust change, reboot, elevated bridge run, or HIDMaestro global cleanup by the agent. `legacy/` is untouched.

## Next

Commit and push the correction and continuity updates. Build and audit a package/readiness from that exact pushed HEAD, publish it atomically, and give the user one elevated `RepairBroker` command. After the user's manual repair, qualify XInput slot availability and rumble in a normal-user run before lifecycle testing.
