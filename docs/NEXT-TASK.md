# Next Task

## TASK 8L-C4L1 — Resolve the virtual-controller privilege boundary

Starting branch: `feature/chatpad-usermode-runner`; HEAD `89117009cc742534501ef5a3b6607fe23111504c` before this continuity update.

### Verified state

The user's 2026-10-04 15:01Z normal-user run opened the physical WinUSB target, completed Chatpad activation, and reached `RUNNING`. The SDK create call then failed as:

```text
backend_create_failed:create_virtual_controller:Win32Exception:Access is denied.
```

This localizes the failure to `HMContext.CreateController`. The repository pins HIDMaestro v1.10.1. Its versioned `HMContext.cs` documents that `CreateController` requires administrator privilege and that Windows has no standard-user route to create a HIDClass device. For the software-device part of device enumeration, Microsoft documents that `SwDeviceCreate` requires Administrator access. Sources: <https://raw.githubusercontent.com/hifihedgehog/HIDMaestro/v1.10.1/sdk/HIDMaestro.Core/HMContext.cs> and <https://learn.microsoft.com/en-us/windows/win32/api/swdevice/nf-swdevice-swdevicecreate>.

The post-stop read-only audit found no runner/helper process, no present task-owned virtual device, and XInput slots 0-3 all disconnected (1167). The exact physical Xbox remains on WinUSB `oem104.inf`, problem 0, with no instance filters. No live changes occurred.

### Required architecture choice

The direct standard-user runner cannot satisfy virtual XInput creation with the pinned SDK. Before further Phase 5 or lifecycle tests, the user must select one of:

1. **Keep normal-user client operation:** design and implement a small, installed privileged broker/service that owns the HIDMaestro controller and accepts only fixed, validated controller state and rumble operations over an authenticated, user-scoped IPC boundary. Setup would install/configure it with administrator rights; the interactive bridge remains non-elevated. This changes the security boundary and requires explicit authorization for service installation and live qualification.
2. **Allow an elevated runner:** retain the current direct SDK design and require elevation for each run that creates the virtual controller. This does not meet the stated normal-user Phase 5 requirement.
3. **Stop the normal-user path:** record Phase 5 as unsupported by the selected SDK and do not continue later lifecycle tests.

Recommended if normal-user operation remains mandatory: option 1. Do not try ACL changes, a hidden scheduled task, undocumented SDK entry points, or alternate setup semantics as a shortcut. Do not rerun the normal-user package: it will deterministically fail at the same SDK boundary. Do not continue unplug/reconnect/crash/long-idle qualification before selecting and implementing a compatible architecture.

After an architecture is authorized: add focused tests for its privilege/IPC boundary; preserve exact physical/runtime identity guards; rebuild and verify package/readiness identity and every member hash; then perform Phase 5 and remaining authorized live lifecycle tests. Keep the accepted 14:16Z clean-stop and core-function evidence. No reboot/sleep/long-idle test is authorized by this continuation.

Inspect first: `docs/PROJECT-STATE.md`, this file, the latest `docs/WORKLOG.md` entry, pinned dependency manifest, `tools/ChatpadVirtualXbox/HidMaestroBackend.cs`, and the diagnostic run output.
