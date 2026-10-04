# Project State

Updated 2026-10-04 for TASK 8L-C4L2 implementation-plan review.

- Branch: `feature/chatpad-usermode-runner`; this plan turn started at HEAD `0107be20255e2bd97cccefb11ffa63c84a4a6cbd`. The earlier C4L1 checkpoint docs incorrectly still named `89117009cc742534501ef5a3b6607fe23111504c`; this discrepancy is recorded in the C4L2 worklog.
- Live core function remains confirmed by the user's earlier runs: physical controller and Chatpad inputs, virtual Xbox buttons/sticks/triggers, keyboard mapping, rumble, and one clean shutdown.
- Latest normal-user run reached WinUSB open and Chatpad activation (`RUNNING`), then `HMContext.CreateController` failed at the adapter phase `create_virtual_controller` with `Win32Exception: Access is denied`. No virtual controller was returned.
- Root cause: the pinned HIDMaestro v1.10.1 public API requires administrator privilege for `CreateController`; its versioned HMContext source says there is no standard-user path to create a HIDClass device. Microsoft's `SwDeviceCreate` documentation also requires Administrator to initiate software-device enumeration. Direct normal-user virtual-device creation is incompatible with this backend/OS contract.
- Approved design is documented in `docs/superpowers/specs/2026-10-04-hidmaestro-broker-design.md`: a `ChatpadVirtualXbox.exe` Windows Service mode owns only HIDMaestro virtual-device lifecycle/state, while the normal-user bridge retains WinUSB, Chatpad, keyboard injection, and physical rumble. A fixed local named-pipe protocol carries create/destroy/state/ping and rumble callbacks.
- Current stage: user approved the written spec and three clarifications. `docs/superpowers/plans/2026-10-04-hidmaestro-broker.md` is written and pending plan approval. No implementation, service install/start, package build, or live qualification has begun for C4L2.
- Safety: C4L2 has not elevated a process, changed ACLs, installed/started/stopped/deleted a service, mutated driver/PnP/registry/device state, changed trust/security, rebooted, or created a virtual controller.
