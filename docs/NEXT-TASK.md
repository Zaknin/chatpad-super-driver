# TASK 8L-C4L2 — Qualify startup controller polling fix

## Current state

- Required branch: `feature/chatpad-usermode-runner`; current source correction is based on `b3a1bbba832842da508172dae2c9553bef41130b`.
- The user manually ran `RepairBroker` successfully. The service payload is unchanged by this native runner fix; do not ask for another elevated repair unless later package evidence shows the service runtime changed.
- Normal-user log showed `initial zero-rumble command failed win32=1460` (once 121) before virtual controller creation. Source now continuously polls physical IF0/81 from before activation through broker creation and streams the latest state after create. This is an unverified hardware hypothesis until the next run.
- Focused native checks passed 3/3 (`controller-input-pump`, `broker-client`, `runner-lifecycle`); pump unit checks passed 7/7. Fresh exact-HEAD package, package hash audit, publication, and commit/push remain pending.
- Prior release `20261005T030811Z` is already published, SHA-256 `1166065DB57CDD92081C3BE982FD7C3BF4F1BF1B93FED5D6DFF4804710AF2661`; never overwrite it. Use a new UTC timestamp.

## Next steps

1. Complete the narrow offline checks, update the release verification summary, inspect the complete diff, commit, and push only `feature/chatpad-usermode-runner`.
2. Build a fresh package from exact pushed HEAD with `tools/Build-ChatpadBridge.ps1 -SkipNativeTests`, then run focused `ctest` and packaged helper/setup/readiness checks. Audit every package member against its generated manifest.
3. Prepare and atomically publish a fresh PARTIAL C4L2 artifact under `\\192.168.23.63\Torrents\Codex\Chatpad-360-driver\TASK-8L-C4L2\<UTC_TIMESTAMP>\`; independently read back hashes and sidecars.
4. Ask the user to run the published package's `ChatpadBridge.exe run` from ordinary, non-elevated PowerShell and return the complete log. Confirm the new `controller input polling started before Chatpad activation` event, no initial zero-rumble timeout, and virtual-controller creation before resuming XInput/rumble tests.

## Safety and acceptance

- Do not perform service lifecycle changes, driver binding, PnP/registry mutation, trust changes, reboot, elevated bridge execution, or HIDMaestro global cleanup.
- Do not weaken the initial zero-rumble command or exact XUSB interface gate. `1460` and `121` mean the bounded USB write failed/timed out; the source-order diagnosis remains a hypothesis until a live retry.
- PASS for this correction requires the normal-user log to pass initial zero-rumble, create the XUSB-gated virtual controller, and remain running; XInput slot and physical rumble are separately qualified afterward.
- Inspect first: `tools/ChatpadWinUsbPoc/ControllerInputPump.{h,cpp}`, `controller-input-pump-tests.cpp`, `Runner.cpp`, `CMakeLists.txt`, and the focused C4L2 build/publish scripts.
