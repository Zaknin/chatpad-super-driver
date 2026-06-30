# Windows 11 KMDF Request Object Creation and Cleanup Design

This is the authoritative design-only checkpoint for future dormant creation,
partial-initialization rollback, and cleanup of the Chatpad activation request
owner's KMDF objects. It creates no object and changes no source code.

## 1. Purpose and non-scope

This design covers the future dormant object-creation and cleanup rules for:

- one per-device bookkeeping `WDFSPINLOCK`;
- one reusable device-parented `WDFREQUEST`;
- one request-parented outbound `WDFMEMORY`;
- one request-parented inbound `WDFMEMORY`;
- the typed request context attached at request creation;
- fixed two-byte owner-backed outbound and inbound transfer storage.

It defines object parentage, creation order, partial initialization, failure
rollback, cleanup/destruction authority, initialization state, device-removal
behavior, and compatibility with future request reuse.

This design does not implement or authorize WDF object creation, target
discovery, request formatting, request submission, completion, cancellation,
activation sequencing, D0 rundown implementation, driver loading, signing,
staging, installation, USB access, hardware access, or any runtime behavior.

## 2. Current architecture

Current reality:

- `ChatpadFilter` is a KMDF lower-filter scaffold. Its current device context
  contains `Signature`, `Version`, `DiagnosticSequence`, and
  `ChatpadFilterLifecycleState Lifecycle`; it does not contain the activation
  request owner.
- `DriverEntry` registers only `ChatpadEvtDeviceAdd`.
- `ChatpadEvtDeviceAdd` calls `WdfFdoInitSetFilter`, registers existing PnP and
  power callbacks, creates the `WDFDEVICE`, initializes the current lifecycle
  state, and marks the device created.
- Existing PnP/power callbacks only advance the lifecycle scaffold:
  prepare-hardware, release-hardware, D0-entry, and D0-exit.
- No cleanup, destroy, completion, cancellation, queue, target, timer, work
  item, USB, or request callback exists for the activation request owner.

Existing compile-checked future design:

- `ChatpadActivationRequestOwner` in
  `src/transport/ChatpadRequestOwnerModel/` is the pure authoritative state
  model for ownership transitions and accounting.
- `ChatpadKmdfActivationRequestOwner` in
  `src/driver/ChatpadKmdfRequestOwnerContext/` is an isolated compile-only
  owner layout. It embeds the pure model and declares future `WDFREQUEST`,
  outbound `WDFMEMORY`, inbound `WDFMEMORY`, and `WDFSPINLOCK` handles.
- `ChatpadKmdfActivationRequestContext` is declared with
  `WDF_DECLARE_CONTEXT_TYPE_WITH_NAME` and will be attached to the reusable
  request at future request creation.
- Fixed outbound and inbound arrays are each exactly two bytes and live in the
  ordinary C owner storage.
- `ChatpadFilter` does not include, compile, link, retain, embed, or invoke the
  compile-only context module.

Future design in this document:

- The activation owner will later become a field in the device context only in
  a separately authorized implementation slice.
- The future dormant creation code will create framework objects but still will
  not acquire a USB target, format a request, register completion, send,
  cancel, advance activation, or touch hardware.

## 3. Final framework object graph

```text
WDFDEVICE
└── future CHATPAD_FILTER_DEVICE_CONTEXT
    └── ChatpadKmdfActivationRequestOwner        ordinary C storage
        ├── Model                                ordinary pure state model
        ├── TransferStorage.OutboundBytes[2]     ordinary C backing array
        ├── TransferStorage.InboundBytes[2]      ordinary C backing array
        ├── BookkeepingLock                      WDFSPINLOCK, parent WDFDEVICE
        └── Request                              WDFREQUEST, parent WDFDEVICE
            ├── ChatpadKmdfActivationRequestContext
            ├── OutboundMemory                  WDFMEMORY, parent Request
            │   └── describes OutboundBytes[2]
            └── InboundMemory                   WDFMEMORY, parent Request
                └── describes InboundBytes[2]
```

| Item | Object kind | Parent | Owner | Lifetime | Deletion authority | Backing-storage owner | Manual deletion expected | Callback required |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `WDFDEVICE` | Framework object | KMDF driver/device stack | KMDF | Device instance | KMDF PnP/device teardown | Not applicable | No during normal removal | No new callback in this design |
| Future device context | Framework context storage | `WDFDEVICE` | `ChatpadFilter` | Device instance | Deleted with `WDFDEVICE` | Contains ordinary owner storage | No | No new callback in this design |
| `ChatpadKmdfActivationRequestOwner` | Ordinary C structure | Future device context | `ChatpadFilter` | Device instance | Device-context lifetime | Owns fixed arrays and handles | No object deletion; fields are invalidated by code | No |
| `BookkeepingLock` | `WDFSPINLOCK` | `WDFDEVICE` | Owner structure holds handle | Device instance after creation | Explicit rollback on initialization failure; otherwise device deletion | Not applicable | Only on partial-initialization rollback | No |
| `Request` | `WDFREQUEST` | `WDFDEVICE` | Owner structure holds handle | Device instance after creation | Explicit rollback on initialization failure; otherwise device deletion | Request context owned by request | Only on partial-initialization rollback | No |
| Request context | Framework request context | `WDFREQUEST` | `ChatpadFilter` | Request lifetime | Deleted with request | Not applicable | No | No |
| `OutboundMemory` | `WDFMEMORY` | `WDFREQUEST` | Owner structure holds handle | Request lifetime after creation | Explicit rollback by deleting request parent or the memory if narrowly needed; otherwise request deletion | Describes owner `OutboundBytes[2]` | No independent normal deletion | No |
| `InboundMemory` | `WDFMEMORY` | `WDFREQUEST` | Owner structure holds handle | Request lifetime after creation | Explicit rollback by deleting request parent or the memory if narrowly needed; otherwise request deletion | Describes owner `InboundBytes[2]` | No independent normal deletion | No |
| `OutboundBytes[2]` | Ordinary C array | Owner structure | Owner structure | Device context lifetime | Not deleted by WDF memory | Owner structure | No | No |
| `InboundBytes[2]` | Ordinary C array | Owner structure | Owner structure | Device context lifetime | Not deleted by WDF memory | Owner structure | No | No |

Parentage is explicit: the lock and reusable request are device-parented; both
memory objects are request-parented; the memory objects describe but do not own
the fixed arrays.

## 4. Creation phase and callback selection

Selected future creation location: immediately after successful
`WdfDeviceCreate` in `ChatpadEvtDeviceAdd`, after the current device context is
retrieved and ordinary owner storage is initialized, but before any
request-owner ready state is published.

Rationale:

- It creates at most one owner object set per device instance.
- It requires no prepared hardware resources, USB target, default pipe, or
  controller query.
- Failure can be returned directly from `EvtDeviceAdd`, preventing a partially
  ready device from being exposed.
- Parentage is predictable because the `WDFDEVICE` exists and can parent the
  lock and request.
- The objects live across D0 cycles, avoiding repeated allocation and repeated
  teardown on power transitions.
- Future activation code can require owner-ready state before attempting
  target discovery or request formatting.

Rejected locations:

- Prepare-hardware: closer to hardware-resource transitions than needed and may
  repeat across resource rebalance, even though the objects do not depend on
  translated resources.
- First D0 entry: can repeat across D0 cycles and would mix device-lifetime
  allocation with power-transition admission.
- Lazy creation before first activation: complicates first-use error handling,
  can race operation admission, and delays framework object validation until
  the activation path.

This task does not implement the selected callback change.

## 5. Request creation without target use

The future reusable request will be created as a framework request object before
any USB target is acquired. KMDF 1.15 declares `WdfRequestCreate` with an
optional `WDFIOTARGET IoTarget` parameter, so the conceptual dormant creation
plan is to pass no target at creation time and use explicit device parentage in
the request attributes.

This separates three phases:

1. Request-object creation: allocate the reusable framework object and typed
   request context.
2. Later request formatting: bind one operation to a discovered target and
   transfer memory.
3. Later request submission: send an already formatted request.

The target becomes relevant only in a future target-discovery and
request-formatting design. Dormant creation does not imply USB access because
it does not discover a target, open a pipe, format an I/O request, register a
completion routine, or submit anything.

Before formatting is implemented, a separate design review must confirm target
identity, lower-filter visibility, request reuse rules, completion ownership,
D0-exit rundown, and cancellation behavior.

## 6. Exact creation order

Future creation order:

1. Zero the ordinary owner structure.
2. Set owner signature and version.
3. Clear the initialization mask to `CHATPAD_KMDF_REQUEST_OWNER_INIT_NONE`.
4. Initialize fixed transfer storage and completion snapshot to safe defaults.
5. Initialize the embedded pure model and mark the model-ready bit.
6. Prepare spinlock object attributes with `ParentObject = WDFDEVICE`.
7. Create the per-device bookkeeping spinlock and set the lock-created bit.
8. Prepare request object attributes with request context type and
   `ParentObject = WDFDEVICE`.
9. Create the reusable request with no target and set the request-created bit.
10. Retrieve and initialize the typed request context.
11. Prepare outbound memory attributes with `ParentObject = Request`.
12. Create outbound preallocated memory over `OutboundBytes[2]` and set the
    outbound-memory-created bit.
13. Prepare inbound memory attributes with `ParentObject = Request`.
14. Create inbound preallocated memory over `InboundBytes[2]` and set the
    inbound-memory-created bit.
15. Validate final invariants: handles present, context owner pointer matches,
    capacities are two bytes, no target acquired, no active operation, pure
    model in the selected initial state.
16. Publish owner ready by setting `CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY`.

Dependencies:

- The device must exist before any device-parented object is created.
- The pure model is initialized before framework handles are exposed.
- The request must exist before request-parented memory can be created.
- The request context is initialized before memory handles are published.
- Ready state is never published until every required handle and context is
  valid.

## 7. Attribute and parentage plan

| Future operation | Context type | `ParentObject` | Cleanup callback | Destroy callback | Execution level | Synchronization scope |
| --- | --- | --- | --- | --- | --- | --- |
| Spinlock creation | None | `WDFDEVICE` | None | None | Inherit from parent | None or inherit; not used as automatic synchronization |
| Request creation | `ChatpadKmdfActivationRequestContext` | `WDFDEVICE` | None | None | Inherit from parent | None or inherit; not used as automatic synchronization |
| Outbound memory creation | None | `WDFREQUEST` | None | None | Inherit from parent | None |
| Inbound memory creation | None | `WDFREQUEST` | None | None | Inherit from parent | None |

The designed `WDFSPINLOCK` protects only short bookkeeping transitions. WDF
automatic synchronization must not substitute for that lock. No cleanup or
destroy callback is selected because parentage and explicit operation-rundown
rules are the required authorities; callbacks would add no independent resource
to release in the dormant object set.

## 8. Preallocated memory and backing-buffer ownership

Outbound memory:

- Backing array: `TransferStorage.OutboundBytes[2]`.
- Array owner: ordinary per-device activation owner storage.
- Memory handle owner: activation owner handle field.
- Memory parent: reusable `WDFREQUEST`.
- Memory lifetime: request lifetime.
- Backing-array lifetime: device context lifetime, longer than memory lifetime.
- Deleting the memory object removes the framework descriptor only; it must not
  free the array.
- The array may be cleared during owner initialization, rollback, after a
  terminal operation has been fully retired, or before preparing a new
  operation; it must not be overwritten while a submitted operation can still
  reference it.

Inbound memory:

- Backing array: `TransferStorage.InboundBytes[2]`.
- Array owner: ordinary per-device activation owner storage.
- Memory handle owner: activation owner handle field.
- Memory parent: reusable `WDFREQUEST`.
- Memory lifetime: request lifetime.
- Backing-array lifetime: device context lifetime, longer than memory lifetime.
- Deleting the memory object removes the framework descriptor only; it must not
  free the array.
- The array may be cleared during owner initialization, rollback, after inbound
  completion data has been captured and operation retirement is complete, or
  before preparing a new inbound operation.

No dynamic allocation is needed because the authoritative activation sequence
requires exactly two-byte outbound and inbound capacities. The memory objects
must not outlive owner storage because they describe owner-owned arrays. This
design does not introduce larger speculative buffers and does not introduce
`90 00` as confirmed outbound data.

## 9. Initialization-state model

Use the existing initialization mask; do not introduce a second readiness
model.

| State or bit | Meaning |
| --- | --- |
| No bits set | Ordinary storage may be zeroed, but the owner is not initialized. |
| `MODEL_READY` | Signature/version and pure model have been initialized. |
| `LOCK_CREATED` | Device-parented spinlock handle is valid. |
| `REQUEST_CREATED` | Device-parented reusable request handle is valid. |
| Request context initialized | No existing bit; it must occur before any memory bit and before ready publication. |
| `OUTBOUND_MEMORY_CREATED` | Request-parented outbound memory handle is valid. |
| `INBOUND_MEMORY_CREATED` | Request-parented inbound memory handle is valid. |
| `OWNER_READY` | All required objects, context, and invariants are valid. |
| `FAULTED` | Initialization or invariant validation failed. |
| `DRAINING` | Cleanup or future teardown admission has begun. |
| Cleaned/unavailable | No ready bit, handles null, pure model unavailable or faulted according to failure timing. |

Allowed coexistence:

- `OWNER_READY` may coexist only with `MODEL_READY`, `LOCK_CREATED`,
  `REQUEST_CREATED`, `OUTBOUND_MEMORY_CREATED`, and `INBOUND_MEMORY_CREATED`.
- `FAULTED` must not coexist with `OWNER_READY`.
- `DRAINING` may coexist with created bits during cleanup, but no new operation
  admission may be allowed.

Externally authoritative readiness is the initialization mask plus pure-model
snapshot: ready requires `OWNER_READY`, all required created bits, non-null
handles, no `FAULTED`, and pure model in the selected initial state. Repeated
initialization is rejected if any created bit, `OWNER_READY`, `DRAINING`, or
non-null handle is observed. Zero-initialized memory is not ready.

Handles must be null before their create step succeeds and after explicit
rollback invalidates them.

## 10. Partial-initialization failure matrix

| Failure point | Objects already created | Parentage established | Explicit deletion | Device deletion ownership | Handles cleared | Flags after rollback | Pure model disposition | Status returned | Retry same instance | `EvtDeviceAdd` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Spinlock creation fails | None | None | None | Not needed | Lock remains null | `FAULTED`; no created bits | Unavailable or faulted before ready | Original failure status | No | Fail |
| Request creation fails | Spinlock | Lock parented to device | Delete spinlock | Device would also delete if not rolled back | Lock null, request null | `FAULTED`; created bits cleared | Unavailable or faulted | Original failure status | No | Fail |
| Request-context initialization fails | Spinlock, request | Lock/request parented to device | Delete request, then spinlock | Device would also delete if not rolled back | Request null, lock null | `FAULTED`; created bits cleared | Unavailable or faulted | Deterministic invalid-state status | No | Fail |
| Outbound memory creation fails | Spinlock, request | Lock/request parented to device | Delete request; request owns no outbound child; then spinlock | Device would also delete if not rolled back | Outbound null, request null, lock null | `FAULTED`; created bits cleared | Unavailable or faulted | Original failure status | No | Fail |
| Inbound memory creation fails | Spinlock, request, outbound memory | Outbound memory parented to request | Delete request, which deletes outbound child; then spinlock | Device would also delete if not rolled back | Inbound null, outbound null, request null, lock null | `FAULTED`; created bits cleared | Unavailable or faulted | Original failure status | No | Fail |
| Final invariant validation fails | Spinlock, request, outbound memory, inbound memory | Both memory children parented to request | Delete request, which deletes memory children; then spinlock | Device would also delete if not rolled back | All framework handles null | `FAULTED`; no ready bit | Faulted | Deterministic invalid-state status | No | Fail |

No failure path may set or retain `OWNER_READY`.

## 11. Rollback strategy decision

Selected strategy: narrowly defined hybrid.

- During initialization failure before returning from `EvtDeviceAdd`, explicitly
  delete created child objects in reverse ownership order: request first, then
  spinlock. Deleting the request deletes request-parented memory children.
- After successful ready publication, normal cleanup relies on device-parented
  hierarchy deletion, but only after future operation-rundown logic has made
  active callbacks impossible.

Why this is safe:

- Explicit rollback prevents a failed `EvtDeviceAdd` path from leaving ordinary
  owner handles appearing live after the callback returns failure.
- Deleting the request parent avoids relying on sibling order for the two
  memory objects.
- The fixed arrays are ordinary device-context storage and are not freed by
  memory-object deletion.
- Handle fields are cleared exactly once after deletion is requested to avoid
  double deletion.
- Cleanup callbacks are not used to duplicate pure-model retirement.

Asynchronous framework deletion after `WdfObjectDelete` means the design must
not immediately reuse backing storage for a new request on the same failed
owner. Same-instance retry is rejected; `EvtDeviceAdd` fails. Sibling deletion
order is not relied on.

## 12. Normal cleanup and device removal

Device creation failure:

- If failure occurs before `WdfDeviceCreate`, no activation owner exists.
- If failure occurs after `WdfDeviceCreate` during future dormant owner
  creation, explicit rollback deletes request then spinlock and returns failure
  from `EvtDeviceAdd`.

Device removal before D0:

- With successful dormant creation and no active operation, device deletion
  owns framework child cleanup. The pure model should be unavailable/draining,
  but no operation retirement exists.

Normal removal after future D0 use:

- Future D0-exit and removal logic must first close admission and complete
  exact operation rundown. Only then may device deletion be treated as safe
  framework object cleanup.

Surprise removal:

- Surprise removal does not make framework cleanup a substitute for operation
  terminal retirement. Future cancellation/rundown must handle any submitted
  request before request destruction is considered safe.

Driver unload through device deletion:

- Device deletion owns device-parented request and lock and request-parented
  memory children, subject to the same active-operation stop condition.

Cleanup while no operation is active:

- Mark not ready or draining, ensure no lifecycle admission exists, clear
  volatile snapshots, and let parent deletion dispose of framework objects.

Cleanup while a future operation is active:

- Stop condition. The separate rundown/cancellation design must run first.
  Framework cleanup must not silently substitute for exact operation retirement
  or lifecycle-admission release.

## 13. Cleanup and destroy callback decision

| Object | Cleanup callback | Destroy callback | Decision |
| --- | --- | --- | --- |
| `WDFDEVICE` | No new callback in this checkpoint | No new callback in this checkpoint | Existing lifecycle callbacks remain the only current callbacks. Future explicit cleanup helper may be called from an authorized lifecycle point, not hidden in object destroy. |
| `WDFSPINLOCK` | None | None | Parentage is sufficient; no resource beyond the framework object exists. |
| `WDFREQUEST` | None | None | Request children and context are framework-owned; operation retirement must occur before deletion, not inside cleanup. |
| Outbound `WDFMEMORY` | None | None | Memory does not own the backing array. |
| Inbound `WDFMEMORY` | None | None | Memory does not own the backing array. |

Callbacks must not release lifecycle admission a second time, mark an active
operation complete, advance activation, wait for I/O, sleep, perform hardware
access, assume sibling deletion order, or free the fixed arrays.

## 14. Lock creation and destruction

The lock is device-parented and created before the request-owner ready state is
externally observable. It exists before any future request state can be
published, so future bookkeeping can safely serialize state transitions as soon
as operation admission is implemented.

The lock is destroyed by explicit rollback during initialization failure or by
device deletion after successful creation. Cleanup does not need to acquire the
lock merely to delete child framework objects. Future rundown must close
admission and prevent callbacks from using the lock after teardown begins; the
lock protects bookkeeping transitions only and must not be held across
formatting, send, cancel, wait, hardware access, or cleanup deletion.

## 15. Request-context initialization

Immediately after future request creation, the request context must receive:

- pointer to the containing `ChatpadKmdfActivationRequestOwner`;
- invalid operation identity;
- invalid lifecycle generation;
- invalid activation step;
- transfer direction `NONE`;
- transfer length `0`;
- expected inbound length `0`;
- null active transfer memory;
- zeroed setup packet;
- completion snapshot with no completion class and zero lengths/status values.

During one submitted operation, these fields are immutable: owner pointer,
operation token, lifecycle generation, activation step, setup packet, selected
transfer direction, selected memory handle, transfer length, and expected
inbound length. Completion fields are written only by the future completion
path under the model's terminal-ownership rules.

The owner pointer remains valid while the request exists because both owner
ordinary storage and the request are device-lifetime objects under the same
`WDFDEVICE`. The request context must not duplicate the complete pure-model
state.

## 16. Pure-model initialization and reset

Ordering:

1. Ordinary owner storage is zeroed.
2. The embedded pure model is initialized before any owner-ready publication.
3. Framework objects are created.
4. Final invariants are validated.
5. Owner ready is published.

The pure model starts unavailable until the future owner creation sequence
explicitly transitions or marks it as idle/available according to the pure
model API. Object-creation failure before readiness marks the model
unavailable or faulted and returns failure from `EvtDeviceAdd`.

Cleanup does not call a pure-model completion transition unless a real
operation exists. Future D0 generations reuse already-created device-lifetime
objects; operation-lifetime reset is distinct from device-lifetime object
creation. This task does not change the pure model.

## 17. IRQL and execution constraints

Installed KMDF 1.15 header evidence:

- `WdfDeviceCreate` is annotated `_IRQL_requires_max_(PASSIVE_LEVEL)`.
- `WdfRequestCreate`, `WdfMemoryCreatePreallocated`, `WdfSpinLockCreate`,
  `WdfObjectDelete`, and `WdfRequestReuse` are annotated
  `_IRQL_requires_max_(DISPATCH_LEVEL)`.
- `EVT_WDF_OBJECT_CONTEXT_CLEANUP` and `EVT_WDF_OBJECT_CONTEXT_DESTROY` are
  annotated `_IRQL_requires_max_(DISPATCH_LEVEL)`.
- `WDF_OBJECT_ATTRIBUTES` contains `EvtCleanupCallback`,
  `EvtDestroyCallback`, `ExecutionLevel`, `SynchronizationScope`, and optional
  `ParentObject`; `WDF_OBJECT_ATTRIBUTES_INIT` defaults execution level and
  synchronization scope to inherit from parent.

Expected future constraints:

- Selected creation location: `EvtDeviceAdd` immediately after
  `WdfDeviceCreate`, expected at PASSIVE_LEVEL because device creation itself
  requires PASSIVE_LEVEL.
- No cleanup/destroy callback is selected; if later introduced, it must obey
  the header's DISPATCH_LEVEL maximum and must not wait or access hardware.
- Future completion may run at framework-defined completion IRQL and must use
  only operations valid at that IRQL.
- Future D0 rundown must define its own IRQL and waiting constraints before any
  cancellation or wait logic is implemented.

Unresolved IRQL issue requiring stop before implementation: the future
completion/rundown design must prove that all model transitions, lifecycle
release, cancellation, and request reuse calls are valid at their actual
callback IRQLs.

## 18. Dormancy guarantee

The future object-creation implementation may create framework objects only. It
must not acquire a USB target, format a request, set a completion routine,
reuse or send a request, cancel a request, access transfer memory through a
live target, alter activation state, interact with hardware, or query PnP/USB.

Required semantic guards:

- Allow only the selected creation calls in the dormant creation slice.
- Forbid target creation/discovery, USB control formatting, request send,
  cancellation, completion routine registration, request reuse, and
  `IoCallDriver`.
- Verify `ChatpadFilter` still does not link target-discovery or activation
  submission paths.
- Verify no INF, CAT, signing, staging, install, service, registry, Driver
  Store, or device-query paths are introduced.
- Verify owner-ready is published only after all dormant objects exist.

## 19. Invariants after successful creation

After future dormant creation succeeds:

- exactly one owner exists per device;
- exactly one lock exists per owner;
- exactly one reusable request exists per owner;
- exactly two memory objects exist;
- both memory objects are parented to the request;
- request and lock are parented to the device;
- request context points to the same owner;
- backing arrays have exact two-byte capacities;
- every required handle is valid;
- `OWNER_READY` is set only after all objects exist;
- no `FAULTED` bit is set;
- no target is acquired;
- no request is formatted;
- no request is submitted;
- no completion routine is registered;
- no active lifecycle admission exists;
- no active operation exists;
- pure model is in the selected initial unavailable/idle state;
- continuous input remains separate.

## 20. Failure and cleanup scenario matrix

| Scenario | Initial state | Framework objects present | Required action | Deletion authority | Pure-model disposition | Lifecycle obligation disposition | Expected final state | Stop condition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1. All object creation succeeds | Zeroed owner after device creation | Lock, request, outbound memory, inbound memory | Validate and set ready | Device owns normal cleanup | Initial unavailable/idle | None | Ready, no active operation | Any missing handle |
| 2. Lock creation fails | Model initialized | None | Mark fault/unavailable, return status | None | Faulted/unavailable | None | Device add fails | Retry on same owner |
| 3. Request creation fails | Lock created | Lock | Delete lock, clear handle | Explicit rollback | Faulted/unavailable | None | Device add fails | Ready bit set |
| 4. Request-context setup fails | Lock and request created | Lock, request | Delete request, delete lock | Explicit rollback | Faulted/unavailable | None | Device add fails | Context owner mismatch ignored |
| 5. Outbound memory creation fails | Request context initialized | Lock, request | Delete request, delete lock | Explicit rollback | Faulted/unavailable | None | Device add fails | Outbound handle retained |
| 6. Inbound memory creation fails | Outbound memory created | Lock, request, outbound memory | Delete request, delete lock | Explicit rollback; request deletes outbound child | Faulted/unavailable | None | Device add fails | Sibling deletion order assumed |
| 7. Final invariant validation fails | All objects created | Lock, request, both memory objects | Delete request, delete lock | Explicit rollback | Faulted | None | Device add fails | Owner ready published |
| 8. Device removal before D0 | Ready, no operation | All dormant objects | Let device deletion clean hierarchy | Device parentage | Unavailable/draining | None | Device removed | Hardware action attempted |
| 9. Normal removal with no active operation | Ready, no operation | All dormant objects | Close readiness, allow device deletion | Device parentage | Unavailable/draining | None | Removed cleanly | Operation active |
| 10. Future removal with operation in preparation | Operation admitted, not submitted | All dormant objects | Abort through pure model and release lifecycle | Future rundown, not object cleanup | Terminal local retirement | Exact release required | No active operation, then remove | Cleanup substitutes for release |
| 11. Future removal with submitted request | Submitted request | All dormant objects plus target state | Run future cancel/rundown design first | Future cancellation/completion | Completion/cancel rules apply | Exact release required | Remove only after terminal retirement | Request destroyed while submitted |
| 12. Cleanup after completion before pins return | Terminal observed, send/cancel pin active | All dormant objects | Wait-free model state remains not reusable until pins return | Future rundown | Terminal pending pin release | Release already owned or pending per model | No reuse until pins return | Reuse before pin release |
| 13. Cleanup callback after partial initialization | Failure path | Some children | No selected callback; explicit rollback handles | Explicit rollback | Faulted/unavailable | None | Handles cleared | Callback required for correctness |
| 14. Explicit deletion races parent deletion | Teardown started | Some children | Avoid double deletion by clearing ownership and serializing teardown | Single owner path | Draining/faulted | None or already released | No stale handle use | Same handle deleted twice |
| 15. Repeated initialization attempted | Any created bit or handle set | Maybe all objects | Reject attempt | Existing owner | Unchanged | Unchanged | No second object set | Reinitialize ready owner |
| 16. Stale handle remains after deletion | Rollback path | Deleted or deleting object | Clear handle and keep not-ready/faulted | Explicit rollback | Faulted | None | No handle considered valid | Handle reused |
| 17. Memory child deletion unexpected order | Request deletion | Both memory children | Do not depend on order | Request parent | Unchanged | None | Both descriptors gone | Sibling order assumed |
| 18. Backing arrays after memory deletion | Request deleted | Memory descriptors gone | Treat arrays as ordinary owner storage; clear if needed | Owner storage | Faulted/unavailable or draining | None | Arrays remain until device context gone | Array freed by memory deletion |

## 21. Implementation decomposition

Smallest future slices, each requiring explicit authorization:

1. Pure helper for owner-structure initialization and validation, with no WDF
   call.
2. Compile-only attribute builders.
3. Dormant spinlock and request creation.
4. Dormant preallocated outbound and inbound memory creation.
5. Partial-failure rollback and device cleanup.
6. Offline semantic and compile validation.
7. Independent review of the dormant object checkpoint.
8. Future target-discovery design.
9. Future request-formatting design.
10. Separately authorized submission and completion work.

This document authorizes none of those implementation slices.

## 22. Binding decisions, rejected alternatives, and stop conditions

Binding decisions:

1. Future dormant creation belongs immediately after successful
   `WdfDeviceCreate` in `EvtDeviceAdd`.
2. The reusable request is device-parented.
3. The request is created without an initial I/O target.
4. Outbound and inbound preallocated memory objects are request-parented.
5. Fixed backing arrays remain ordinary owner storage and are exactly two bytes
   each.
6. The spinlock is device-parented and protects only short bookkeeping
   transitions.
7. No cleanup or destroy callback is selected for the dormant object set.
8. Rollback uses explicit reverse-order deletion during initialization failure
   and parent hierarchy deletion during normal device teardown after future
   rundown.
9. The pure request-owner model remains the transition/accounting authority.
10. Activation ownership remains separate from future continuous input.

Rejected creation locations:

- Prepare-hardware, first D0 entry, and lazy first activation creation, for the
  reasons in section 4.

Rejected rollback strategies:

- Pure reliance on device deletion during initialization failure, because
  ordinary handle fields could remain misleading before returning failure.
- Explicit deletion of every memory child independently during normal removal,
  because request parentage already owns the memory children and sibling order
  must not matter.

Rejected parentage alternatives:

- Request-parenting the spinlock: weakens per-device bookkeeping lifetime.
- Device-parenting the memory objects: can outlive request reuse and weakens
  transfer lifetime boundaries.
- Target-parenting the request: would require target discovery and USB access
  before dormant creation.

Rejected callback designs:

- Memory cleanup callback to free fixed arrays: invalid because memory does not
  own the arrays.
- Request cleanup callback to retire active operations: operation retirement
  belongs to the pure model and future completion/cancellation/rundown paths.
- Lock cleanup callback for bookkeeping: no independent resource exists.

Unresolved questions:

- Exact future target-discovery and target lifetime rules.
- Exact request formatting and completion callback design.
- Exact D0-exit rundown, cancellation, and waiting rules.
- Exact IRQL proof for future completion/rundown transitions.

Stop conditions requiring another design review:

- KMDF evidence proves targetless `WdfRequestCreate` is not valid for the
  selected request use.
- A future target lifetime cannot safely coexist with a device-parented
  request.
- Future completion/rundown cannot prove IRQL correctness.
- Any implementation would require stack-backed asynchronous storage.
- Any implementation would require broadening buffers beyond two bytes.
- Any implementation would merge activation request ownership with continuous
  input.
- Any implementation would need hardware access, signing, staging,
  installation, or request submission before the corresponding design gate.
