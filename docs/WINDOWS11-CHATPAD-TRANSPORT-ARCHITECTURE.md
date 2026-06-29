# Windows 11 Chatpad Transport Architecture

## 1. Scope

This document defines a documentation-only architecture for supporting an
original Chatpad attached to an original wired Xbox 360 controller on Windows
11. It separates four concerns: narrow attachment to the existing controller
stack, future activation transfers, future five-byte Chatpad input, and future
keyboard presentation.

No attachment point, endpoint, request path, or keyboard technology is approved
for runtime use by this design. The physical device remains mediated by the
controller; the Chatpad is not modeled as an independent USB device. All
hardware-facing work remains behind the stop gates in section 20.

## 2. Current project position

The repository already contains portable, hardware-free implementations of the
packet parser, state machine, six-request builder, activation planner, and
mocked executor. `src/driver/ChatpadFilter/` is only a compile-validated KMDF
filter skeleton. It has no USB target, transport adapter, input reader, INF,
installation path, or keyboard output.

The connected-device inventory is the current Windows 11 evidence baseline.
The legacy source is protocol and historical architecture evidence, not a
design to port mechanically. The latest protocol/build checkpoint remains
610/610 tests plus Debug and Release compile validation; no build was needed
for this documentation-only task.

## 3. Confirmed physical and PnP model

- The observed controller is USB `VID_045E&PID_028E`, revision `0114`.
- The Chatpad is physically attached to, powered by, and mediated by that
  controller.
- No separately identifiable Chatpad PnP device or interface was observed.
- The controller has an `IG_01` child/function node and a related HID
  descendant in the same container.
- Neither the `IG_01` node nor the HID collection is proven to carry Chatpad
  data.
- Cached PnP inventory did not expose configurations, interfaces, alternate
  settings, endpoints, pipe addresses, transfer types, or polling intervals.

Consequently, PnP relationships support a controller-scoped design but do not
identify the activation or input transport.

## 4. Observed Windows 11 controller stack

The physical controller node is class `XnaComposite`, class GUID
`{D61CA365-5AF4-4486-998B-9DB4734C6CA3}`, and service `xusb22`. Microsoft
`xusb22.sys`, selected through `xusb22.inf`, owns normal controller behavior.
The physical node registers the standard USB device interface and an opaque
class interface. The related descendant registers a HID interface.

No relevant device-level `UpperFilters` or `LowerFilters` entry was observed
on the target nodes, and no relevant class-wide filter was observed on
`XnaComposite` or `HIDClass`. A future filter therefore changes the current
stack and must prove that XInput/controller enumeration and input remain
unchanged.

The proposed target is the physical `USB\VID_045E&PID_028E`/`XnaComposite`
devnode, with a device-specific lower filter beneath `xusb22`. This is an
architecture direction, not evidence that a Windows 11 filter in that position
can already reach the required control pipe or input transfer.

## 5. Legacy attachment and transport architecture

### Attachment

The legacy `winxp_chatpad_filter.inf`, `winvista_chatpad_filter.inf`, and
`win7_chatpad_filter.inf` variants target the exact hardware ID
`USB\VID_045E&PID_028E`. Their device install section writes
`LowerFilters=ChatpadFilter` under the selected device's hardware key. This is
a device-specific lower filter in the `XnaComposite` stack, not a class-wide
filter.

In `filter/chatpad_filter.cpp`, `EvtDeviceAdd` calls
`WdfFdoInitSetFilter`. `EvtDevicePrepareHardware` creates a `WDFUSBDEVICE`.
An internal-device-control queue observes `IOCTL_INTERNAL_USB_SUBMIT_URB`.
When it encounters `URB_FUNCTION_SELECT_CONFIGURATION`, the legacy filter
selects the configuration using the upper driver's URB and caches interface and
pipe handles.

### Control requests

The control sideband accepts legacy IOCTL structures from
`include/chatpad_filter_ioctl.h`. It copies setup fields into a
`WDF_USB_CONTROL_SETUP_PACKET` and calls
`WdfUsbTargetDeviceSendControlTransferSynchronously`. The interface selector
in the IOCTL contract is not used. The control transfer is device-level and
uses the default control pipe exposed through the cached USB target.

`chatpad_control/chatpad_control_code.cpp::InitChatpad` sends the six calls now
represented by the portable request builder. Three `40/a9` calls have unknown
meaning. The later `c0/a1`, `40/a1`, and `c0/a1` calls are historically
observed, but response bytes were logged rather than validated. Return values
from the first three calls were ignored.

### Incoming data and ordinary controller traffic

The legacy filter assumes pipe ordinal positions rather than endpoint
addresses:

- interface 0, pipe 1 for normal-controller writes;
- interface 0, pipe 0 for normal-controller reads;
- interface 2, pipe 0 for Chatpad reads.

It creates and continuously resubmits two of its own Chatpad read URBs. For
some normal-controller traffic it parks upper URBs, substitutes proxy reads,
then copies data into the upper request. Unrecognized URBs are forwarded.
This forwarding intent is a useful concept, but proxying normal-controller
traffic is unnecessarily invasive and can change timing, cancellation, and
completion behavior.

The user-mode `ChatpadReadFunction` maintains two overlapped IOCTL reads and
passes five-byte packets to `HandleChatpadData`. A separate user-mode worker
alternates historical `001f` and `001e` requests. Those periodic requests and
their relationship to readiness remain unresolved.

### Keyboard and mouse presentation

The legacy keyboard and mouse paths each combine a KMDF function layer with a
WDM HID minidriver installed as an upper filter. The KMDF layers spoof PnP IDs
such as `HID\ChatpadKbd`, maintain global collections, and expose sideband
IOCTLs for reports. The WDM layers call `HidRegisterMinidriver`. This
multi-driver, ID-spoofing design is obsolete and is not a Windows 11 target.

## 6. Legacy concepts that remain useful

| Legacy behavior | Classification | Use in the Windows 11 design |
| --- | --- | --- |
| Exact `045E:028E` device targeting | Reusable architecture concept | Keep attachment device-specific. |
| Device-specific lower-filter position | Reusable architecture concept, current capability unresolved | Use as the conditional design direction and prove it at gates 1-4. |
| Six setup descriptors and order | Reusable protocol fact | Keep in portable request-builder/planner code. |
| Five-byte input record | Reusable protocol fact | Keep parser boundary independent of Windows transport. |
| Twelve-millisecond post-call sleep | Reusable evidence metadata only | Preserve as planner metadata; do not infer a device requirement. |
| Forward unrelated URBs | Reusable architecture concept | The filter must transparently pass traffic it does not own. |
| Dedicated Chatpad reader | Possible architecture concept | Consider only after pipe identity and ownership are proven. |
| `001f`/`001e` worker traffic | Unresolved | Do not schedule or send it. |
| Interface/pipe ordinal assumptions | Unresolved historical evidence | Never encode these ordinals without current descriptor evidence. |

## 7. Legacy defects and obsolete patterns

The following must not be reproduced:

- global "first device" selection and raw `PDEVICE_CONTEXT` pointers shared
  with a sideband control device;
- ignored creation failures and unconditional success from device-add paths;
- hard-coded interface and pipe ordinals without descriptor validation;
- replacing or parking ordinary controller reads merely to observe traffic;
- unchecked fixed-size copies into 80-byte and 32-byte buffers;
- synchronous ten-second kernel control transfers exposed through permissive
  user-mode IOCTLs;
- reusable request memory deleted while requests may still be active;
- callbacks, timers, threads, or work continuing after unplug;
- global worker state, infinite waits, incomplete partial-start cleanup, and
  shutdown dependent on a cooperative console path;
- treating transfer completion or logged bytes as Chatpad readiness;
- PnP ID spoofing and a custom KMDF-plus-WDM HID stack where a supported modern
  presentation mechanism may exist.

The legacy D0-exit and surprise-removal callbacks do not establish safe
quiescence. The legacy special case that avoids resubmission after
`STATUS_CANCELLED` is evidence of a real unplug hazard, not an adequate
lifetime model.

## 8. Candidate attachment points

### Candidate A: device-specific lower filter on the physical controller node

This matches the legacy attachment scope and is the only candidate with
historical evidence of both device-level control transfers and a separately
owned Chatpad read. A hardware-ID-specific lower filter could sit beneath
`xusb22`, forward ordinary traffic unchanged, and scope impact to `045E:028E`.
However, current Windows 11 access to the default control pipe, configuration
information, and the input transfer is not proven. It is the selected
architecture direction but remains **unresolved**, not preferred, until both
activation and input visibility pass gates 3 and 4.

### Candidate B: filter on the `IG_01` child/function node

The child exists, but inventory does not identify its semantics. There is no
evidence that a filter there can reach the parent device's default control
pipe, see interface-2-era traffic, or distinguish Chatpad packets. Attaching
there might affect only an existing controller/HID function while still
missing the required transport. It remains unresolved and is not selected.

### Candidate C: filter on the HID descendant

The descendant exposes an existing HID game-controller collection. Nothing
attributes it to the Chatpad, and HID reports do not imply access to the parent
USB default control pipe. This candidate is rejected for transport. It could
be reconsidered only if future non-invasive evidence directly identifies
Chatpad data in this collection.

### Candidate D: class-wide XNA or HID filter

A class filter could affect every XNA controller or every HID device in the
system. It provides no transport advantage over a device-specific attachment
and creates disproportionate recovery and compatibility risk. It is rejected.

### Candidate E: user-mode HID or WinUSB access

`xusb22` currently owns the physical controller. The HID descendant is not
proven to expose Chatpad data, and WinUSB cannot simply share ownership of a
function already bound to the Microsoft controller driver. Replacing the
binding could remove normal XInput behavior and requires a materially more
disruptive installation and recovery model. This is rejected for the primary
transport.

### Candidate F: separate virtual keyboard-output component

This is not an attachment point for controller transport. It is a possible
fallback boundary for presenting decoded keys after a safe transport exists.
Keeping it separate prevents keyboard policy and output technology from
controlling the physical Xbox stack. The technology choice remains unresolved.

## 9. Attachment decision matrix

| Candidate | Supporting evidence and narrow scope | Default control / incoming packet access | `xusb22`, lifecycle, and cancellation impact | Signing, HVCI, unrelated-device risk, and recovery | Unknowns | Recommendation |
| --- | --- | --- | --- | --- | --- | --- |
| A. Physical-node device lower filter | Exact `045E:028E` legacy INF and current physical node; can be device-specific | Legacy code reached device control and owned a read; neither is confirmed on Windows 11 | Must pass through all ordinary traffic, quiesce per device, and prove XInput preservation; highest transport/lifecycle complexity | Kernel signing and HVCI apply; narrow blast radius; recover by removing only the device filter package | Current default-pipe access, descriptors, input pipe, coexistence with `xusb22` | **Unresolved**; selected direction, cannot be preferred before gates 3-4 |
| B. `IG_01` child filter | Node is observed and could be targeted by an exact device/compatible ID rather than class-wide scope | No evidence of parent control-pipe or Chatpad-packet access | Could disturb an existing controller function; owns separate PnP/power state and would need child-queue cancellation/removal tests | Kernel signing/HVCI; low unrelated-device risk if exact-targeted; rollback removes the child filter | Function identity, stable targeting ID, lower transport reach | **Unresolved**, not selected |
| C. HID descendant filter | Existing HID collection is observed and could be device-targeted | No Chatpad attribution; no parent default-control evidence | Risks existing HID controller input; HID queue cancellation, D0, and removal must be handled | Kernel signing/HVCI; narrow if device-specific but wrong boundary; rollback removes the device filter | Report descriptor/data meaning and Chatpad attribution | **Rejected** for transport |
| D. Class-wide XNA/HID filter | Classes are known, but attachment cannot be limited to `045E:028E` by the class value | Does not prove either required path | Multiplies PnP/power/cancellation and compatibility exposure across every affected stack | Kernel signing/HVCI; highest unrelated-device risk; rollback must repair class state on all devices | No compensating capability | **Rejected** |
| E. User-mode HID/WinUSB | HID interface exists; WinUSB is a known generic transport, but rebinding would target a physical/function node | HID path unproven; WinUSB ownership conflicts with current binding | Binding replacement could remove XInput; user handles still need cancellation and removal detection | User-mode client is simpler, but INF/rebinding deployment is disruptive; unrelated-device risk is narrow if exact-targeted; recovery must restore `xusb22` | Shareability, default-control/input exposure, reconnect behavior | **Rejected** for primary transport |
| F. Separate virtual keyboard output | Decoded output needs a distinct presentation boundary; its virtual identity is independent of `045E:028E` targeting | Not applicable to USB activation/input | Preserves `xusb22` if isolated; has its own PnP/output queue cancellation and deletion lifecycle | VHF is present in installed WDK; kernel output still needs signing/HVCI validation; low physical/unrelated-device risk; rollback removes only virtual output | Kernel vs user-mode VHF integration, report contract, lifecycle | **Possible fallback** for output only |

No candidate is marked preferred because no current evidence supports both the
activation and input paths. Candidate A is nevertheless the only defensible
design direction on present evidence.

## 10. Recommended attachment architecture

The recommended target is the physical controller devnode matching
`USB\VID_045E&PID_028E`, with a **device-specific lower filter** beneath
`xusb22`. Installation must use a device install section matching that exact
hardware ID; it must not write `LowerFilters` or `UpperFilters` on the
`XnaComposite` or `HIDClass` class keys. Revision `0114` is observed evidence,
not an installation restriction unless later compatibility evidence requires
one.

The current `ChatpadFilter` lifecycle scaffold calls
`WdfFdoInitSetFilter(DeviceInit)`, but that API only makes the binary
filter-capable. Because this repository still has no INF, service binding,
package, signing, installation, or load path, the scaffold does not prove that
the `.sys` is attached to any stack, positioned beneath `xusb22`, or targeted
at `USB\VID_045E&PID_028E`. Those remain future installation and recovery
responsibilities.

This recommendation is conditional:

1. The filter forwards every request it does not explicitly own without
   changing buffers, status, timing, or cancellation behavior.
2. The transport remains dormant until D0 and validated hardware resources are
   available.
3. Gate 3 must prove default-control access and a relevant incoming-transfer
   path at this stack position.
4. Gate 4 must identify the input path without assuming legacy pipe ordinals.
5. Failure of either transport gate reopens the attachment decision; it does
   not justify proxying controller traffic or replacing `xusb22`.

Thus, Candidate A is recommended for architecture planning but remains
unresolved for implementation.

## 11. Activation control-request path

The conceptual path is:

```text
portable planner/executor
    -> Windows transport-adapter contract
    -> Windows request translation and per-device scheduler
    -> WDF USB request representation
    -> lower target/controller stack
```

- The portable builder owns the neutral setup direction, request, value,
  index, payload, and length. It must not include WDF or USB handles.
- The planner owns sequence order and confirmed 12 ms post-completion metadata.
- The executor owns transport-independent step progression and reports only
  transport outcomes defined by its existing contract.
- A Windows adapter validates each descriptor and translates it into a WDF
  control-request representation. It does not invent setup bytes, retries,
  acknowledgements, or ready states.
- A per-device transport object owns each request, memory object, cancellation
  token/generation, and completion context.
- Completion is observed at the adapter boundary and translated back into a
  neutral result. Successful USB completion proves only that one transfer
  completed; it does not prove Chatpad activation or readiness.
- The 12 ms metadata, if later authorized, belongs in a cancelable per-device
  scheduler after completion. It must not be a blocking sleep in an I/O,
  completion, power, or PnP callback.
- Cancellation on D0 exit or removal wins over scheduling. No next request may
  be created after the device generation enters stopping/removed state.

The legacy implementation demonstrates that such device-level transfers were
possible in its old stack. It does not confirm that a Windows 11 Candidate A
filter can issue them. No translation or request submission should be written
until gate 3 passes.

## 12. Incoming Chatpad packet path

The transport must eventually deliver exactly one complete five-byte record to
the portable parser without transferring ownership of WDF buffers or handles.
Possible acquisition paths are:

| Path | Evidence and required position | Disruption risk | Evidence required before implementation |
| --- | --- | --- | --- |
| Observe existing interrupt-transfer completions | A lower USB-stack position can observe forwarded URBs in principle; legacy code intercepted internal USB submissions | Observation may alter completion/cancellation ordering; `xusb22` may never request Chatpad data | Prove a distinct existing transfer carries five-byte Chatpad records and can be observed transparently |
| Own continuous reader | Legacy used two independently submitted reads on interface 2, pipe 0 | Competing for a pipe may consume data or conflict with `xusb22`; a filter may not own/configure the pipe | Current descriptors, pipe ownership, target support, read size, cancellation, and non-interference proof |
| Intercept internal USB submissions/completions | Legacy observed `IOCTL_INTERNAL_USB_SUBMIT_URB` and select-configuration URBs | Proxying/parking upper URBs is high risk; completion hooks can become stale on removal | Prove which URB carries the data and use observation-only forwarding first; never assume ordinal indices |
| Receive through `IG_01`/existing HID | Those descendants are present | Filtering the wrong function can disrupt controller/HID input and still omit Chatpad | Report/interface semantics that directly attribute five-byte Chatpad data to the node |
| Legacy sideband read queue | User mode received packets through filter IOCTLs | Adds an unnecessary public control surface and repeats global-lifetime hazards | Not selected; any diagnostic boundary must be internal, authenticated/scoped, and separately justified |

The legacy own-reader path is the strongest historical input evidence, but its
interface-2/pipe-0 assumption is not portable evidence. No endpoint address,
pipe ordinal, transfer type, or continuous-reader configuration is selected.

## 13. Portable versus Windows-specific layers

A future source layout may be:

```text
src/protocol/ChatpadProtocol/
    portable parser, state machine, request builder, planner, executor

src/driver/ChatpadFilter/
    KMDF attachment, PnP/power lifecycle, per-device context

src/driver/ChatpadTransport/
    adapter contract implementation, WDF request translation,
    inbound packet acquisition, cancelable timing, diagnostics boundary

src/driver/ChatpadKeyboard/
    future keyboard presentation and report lifecycle
```

Dependencies flow in one direction:

```text
ChatpadFilter -> ChatpadTransport -> ChatpadProtocol
ChatpadKeyboard -> ChatpadProtocol data/output contract
```

`ChatpadProtocol` must never include WDF, USB, PnP, HID, timer, or Windows
handle types. `ChatpadTransport` adapts neutral descriptors and produces owned
five-byte copies. `ChatpadFilter` owns the device lifetime and authorizes when
the adapter may operate. Scheduling is Windows-specific but consumes portable
metadata. Keyboard presentation consumes semantic output and never calls the
physical USB transport.

Diagnostics use bounded, non-sensitive event records and opaque per-device
generation IDs. Tests inject mocks at the neutral adapter contract, inbound
packet sink, scheduler, lifecycle state, and keyboard-output contract. No
circular dependency or global device registry is needed.

## 14. PnP, power, cancellation, and removal model

Each `WDFDEVICE` owns one context and one monotonically changing generation.
Conceptual states are `Added`, `Prepared`, `D0`, `Stopping`, and `Removed`.

- **Device add:** create only parented state, queues, locks, and dormant
  contracts. Do not select a global first device.
- **Prepare hardware:** validate translated resource/target assumptions and
  create parented transport objects. Any failure unwinds completely. No USB
  request is submitted merely because prepare succeeded.
- **D0 entry:** move to an operable generation only after resources and policy
  permit it. Hardware traffic still requires the later authorization gate.
- **D0 exit:** atomically block new work, stop the scheduler/reader, cancel
  outstanding requests, wait for rundown where required, and then mark the
  generation inactive.
- **Release hardware:** release pipe/interface/USB-target references only after
  request completions and workers can no longer access them.
- **Surprise removal:** atomically enter stopping, reject new operations,
  cancel all owned requests, drain callbacks/work items, complete clients with
  removal status, and release hardware in parent-child order.
- **Orderly removal:** use the same idempotent quiesce path before deleting the
  context.

Teardown order is scheduler/timer, new-request admission, outstanding
requests, continuous reader, completion/work-item rundown, pipe/interface
references, USB target, and finally device context. Completion contexts hold a
WDF parent reference or explicit rundown reference plus the generation they
were created under. A completion for an old generation can release resources
but cannot schedule new work or publish input.

No raw context pointer may outlive its parent. No global sideband object may
select a device context by collection order. No worker or timer may be owned by
process-global state. These rules directly replace the legacy global pointer,
weak D0-exit, cancellation race, and post-unplug resubmission patterns.

## 15. Keyboard-output architecture options

Keyboard presentation is downstream of decoded protocol state and is not part
of physical controller attachment.

| Option | Boundary and signing | Compatibility and controller preservation | Evidence/prototype required |
| --- | --- | --- | --- |
| Separate virtual HID keyboard child/device | Kernel-created HID presentation; requires a signed, HVCI-compatible driver package | Clean separation if its lifetime is independent of `xusb22`; report/device lifecycle adds kernel complexity | Validate supported enumeration model, report descriptor, parentage, cancellation, and removal in a non-hardware scaffold |
| Windows Virtual HID Framework (VHF) | Installed WDK 10.0.26100.0 supplies `shared/vhf.h`, kernel `vhfkm.lib`, and user-mode VHF libraries; kernel use still requires compliant signing/deployment | Supported framework avoids legacy HID minidriver/ID-spoofing design and need not replace `xusb22` | Compile-only isolated prototype must validate target versions, KMDF/WDM ownership, callbacks, report flow, deletion, and HVCI before selection |
| Legacy keyboard-class injection/minidriver layering | Multiple kernel drivers and filters; highest signing/deployment burden | PnP ID spoofing and upper-filter layering create compatibility risk even if controller transport is separate | Rejected; no prototype planned |
| User-mode companion | User process may own mapping, settings, and diagnostics; it should not own the USB transport | Process/session/security lifetime can make synthetic input unreliable; generic input injection is not equivalent to a keyboard device | Define security/session requirements and prove an approved output API before considering it |

VHF is an evidence-supported option because the installed WDK exposes it for
Windows 10-and-later targets. It is not definitively selected. No semantic key
mapping, descriptor, report format, or transport-to-output coupling is defined
here.

## 16. Security, signing, and HVCI considerations

- Any physical-stack filter or kernel virtual keyboard requires a current
  signed package and must pass the separate install/deployment gate.
- Design and validation must assume Secure Boot and Memory Integrity remain
  enabled. Disabling either is not a recovery strategy.
- Use NX/nonpaged-safe allocations, valid IRQL contracts, WDF ownership,
  checked lengths and arithmetic, bounded buffers, and no writable executable
  memory, unsupported hooks, or self-modifying behavior.
- Do not expose a general USB-control IOCTL. If a diagnostic/control surface is
  later justified, restrict access, validate every byte and operation, bind it
  to one live device generation, and keep arbitrary setup packets impossible.
- Do not log instance-specific paths, serial-like IDs, payloads unrelated to
  Chatpad protocol, key content, or machine-private identifiers.
- A device-specific INF must not create class-wide filters. Package removal and
  restoration of the Microsoft binding must be validated before install.
- VHF or another output technology must be validated independently for target
  OS/version, signing, HVCI, and teardown behavior.

## 17. Diagnostics and observability

Future diagnostics should make preservation and teardown failures visible
without capturing unrelated controller payloads. Useful bounded events are:

- device generation and lifecycle transition;
- selected attachment identity in redacted VID/PID form;
- request sequence index, neutral setup tuple, byte count, transport status,
  cancellation cause, and elapsed time;
- reader start/stop, complete-record count, malformed length count, and stale
  generation drops;
- scheduler cancellation and teardown completion;
- keyboard-output queue state without logging key contents.

Diagnostics must distinguish "request completed" from "Chatpad ready". ETW,
USB capture, device handle use, and live descriptor queries are not authorized
by this document and require separate evidence tasks.

## 18. Testing strategy

1. Keep all portable tests running in user mode and kernel compile checks.
2. Add contract tests for descriptor translation using fake Windows-neutral
   structures before any WDF request exists.
3. Add deterministic lifecycle tests for every state transition, cancellation
   race, duplicate removal, stale generation, partial creation failure, and
   teardown ordering.
4. Mock completion, scheduler, inbound packet sink, and keyboard output. Prove
   no retry, acknowledgement, readiness, or post-removal scheduling appears.
5. Build a non-installable WDF scaffold only after the adapter contract is
   stable; use static analysis and compile validation without USB submissions.
6. Separately validate any keyboard presentation prototype with no dependency
   on a connected controller.
7. Only after gates 1-7 pass may a controlled hardware test be proposed. It
   must establish normal controller behavior before and after each single
   change and have an immediate rollback path.

## 19. Recovery and rollback strategy

Before any future package is installed, record the Microsoft binding and
prepare an offline, documented way to remove only the development package and
device-specific filter value. Recovery must restore `xusb22` without changing
class-wide state, Secure Boot, Memory Integrity, or unrelated devices.

A hardware test must have a second input method, administrative recovery path,
package identity, uninstall commands, expected Device Manager state, and a
stop owner. If the controller, XInput, HID descendant, or unrelated device
changes unexpectedly, stop immediately; do not retry requests or layer another
driver change over the failure. Restore the Microsoft-only stack and verify
the baseline before further analysis.

## 20. Evidence and stop gates

| Gate | Evidence required | Safe test method | Pass criterion | Stop condition | Rollback requirement |
| --- | --- | --- | --- | --- | --- |
| Gate 1. Attachment decision | Exact devnode and upper/lower position tied to stable IDs | Documentation/INF translation review using cached inventory and legacy source; no install | Review agrees on physical `045E:028E` node and device-specific lower filter | Node/position ambiguity or class-wide requirement | No mutation; revise design |
| Gate 2. Stack preservation | Explicit pass-through, queue, completion, and baseline XInput plan | Mock/static lifecycle review, then separately authorized non-I/O scaffold | Every unowned request is forwarded unchanged; baseline checks and abort criteria are specified | Any design parks/proxies ordinary traffic or requires replacing `xusb22` | Remove scaffold/package if later installed; restore Microsoft-only stack |
| Gate 3. Transport visibility | Proof chosen layer can reach default control and a relevant incoming transfer | Separately authorized, observation-first task using the least invasive supported mechanism; no activation | Both paths are attributable to Candidate A without guessing or consuming traffic | Either path is inaccessible, ambiguous, or disrupts controller operation | Stop observation, unload/remove only under its approved recovery procedure |
| Gate 4. Endpoint/input evidence | Current interface/endpoint or transfer-path identity, sizes, ownership, cancellation behavior | Separately authorized descriptor/trace/stack evidence task; one method and one change at a time | Evidence identifies the five-byte record path and safe ownership model | Only legacy ordinals, inferred HID identity, or unexplained traffic is available | Return to untouched Microsoft stack and retain only sanitized evidence |
| Gate 5. Safe lifecycle scaffold | Tested PnP/power/removal state machine with no hardware I/O | Fully mocked tests plus non-installable compile/static validation | Cancellation, partial failure, D0 exit, surprise removal, restart, and stale completions pass deterministically | Any request/work can outlive its device generation | Delete/disable scaffold changes before proceeding; no hardware was touched |
| Gate 6. Recovery plan | Exact package/filter removal and `xusb22` restoration procedure | Peer review and offline rehearsal where possible, without target-device mutation | Recovery owner, commands, alternate input, and baseline verification are complete | Recovery depends on disabling security or an unavailable controller | No install authorization |
| Gate 7. Explicit authorization | A later task explicitly names the hardware action, exact request set, limits, observation, and abort criteria | One authorized run only after gates 1-6 pass | Authorization and preflight match; normal controller baseline is healthy | Missing/mismatched authorization, gate regression, or baseline failure | Send nothing; if already installed, execute gate-6 restoration |

Failure at a gate is a hard stop. Passing a documentation or compile gate never
implicitly authorizes installation, device access, capture, or USB traffic.

## 21. Unresolved questions

- Can a Windows 11 device-specific lower filter beneath `xusb22` create or
  access a supported default-control target without taking configuration
  ownership from the function driver?
- Which current interface, endpoint, or existing request carries five-byte
  Chatpad input?
- Does `xusb22` already submit relevant reads, or must a compatible owner create
  a continuous reader?
- What do the opaque controller interface and `IG_01` function expose?
- Are legacy interface 0/2 and pipe 0/1 ordinals stable, incidental, or obsolete?
- What bytes follow the control-IN calls, and what objective observation would
  prove readiness?
- What are the `40/a9`, `001f`, `001e`, and `f0` semantics?
- Which VHF ownership model best fits a future isolated keyboard component, and
  does it pass the target signing/HVCI/lifecycle constraints?

## 22. Smallest safe implementation task

Define a kernel-safe, transport-adapter interface and a fully mocked,
WDF-independent implementation. The task should connect the existing portable
executor to a neutral adapter contract, model cancellation/generation outcomes,
and test translation inputs without creating WDF requests, timers, USB targets,
device handles, INF files, or hardware behavior.

This task is safe while Candidate A remains unresolved because it establishes a
test seam rather than claiming a Windows transport capability. It must not
begin as part of this architecture task.

## 23. Explicitly deferred work

- WDF USB/control-request translation and submission;
- interface, configuration, alternate-setting, endpoint, or pipe discovery;
- continuous readers, URB interception, proxy reads, and captures;
- activation, periodic requests, response interpretation, acknowledgements,
  retries, timeouts, readiness, and semantic key mappings;
- INF, CAT, certificates, packaging, signing, installation, deployment,
  loading, Device Manager changes, or service changes;
- VHF or other keyboard implementation;
- Chatpad detach/reattach, controller disconnect/reconnect, reset, disable,
  enable, restart, or live behavior testing.

A later controlled evidence task may use one physical action—preferably a
Chatpad-only detach/reattach while the controller remains connected, followed
only if necessary by a full controller reconnect—to correlate topology or input
behavior. It must be explicitly authorized, define a healthy XInput baseline,
permit only one physical change at a time, send no activation traffic unless
separately authorized, and use the gate-6 recovery and hard-stop criteria.

## 24. Transport-adapter contract checkpoint

Branch `feature/transport-adapter-contract` completed the smallest safe task
from section 22 without changing the Windows attachment decision. The new
`src/transport/ChatpadTransport/` static library is a neutral contract and
mockable adapter surface only:

- caller-owned adapter state;
- explicit device generation;
- generation-bound operation tokens;
- activation request value copies from the existing protocol descriptors;
- delay metadata value copies from the existing activation executor;
- cancellation, stale generation, stale completion, duplicate completion, and
  unknown completion classification;
- callback-based plan emission to a caller-supplied sink.

The transport contract intentionally has no WDF/WDM/USB/HID/SetupAPI/
Configuration Manager/WinUSB/IOCTL/URB/device-handle/endpoint/pipe behavior,
does not sleep or run timers, and does not interpret responses, readiness,
acknowledgements, retries, or hardware success. The test-only mock sink lives
under `tests/transport/fixtures/` and records bounded operations for
deterministic offline tests.

This checkpoint satisfies Gate 5 only at the portable/mock contract level. It
does not prove Candidate A can access default control or incoming Chatpad data,
and it does not authorize driver installation, live hardware requests, or
transport traffic.

## 25. KMDF transport bridge design checkpoint

`docs/WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md` defines the future bridge
between the portable activation executor, the neutral transport adapter, a
per-device KMDF transport owner, and later WDF USB request translation. It
keeps the selected physical-node lower-filter architecture conditional on
future evidence and does not implement or authorize runtime transport behavior.

The bridge design selects one future owner under `WDFDEVICE` for bounded
activation bridge state, request-owner records, future target references,
future delay scheduler state, diagnostics, and separate continuous-input state.
Each future WDF request must be tied to one nonzero lifecycle D0 generation and
one portable `ChatpadTransportOperationToken`; raw request pointers must not be
used as generation or operation tokens.

The recommended first synchronization model is a per-device `WDFSPINLOCK` for
short shared-state transitions. The existing lifecycle core remains externally
serialized and must not be treated as internally thread-safe. D0 exit closes
admission before request cancellation and before delay scheduling; completions
must release lifecycle outstanding counts exactly once and reject stale or
duplicate completions without mutating the current generation.

The design also preserves activation and continuous input as separate
architectures. The existing transport adapter's 64-operation tracking is
suitable only for bounded activation work. Continuous input still requires
separate endpoint/input evidence, a bounded read owner, generation-bound
cancellation, parser delivery by value, and preservation of ordinary `xusb22`
traffic.

The smallest safe next coding task is pure setup translation: map the six
neutral `ChatpadActivationRequest` descriptors into a caller-owned,
WDF-independent Windows control-setup representation with offline tests and
kernel compile validation only. That task must not create targets, requests,
queues, timers, endpoints, INF/package/signing/install behavior, or hardware
traffic.
