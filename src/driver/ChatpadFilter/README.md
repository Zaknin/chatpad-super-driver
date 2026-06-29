# ChatpadFilter lifecycle scaffold

`ChatpadFilter` is a compile-only, non-installable x64 KMDF filter-capable
skeleton for the Windows 11 port. `EvtDeviceAdd` calls
`WdfFdoInitSetFilter(DeviceInit)`, creates a per-device context, and registers
only the PnP/power lifecycle callbacks needed for offline lifetime
bookkeeping.

The per-device context contains only:

- a fixed context signature/version;
- a deterministic diagnostic sequence counter;
- the caller-owned portable lifecycle state from `ChatpadFilterLifecycle`.

The lifecycle core is portable C and is compiled into both the driver and the
native lifecycle test executable. It has no WDF, WDM, Windows, USB, HID, IOCTL,
endpoint, pipe, queue, request, timer, work-item, protocol, transport,
keyboard, allocation, I/O, global mutable state, or retained caller pointer.
The core is externally serialized by its caller; it makes no locking, waiting,
threading, retry, cancellation-wait, or scheduler claim.

Lifecycle phases are neutral:

1. unset;
2. created;
3. prepared;
4. D0 active;
5. rundown requested;
6. D0 stopped;
7. released.

Generation zero is invalid. The first active D0 epoch is generation `1`; each
later D0 entry after a completed D0 exit increments the generation. D0 entry
opens operation admission. D0 exit closes admission, begins rundown, and
completes only when outstanding operation count is zero. Stale-generation
acquire/release/rundown/completion attempts are rejected without mutating
current state.

The KMDF layer registers only `EvtDevicePrepareHardware`,
`EvtDeviceReleaseHardware`, `EvtDeviceD0Entry`, and `EvtDeviceD0Exit`.
Prepare/release callbacks maintain the conceptual prepared resource epoch but
do not inspect resource lists or create hardware resources. D0 callbacks
delegate state changes to the core. `EvtDeviceD0Exit` does not wait; a nonzero
outstanding count returns a deterministic busy status.

`WdfFdoInitSetFilter(DeviceInit)` makes this binary filter-capable only. This
repository still has no INF, hardware-ID targeting, install package, service,
catalog, certificate, signing, deployment, or load path. It does not prove this
`.sys` is attached to any device stack, positioned beneath `xusb22`, or
targeted at `USB\VID_045E&PID_028E`; those remain future installation
responsibilities.

The project sets WDK `SignMode` to `Off` for Debug x64 and Release x64. Builds
are intentionally unsigned: no certificate is created and no SignTool
operation runs. All outputs and intermediates are routed beneath repository
root `artifacts/` by `tools/Build-Driver.ps1`.

The generated `.sys` must not be installed or loaded on any Windows system.
