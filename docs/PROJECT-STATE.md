# Project State

Updated 2026-10-04 for TASK 8L-C4L1 normal-user privilege boundary.

- Branch: `feature/chatpad-usermode-runner`; starting HEAD `89117009cc742534501ef5a3b6607fe23111504c`.
- Live core function remains confirmed by the user's earlier runs: physical controller and Chatpad inputs, virtual Xbox buttons/sticks/triggers, keyboard mapping, rumble, and one clean shutdown.
- Latest normal-user run reached WinUSB open and Chatpad activation (`RUNNING`), then `HMContext.CreateController` failed at the adapter phase `create_virtual_controller` with `Win32Exception: Access is denied`. No virtual controller was returned.
- Root cause: the pinned HIDMaestro v1.10.1 public API requires administrator privilege for `CreateController`; its versioned HMContext source says there is no standard-user path to create a HIDClass device. Microsoft's `SwDeviceCreate` documentation also requires Administrator to initiate software-device enumeration. Direct normal-user virtual-device creation is incompatible with this backend/OS contract.
- Post-stop read-only audit: XInput slots 0-3 all returned 1167; no ChatpadBridge/ChatpadVirtualXbox processes or present HIDMaestro/IG_00 devices; physical `USB\VID_045E&PID_028E\1C21F10` remains WinUSB on `oem104.inf`, problem 0, no instance filters. Audit token was non-elevated.
- Verified diagnostic package remains `artifacts/task-8lc4/build-task-8lc4l1-normal-user-phase5-final`, built from implementation commit `ff6dcad52aaa2da486fbe5f354d6923bc412ab39`; 27/27 manifest hashes and lengths, exact package file set, and 18/18 readiness hashes passed. Later commit `8911700` changed documentation only.
- Safety: no elevation, ACL modification, service/task installation, driver/PnP/registry mutation, reboot, trust/security change, or successful virtual-device creation was performed in this turn.
- Blocker: retain a standard-user foreground client by introducing a narrowly scoped privileged broker/service, or change the Phase 5 requirement to permit an elevated runner. Do not continue lifecycle acceptance until this architecture decision is authorized and implemented.
