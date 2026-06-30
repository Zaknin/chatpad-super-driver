# ChatpadFilter offline integration scaffold

`ChatpadFilter` is a compile-only, non-installable x64 KMDF filter-capable
skeleton for the Windows 11 port. `EvtDeviceAdd` calls
`WdfFdoInitSetFilter(DeviceInit)`, creates a per-device context, and registers
only the PnP/power lifecycle callbacks needed for offline lifetime
bookkeeping.

The project also compiles the dormant `ChatpadActivationPreparation` module.
That module selects one authoritative activation step, translates its portable
request into explicit setup metadata, and formats the setup bytes into a
caller-owned `WDF_USB_CONTROL_SETUP_PACKET`. It is not called by DriverEntry,
device-add, PnP/power, cleanup, or any other runtime callback.

The per-device context contains:

- a fixed context signature/version;
- a deterministic diagnostic sequence counter;
- the caller-owned portable lifecycle state from `ChatpadFilterLifecycle`;
- one directly embedded `ChatpadKmdfActivationRequestOwner`.

`EvtDeviceAdd` ordinarily initializes that owner exactly once after scalar
context setup, validates the clean pre-object baseline exactly once, and only
then initializes lifecycle state. This creates no WDF object and leaves only
`MODEL_READY` set: all framework handles remain null, `OWNER_READY` remains
clear, and the owner remains targetless, non-admitting, and request-inactive.
Dormant creation, rollback, and orchestration helpers are not called.

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

The project compiles the portable request-owner model directly as a WDK
object so the context initializer's WDF-free model dependencies resolve
without linking the user-mode model library. The existing request-owner
context static-library project remains the authoritative KMDF implementation.

The preparation module compiles the authoritative activation-request,
activation-sequence, pure control-setup, and WDF formatter sources directly
under the WDK toolchain. No constants or payloads are duplicated, no user-mode
library is linked, and `ChatpadTransport` remains disconnected.

The project sets WDK `SignMode` to `Off` for Debug x64 and Release x64. Builds
are intentionally unsigned: no certificate is created and no SignTool
operation runs. Project defaults and `tools/Build-Driver.ps1` route all outputs
and intermediates beneath repository-root `artifacts/`.

The generated `.sys` must not be installed or loaded on any Windows system.

## Offline INF prototype reference

`prototypes/inf/ChatpadFilterExtension/` contains an isolated source-only
extension-INF prototype and its prominent installation warning. The prototype
is not referenced by this project, the solution build, or
`tools/Build-Driver.ps1`. Its static `InfVerif` result does not make this
unsigned driver installable and does not prove placement beneath `xusb22`.

## Future bridge design reference

`docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md` documents the future
documentation-only bridge from the portable activation executor and neutral
transport adapter into a per-device KMDF request owner. It does not change this
driver's runtime behavior: `ChatpadFilter` still owns no transport target, WDF
request, queue, timer, work item, endpoint, pipe, INF, package, signing,
install, load, or hardware behavior.
