# Windows 11 KMDF Transport Bridge Design

## 1. Scope

This document defines a documentation-only design for a future Windows KMDF
transport bridge:

```text
ChatpadActivationExecutor
-> ChatpadTransportAdapter
-> per-device KMDF transport owner
-> future WDF USB request translation/submission
```

It defines ownership, generation binding, synchronization, request lifetime,
cancellation, stale-completion handling, delay metadata ownership, diagnostics,
and stop gates. It does not implement runtime transport behavior and does not
authorize USB, HID, IOCTL, URB, WDF request, endpoint, pipe, installation,
signing, packaging, deployment, loading, capture, or live hardware activity.

## 2. Current project position

The repository currently has three relevant layers:

- `ChatpadActivationExecutor` emits six activation request operations and six
  delay-metadata operations from confirmed legacy setup descriptors.
- `ChatpadTransportAdapter` is a portable, WDF-independent static-library
  contract with caller-owned state, generation-bound operation tokens, bounded
  activation operation tracking, cancellation, stale generation, stale
  completion, duplicate completion, and deterministic offline tests.
- `ChatpadFilter` is a compile-only KMDF filter-capable scaffold with per-device
  lifecycle state. It is unsigned, non-installable, and disconnected from the
  protocol and transport projects at runtime.

No default-control-pipe access, input endpoint, transfer ownership, lower-filter
installation, response semantics, acknowledgement, readiness, retry, timeout,
or keyboard presentation path is proven.

## 3. Existing portable and KMDF boundaries

`ChatpadProtocol` owns portable request descriptors, planner metadata, executor
emission, five-byte packet parsing, and neutral state classification. It has no
Windows, WDF, USB, HID, IOCTL, request, timer, endpoint, pipe, allocation, or
hardware dependency.

`ChatpadTransportAdapter` owns a bounded activation adapter contract. It may
copy `ChatpadActivationRequest` values, emit delay metadata values, allocate
portable operation tokens, and classify cancellation or stale completions. Its
64-operation tracking limit is suitable only for bounded activation work.

`ChatpadFilterLifecycle` owns per-device lifecycle phases, nonzero D0
generation epochs, operation admission, outstanding abstract operation count,
and rundown state. It is externally serialized by its caller.

`ChatpadFilter` owns the future `WDFDEVICE` lifetime, but today it registers
only lifecycle callbacks and does not own a USB target, WDF request, queue,
timer, work item, endpoint, or transport bridge.

## 4. Design goals

- Preserve one per-device ownership boundary under `WDFDEVICE`.
- Bind every future runtime operation to exactly one nonzero D0 generation.
- Pair lifecycle operation acquisition and release exactly once.
- Keep activation request translation inspectable and testable offline.
- Ensure cancellation closes admission before teardown and rejects stale work.
- Prevent duplicate request completion from corrupting current state.
- Keep delay metadata as cancelable scheduling metadata, not blocking sleep.
- Keep continuous input separate from bounded activation operations.
- Define stop gates before source implementation can progress.

## 5. Non-goals

This design does not select an endpoint, pipe, interface, queue, timer, work
item, descriptor query, response schema, acknowledgement condition, readiness
condition, retry policy, input reader, key mapping, VHF output path, INF,
catalog, package, service, installation, signing, deployment, driver load, live
hardware test, ETW provider, or capture workflow.

It also does not add fields to source, modify projects, connect
`ChatpadTransport` to `ChatpadFilter`, or send any request.

## 6. Proposed per-device context ownership

A future per-device context should conceptually separate these fields:

| Context area | Owner | Purpose |
| --- | --- | --- |
| Existing lifecycle core state | `WDFDEVICE` context | Resource and D0 generation phases, admission, rundown count. |
| Existing transport-adapter state | `WDFDEVICE` context | Bounded activation operation tokens for the current D0 generation. |
| Future KMDF request-owner table | `WDFDEVICE` context | Generation-bound records for owned activation requests. |
| Future synchronization object | `WDFDEVICE` context | Serializes lifecycle, bridge, request table, scheduler, and diagnostics state. |
| Future USB target reference | `WDFDEVICE` child object or context field | Holds an authorized lower target only after a later gate. |
| Future delay scheduler | `WDFDEVICE` child object | Owns cancelable delay metadata interpretation if a timer/work item is selected. |
| Diagnostics | `WDFDEVICE` context | Bounded neutral counters and event sequence IDs. |
| Future continuous-input state | Separate `WDFDEVICE` owned area | Bounded input reads and parser delivery, not activation tracking. |

No global mutable device state is allowed. No sideband object may select a
device by collection order.

Future object parenting should follow this model:

- `WDFDEVICE`: bridge state, lock, transport adapter state, request-owner table,
  target reference, scheduler object, continuous-input owner, diagnostics.
- Individual `WDFREQUEST`: one request-owner record or request context that
  carries generation, portable operation token, activation step, operation type,
  cancellation flag, and completion-once state.
- Timer or work item, if later selected: parented to `WDFDEVICE`; callbacks
  must carry or validate the originating generation before touching bridge
  state.

## 7. Bridge state model

The conceptual bridge state is dormant until PrepareHardware succeeds and D0
entry opens a generation. A future state model should distinguish:

- `Unprepared`: device object exists; no target or scheduler ownership.
- `Prepared`: future targets and bookkeeping are created or acquired, but no
  activation is running.
- `D0Active`: lifecycle generation is nonzero; transport adapter is initialized
  for the same generation; admission is open.
- `Stopping`: admission is closed; owned requests and scheduler work are being
  canceled; stale callbacks are rejected.
- `Stopped`: outstanding operation count is zero; generation is no longer
  active.
- `Released`: targets and scheduler objects are released in order; callbacks
  cannot reference released state.

Portable lifecycle state remains authoritative for D0 generation and outstanding
operation admission.

## 8. Lifecycle and generation integration

### PrepareHardware

PrepareHardware must validate the lifecycle state first. Only after a later
gate authorizes it may this callback create or acquire a lower I/O target. It
should initialize bridge bookkeeping, clear request-owner records, and mark
scheduler state inactive. Preparation must not begin activation merely because
resources were prepared.

### D0Entry

D0Entry starts a new lifecycle generation through `ChatpadFilterLifecycleEnterD0`.
The returned nonzero generation is copied into the bridge and used to initialize
`ChatpadTransportAdapter` for bounded activation work. Operation admission is
open only for that generation. D0Entry may make activation eligible after later
gates, but it must not claim activation occurred.

### D0Exit

D0Exit closes admission first by beginning lifecycle rundown for the current
generation. It then requests cancellation of owned WDF requests, prevents new
delay scheduling, and rejects stale callbacks. The callback should be wait-free
at the point where this scaffold currently returns; completion of D0 exit is
allowed only when rundown evidence says outstanding operations are zero.

KMDF asynchronous completion normally means lower-stack request completions may
arrive after cancellation is requested. A future implementation must either
complete D0 exit only after a framework-approved rundown path observes all
request completions, or return a deterministic busy/pending outcome according
to the selected PnP/power strategy. That exact callback/wait strategy is not
implemented by this design.

### ReleaseHardware

ReleaseHardware requires completed D0 rundown. It releases scheduler ownership,
request-owner storage, target references, and bridge ownership in a defined
order. After release, no callback may hold an unprotected pointer to per-device
state.

## 9. Synchronization strategy

The existing lifecycle core is not internally thread-safe. The following fields
require protection as one per-device unit: lifecycle state, transport adapter
state, request-owner table, target reference, scheduler state, cancellation
flags, completion-once flags, continuous-input owner state, and diagnostics
counters.

| Option | IRQL compatibility | Lifecycle state | Completion paths | Delay scheduling | Blocking risk | Cancellation/rundown complexity | Classification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| KMDF automatic synchronization scope | Depends on queue/callback configuration; not enough by itself for all future callbacks | Useful for selected callbacks but easy to miss timer/completion paths | Does not automatically cover arbitrary completion and timer state unless configured consistently | Partial | Low if passive constraints are clear | Medium; hidden callback coverage risk | Possible fallback |
| Per-device `WDFWAITLOCK` | Passive-level only | Good if all protected callbacks are passive | Not suitable for DISPATCH_LEVEL completion paths | Good for passive scheduler logic | Can block; must not be held across request submission or waits | Medium; simple but IRQL-limited | Possible fallback for passive-only prototype |
| Per-device `WDFSPINLOCK` | DISPATCH_LEVEL capable | Good for small state transitions | Good for completion-once flags and request table updates | Only for brief state changes, not timer work bodies | Must not block; keep critical sections tiny | Medium; requires strict no-blocking discipline | Recommended first implementation strategy |
| Passive serialized work item or queue ownership | Passive-level worker owns mutations | Good if all mutations are marshaled | Completion paths must enqueue work without touching much shared state | Good for sequenced scheduler state | Queueing can delay teardown; cannot be required for urgent cancel flags | High; more moving pieces | Possible fallback for higher-level orchestration |
| Unsupported lock-free use | Unsafe unless proven by atomics and memory ordering | Not suitable | Not suitable | Not suitable | Low apparent blocking, high data-race risk | High and fragile | Rejected |

Recommended first implementation strategy: use a per-device `WDFSPINLOCK` for
short bridge state transitions, request-owner table updates, lifecycle
admission pairing, completion-once checks, cancellation flags, and generation
validation. Do not hold it while formatting, submitting, waiting, allocating, or
calling into a lower target. If later design requires passive-only APIs, wrap
those in a separate passive work item but keep the generation and
completion-once decisions protected by the same per-device state model.

The callbacks that must share synchronization are PrepareHardware,
ReleaseHardware, D0Entry, D0Exit, future request completion callbacks, future
timer/work-item callbacks, surprise-removal cleanup, and any future activation
start path.

## 10. Abstract operation admission

Every future WDF request operation must first acquire a lifecycle operation for
the current nonzero generation. Acquisition creates an abstract outstanding
operation count, not a WDF request. If request allocation, formatting, or
submission fails after acquisition, the same generation must be released exactly
once.

D0 exit begins by closing admission. After that point no request, delay, or
continuous-input operation may acquire a new lifecycle count. Stale-generation
acquire attempts reject without mutating current state.

## 11. WDF request ownership model

A future request-owner record should conceptually contain:

- D0 generation;
- portable `ChatpadTransportOperationToken`;
- activation step index;
- operation type;
- owned WDF request handle;
- cancellation requested flag;
- submitted flag;
- completion-once flag;
- lifecycle operation acquired flag;
- final neutral completion classification.

The per-device KMDF transport owner creates the request after lifecycle
admission succeeds. The request is parented so that the device owns lifetime,
and the record is discoverable by completion through request context or a
device-owned table. The future formatter owns translating inspected setup data
into a WDF representation. The future submitter owns sending to the lower
target only after an explicit authorization gate.

Only the per-device owner may request cancellation. Completion owns the request
long enough to atomically mark completion-once, classify stale/duplicate/current
status, release the lifecycle outstanding count exactly once, and prevent
follow-on scheduling if the generation is no longer current.

Raw request pointers must not be generation IDs or portable operation tokens.
The portable token identifies an abstract activation operation. The request
record maps that token to one WDF request for one D0 generation.

## 12. Activation request translation boundary

A future pure translation boundary should map `ChatpadActivationRequest` to an
inspectable Windows control-setup representation:

| Source field | Future setup representation |
| --- | --- |
| `RawBmRequestType` | `bmRequestType` byte. |
| `RawRequest` | `bRequest` byte. |
| `RawValue` | little-endian 16-bit value. |
| `RawIndex` | little-endian 16-bit index. |
| `RawLength` | little-endian 16-bit length. |
| `OutboundPayloadLength` | host-to-device payload byte count. |
| `ExpectedInboundDataLength` | device-to-host expected byte count. |

Translation is not submission. Setup creation is not evidence that the Windows
11 stack permits default-control access. Control-IN response contents remain
unresolved. `09 00` remains the only confirmed outbound payload. `90 00` must
remain absent.

Recommended next coding shape: two layers, starting with a pure
WDF-independent Windows setup model and offline tests, followed later by a WDF
formatter only after the pure model is proven. This gives the strongest offline
testability and keeps WDF request creation deferred.

## 13. Delay-metadata scheduling boundary

The planner exposes 12 ms after each activation step as metadata only. A future
per-device scheduler owns interpretation of that metadata after the prior
request's completion policy permits progression.

| Option | Assessment | Classification |
| --- | --- | --- |
| Per-device KMDF timer | Cancelable and generation-bound if parented to `WDFDEVICE`; callback must validate generation. | Recommended for later implementation after gate review |
| Serialized passive work item | Useful if passive-only APIs are needed; more teardown ordering and queue-drain complexity. | Possible fallback |
| Completion-driven state machine | Good for deciding when a delay becomes eligible; still needs a cancelable timer for elapsed-time metadata. | Recommended as orchestration, not as elapsed-time mechanism |
| Blocking sleep | Blocks power/completion paths, cannot participate cleanly in cancellation, and fabricates active timing behavior. | Rejected |

Delay metadata does not begin until the prior request completes according to the
future policy. No acknowledgement semantics exist. Timer cancellation must
participate in D0 rundown. A timer callback must carry or validate the
originating generation. Stale timer callbacks must do nothing except record a
neutral stale result. No timer is added by this task.

## 14. Completion and stale-completion handling

The completion model separates:

1. request submitted;
2. request completed by the lower stack;
3. completion status received;
4. portable transport token completed;
5. activation step allowed to advance;
6. Chatpad readiness, which remains unknown.

Treatment by case:

| Case | Required treatment |
| --- | --- |
| Successful lower-stack completion | Mark completion-once, release lifecycle count, complete portable token as lower-stack success only, then decide whether delay metadata may be scheduled. |
| Cancelled request | Mark completion-once, release lifecycle count, classify cancellation, do not schedule follow-on activation. |
| Device removed | Mark cancellation/removal, reject new work, release current outstanding records as completions arrive, and avoid touching released targets. |
| Stale generation | Release only resources owned by that stale record; do not mutate current generation or schedule new work. |
| Duplicate completion | Ignore after recording a neutral duplicate result; do not release lifecycle count twice. |
| Malformed internal ownership record | Fail closed: no scheduling, no pointer chasing, record diagnostic, and require recovery/teardown. |
| Control-IN data with unknown semantics | Preserve byte count/status as unresolved evidence only; do not invent acknowledgement or ready state. |

## 15. Cancellation and rundown

D0 exit and removal first close lifecycle admission for the current generation.
The bridge then marks cancellation requested, prevents scheduler creation,
requests cancellation of owned WDF requests, and waits only through the selected
KMDF-safe nonblocking rundown strategy.

Each request-owner record pairs one successful lifecycle acquire with exactly
one release. Cancellation does not erase records before completion paths can
classify them. Stale and duplicate completions must not decrement outstanding
counts unless their record still owns an unreleased lifecycle operation.

## 16. D0 exit and ReleaseHardware ordering

Ordering:

1. Close abstract operation admission.
2. Stop future delay scheduling.
3. Mark per-device bridge cancellation requested.
4. Request cancellation of owned WDF requests.
5. Let completion paths release acquired lifecycle counts.
6. Complete D0 exit only when outstanding count is zero.
7. Release scheduler objects.
8. Release request-owner storage.
9. Release future target references.
10. Clear bridge ownership.

ReleaseHardware must run only after D0 rundown is complete or when D0 never
became active. It must not free a target, scheduler, or request-owner table
while a completion or timer callback can still reference it.

## 17. Surprise removal and failed-request behavior

Surprise removal uses the same path as D0 stop, but removal status wins over
normal activation progression. The bridge rejects new work, cancels owned
requests, prevents new delays, and accepts only cleanup-oriented completions for
the old generation.

Failed allocation, formatting, or submission after lifecycle acquisition must
release the acquired abstract operation before returning. Failed lower-stack
completion does not imply Chatpad protocol failure; it is classified as a
transport completion status and stops activation progression until a later task
defines a recovery policy.

## 18. Diagnostics and observability

Future neutral log events:

- bridge generation start/end;
- operation admitted/rejected;
- request allocated/formatted/submitted;
- cancellation requested;
- completion accepted/stale/duplicate;
- delay metadata scheduled/cancelled/stale;
- rundown count;
- removal.

Logs must exclude raw pointers, device instance IDs, machine-specific paths,
unbounded payload dumping, private data, and key contents. Payload diagnostics
should be limited to bounded setup metadata and the confirmed activation
payload length/value where required by offline validation.

No logging source is added by this task.

## 19. Memory and object lifetime

All bridge state is device-owned. Request records are either request-context
owned or indexed in a device-owned table protected by the per-device lock.
Scheduler objects are parented to `WDFDEVICE`. No raw context pointer may be
retained past the parent object's lifetime without a framework reference or
explicit rundown ownership.

Objects are released in reverse dependency order: scheduler, request owner,
continuous-input owner, target references, then bridge bookkeeping. Current
generation state is invalidated only after outstanding counts are zero.

## 20. Activation versus continuous-input separation

Activation is bounded: six request operations and six delay metadata operations
for the current planner. `ChatpadTransportAdapter`'s 64-operation tracking must
not become the continuous-input architecture.

Continuous input needs separate future concepts:

- bounded number of in-flight reads;
- explicit repeated read resubmission policy;
- generation-bound request ownership;
- cancellation on D0 exit and removal;
- five-byte packet delivery into the portable parser by value;
- preservation of normal `xusb22` traffic.

No endpoint, transfer type, pipe ordinal, interception method, continuous
reader, or submission strategy is selected without evidence.

## 21. Test seams and mock strategy

Future tests should remain offline until explicit gates reopen runtime scope:

- pure activation setup translation tests for all six descriptors;
- lifecycle plus transport-adapter generation pairing tests;
- mock request-owner tests for acquire/release pairing;
- stale completion, duplicate completion, cancellation, D0 exit, and generation
  replacement tests;
- delay scheduler mock tests for stale/cancelled generation callbacks;
- continuous-input separation tests that prove activation tracking is not used
  for repeated input reads;
- WDK compile-only checks that create no target, request, INF, CAT, package,
  signing, install, deployment, load, or hardware path.

## 22. Security, HVCI, and signing implications

Runtime bridge implementation would be kernel code and must assume Secure Boot
and Memory Integrity remain enabled. It must use bounded buffers, checked
lengths, no arbitrary USB-control IOCTL surface, no class-wide filter state, no
machine-private logging, and no writable executable memory.

Any future package, request submission, physical-stack filter, or virtual
keyboard output requires a separate signed-package and recovery gate. This
design does not create or authorize such a package.

## 23. Recovery and rollback

Before any future install or hardware test, the project needs a reversible,
device-specific lower-filter installation and removal plan that restores the
Microsoft `xusb22` binding without class-wide filter changes or security
weakening. A later physical action may be useful only after stack visibility and
installation recovery gates pass, and only with explicit authorization for one
controlled experiment.

Potential future physical actions include a Chatpad-only detach/reattach while
the controller remains connected, or a full controller reconnect if needed.
Those actions remain deferred until recovery, stack visibility, and explicit
authorization gates pass.

## 24. Implementation stop gates

| Gate | Required evidence | Pass criterion | Stop condition | Rollback requirement |
| --- | --- | --- | --- | --- |
| Gate A - synchronization | Reviewed callback/IRQL and locking model covering lifecycle, completion, scheduler, removal, and diagnostics | One per-device synchronization strategy is selected and all protected fields/callbacks are listed | Any callback can mutate shared state outside the model | No source implementation; revise design |
| Gate B - request ownership | Creation, parenting, formatting, submission, cancellation, completion-once, and lifecycle release rules | Each request has one generation, one portable token, and one completion/release path | Request pointer aliases tokens or lifecycle release can happen twice | Remove/disable request-owner changes before proceeding |
| Gate C - pure translation | Offline mapping for all six activation descriptors | Exact setup and payload representation, including `09 00` present and `90 00` absent | Any response, readiness, retry, or unproven byte is encoded | Revert translation and fixtures |
| Gate D - compile-only WDK formatting | WDK type compatibility without target or request creation | Compiles with installed WDK and creates only ignored static-library artifacts | WDF target/request creation, formatting, or submission appears | Remove WDK formatter changes |
| Gate E - lifecycle race tests | Mocked cancellation, D0 exit, stale completion, duplicate completion, and generation replacement tests | Deterministic tests prove acquire/release pairing and stale rejection | Any operation can outlive generation without rundown ownership | Rework mocks before runtime code |
| Gate F - installation recovery | Reversible device-specific lower-filter install/removal plan | Peer-reviewed recovery restores Microsoft-only `xusb22` state and avoids class-wide filters | Recovery depends on disabling security or broad class changes | No install authorization |
| Gate G - stack visibility | Evidence for default-control access and input visibility | Current Windows 11 stack proves both paths without guessing legacy ordinals | Default control or input path is inaccessible, ambiguous, or disruptive | Restore baseline and keep only sanitized evidence |
| Gate H - explicit authorization | Later task names exact hardware action, request set, limits, observation, and abort criteria | Authorization and preflight match all prior gate evidence | Missing authorization, stale evidence, or unhealthy baseline | Send nothing; if installed, execute recovery plan |

Passing a documentation or compile gate never authorizes live USB traffic.

## 25. Unresolved questions

- Can a device-specific lower filter beneath `xusb22` access default-control
  requests safely on Windows 11?
- Which current path can deliver Chatpad five-byte input without guessing
  legacy interface or pipe ordinals?
- What WDF callback and IRQL constraints will the final request-completion path
  impose?
- Should delay scheduling use a KMDF timer or a passive serialized owner after
  the completion model is implemented?
- What do control-IN response bytes mean, if anything?
- What recovery package identity and uninstall path will be used before any
  install test?
- Which keyboard output technology should be selected after transport evidence
  exists?

## 26. Smallest safe next coding task

The next coding task should create a pure, compile-tested Windows control-setup
translation module that maps the six neutral `ChatpadActivationRequest`
descriptors into a caller-owned inspectable setup representation. It should
include exact offline tests and kernel compile validation. It must not use
`WDFDEVICE`, `WDFIOTARGET`, `WDFREQUEST`, USB target creation, request
formatting/submission, hardware access, INF, installation, signing, packaging,
deployment, or loading.

Explicit conclusions:

1. The future per-device KMDF transport owner owns WDF requests.
2. Ownership is tied to one D0 generation through lifecycle generation plus a
   portable operation token stored in the request-owner record.
3. D0 exit closes admission before cancellation and before new delay scheduling.
4. A per-device `WDFSPINLOCK` is the recommended first synchronization model.
5. Stale completions compare stored generation/token to current state; duplicate
   completions are blocked by completion-once state.
6. Lifecycle outstanding counts are acquired before request creation and
   released exactly once in failure, cancellation, or completion cleanup.
7. The per-device scheduler owns the 12 ms metadata after prior request
   completion permits progression.
8. Blocking sleep is rejected because it blocks callbacks, weakens cancellation,
   and turns metadata into runtime behavior.
9. During removal, timers/scheduler work are stopped, requests are canceled, and
   old callbacks may only perform cleanup for their generation.
10. The portable token maps to a WDF request through a request-owner record and
   never aliases a pointer.
11. Activation remains bounded and separate from continuous input.
12. Default-control and input access remain unproven on Windows 11.
13. The exact next task is pure control-setup translation with offline tests and
   kernel compile validation only.
14. Future physical actions may be useful only after recovery, stack visibility,
   and explicit authorization gates pass.

## 27. Explicitly deferred work

- WDF target creation;
- WDF request creation, formatting, submission, completion callbacks, and
  cancellation callbacks;
- queues, timers, work items, continuous readers, or threads;
- USB/HID/IOCTL/URB/device-handle/endpoint/pipe access;
- endpoint discovery, input acquisition, response parsing, acknowledgement,
  readiness, retry, timeout, or key mapping;
- INF, CAT, package, service, installer, certificate, signing, deployment,
  loading, or Device Manager behavior;
- ETW, capture, descriptor queries, hardware enumeration, controller
  disconnect/reconnect, or Chatpad detach/reattach;
- VHF or other keyboard output implementation.

## 28. Pure control-setup translation checkpoint

`src/transport/ChatpadControlSetup/` now implements Gate C as an isolated
portable static library. `ChatpadTranslateActivationRequest` accepts a
caller-provided descriptor and writes a caller-owned value containing exactly
eight setup bytes, explicit data-stage direction, copied outbound bytes and
length, and expected inbound length.

The translator encodes `wValue`, `wIndex`, and `wLength` little-endian without
packing or structure overlays. It rejects null arguments, invalid direction,
direction-bit mismatch, host-to-device length mismatch, device-to-host
outbound data, inbound-length mismatch, and outbound capacity overflow. Every
failure with a non-null output clears the complete output deterministically.

All six confirmed descriptors are obtained through
`ChatpadBuildActivationRequest`; no request tuple is duplicated in production.
Native Debug and Release tests pass `141/141`. The kernel compatibility project
compiles the same header and source as C with the installed WDK and emits only
its existing `.lib`. `ChatpadFilter` has no reference, source, solution
dependency, or linker input for this module.

This checkpoint is not WDF request formatting or submission. It creates no
target, request, memory object, response buffer, queue, timer, work item,
thread, handle, or transfer. Control-IN bytes and default-control access remain
unresolved. Confirmed request 4 preserves `09 00`; confirmed fixtures contain
no `90 00` payload.
