# Project State

Updated 2026-10-05 for the C4L2 physical-controller polling startup fix.

- Branch: `feature/chatpad-usermode-runner`; starting HEAD for this correction: `b3a1bbba832842da508172dae2c9553bef41130b`.
- Live status: the user manually repaired the broker successfully; it was reported Running as LocalSystem. The most recent normal-user run repeatedly failed the initial zero-rumble USB write (Win32 1460, once 121) before any virtual-controller-created event. XInput/rumble are still not qualified on that run.
- Diagnosis: source previously left IF0/81 unread after its readiness report while it activated Chatpad and issued the initial rumble write, then performed potentially slow broker creation before starting the controller reader. This is the leading explanation for the output-pipe timeout, not yet confirmed on hardware.
- Correction in progress: a persistent IF0/81 controller pump now starts before Chatpad activation, retains latest state during startup, and streams it to the existing broker after create. The required zero-rumble write and XUSB identity gate remain unchanged.
- Focused verification so far: Release build of `ChatpadControllerInputPumpTests` and `ChatpadWinUsbPoc` passed; pump test 7/7; focused CTest `controller-input-pump`, `broker-client`, and `runner-lifecycle` passed 3/3. Fresh package, managed/setup checks, publication, commit, and push remain pending.
- Previous release `20261005T030811Z` was already published (archive SHA-256 `1166065DB57CDD92081C3BE982FD7C3BF4F1BF1B93FED5D6DFF4804710AF2661`) and the user manually repaired from its package. The previous continuation notes that called it merely prepared were stale; this correction will use a fresh immutable release timestamp.
- Safety: no service, PnP, driver binding, registry, trust, or device mutation by the agent; no elevated bridge run; no global HIDMaestro cleanup; `legacy/` untouched.

## Next

Finish focused offline verification, build a fresh package from the committed/pushed HEAD, audit package member hashes, and atomically publish a new PARTIAL release. Because the broker service payload is unchanged and the user has already repaired it, the next live step is a normal-user run of the new `ChatpadBridge.exe`; collect whether IF0/81 polling starts, whether the zero-rumble write passes, and whether the virtual Xbox is created. Only then resume XInput and physical rumble checks.
