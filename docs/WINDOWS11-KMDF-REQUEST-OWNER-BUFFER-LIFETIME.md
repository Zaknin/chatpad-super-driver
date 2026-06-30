# Windows 11 KMDF Request Owner and Buffer Lifetime

This document is the authoritative ownership and lifetime design for the first
future asynchronous Chatpad activation control request. It refines the broader
[KMDF transport bridge design](WINDOWS11-KMDF-TRANSPORT-BRIDGE-DESIGN.md)
without implementing that bridge.

## 1. Scope and explicit non-scope

This design covers one future per-device activation control-request owner,
stable outbound and inbound transfer-buffer lifetime, request bookkeeping,
lifecycle-generation association, completion/cancellation/send-return races,
cleanup/rundown, and terminal sequencing between the six steps prepared by
`ChatpadPrepareActivationStep`.

This design does not implement or authorize WDF object creation, target
creation, request formatting, request submission, cancellation calls,
completion callbacks, executable timing, device loading, USB discovery,
controller or Chatpad access, Chatpad input, continuous input acquisition,
keyboard output, signing, staging, installation, or any operating-system or
hardware action. Every WDF object and callback below is future design only.

## 2. Ownership hierarchy

The future hierarchy is per device instance. No handle, buffer, context, token,
or mutable state is shared globally or across device instances.

| Item | Intended owner and parent | Lifetime and rule |
| --- | --- | --- |
| Request owner | `WDFDEVICE` context | Device lifetime; contains one activation slot, not the continuous-input owner. |
| Request slot/operation record | Request owner | Device lifetime storage whose active values are operation-lifetime only. |
| `WDFREQUEST` | Explicit child of `WDFDEVICE` | Created once for the device and reused only after terminal completion. |
| Request context | Context on the reusable `WDFREQUEST` | Request-object lifetime; holds the stable setup value, memory handles, operation identity, and bounded completion snapshot. |
| Outbound transfer storage | Two-byte nonpaged `WDFMEMORY`, parented to the request | Request-object lifetime; used only for a host-to-device operation and never shared with inbound storage. |
| Inbound transfer storage | Two-byte nonpaged `WDFMEMORY`, parented to the request | Request-object lifetime; used only for a device-to-host operation and invalidated before every operation. |
| Setup packet | Request context | Stable through formatting and terminal completion. A stack-local preparation value is copied here before formatting. |
| Completion metadata | Request context plus bounded local snapshot in the callback | Operation lifetime; status, USB status, actual length, disposition, and at most two inbound bytes. |
| Cancellation state | Request slot | Operation lifetime; protected by the per-device bookkeeping lock. |
| Lifecycle generation | Request slot and request context | Captured nonzero generation for the operation; never inferred from a request pointer. |
| Activation identity | Portable token and step index in the slot/context | Operation lifetime; both values must match before a completion can advance sequencing. |
| Outstanding reference | Boolean exact-once marker in the slot | One successful lifecycle acquire maps to one release attempt for the captured generation. |
| Delay-after-step metadata | Sequencing owner, copied as a scalar in the slot until terminal disposition | Operation metadata only; it is not represented by an in-flight request. |

`ChatpadActivationPreparation` and validation temporaries may be stack-local
only before the owner copies their setup, lengths, payload, and scalar metadata
into request-owned storage. `WDF_REQUEST_REUSE_PARAMS` and local status
snapshots may also be stack-local because KMDF consumes them synchronously.
No setup packet, transfer bytes, `WDFMEMORY_OFFSET`, completion context, or
other data referenced by the asynchronous operation may depend on temporary
stack storage.

## 3. Selected request allocation strategy

The first implementation shall use exactly one reusable, preallocated
`WDFREQUEST` per device. It is a device child, has one typed request context,
and is reserved exclusively for bounded activation control operations. The
slot is either unavailable, idle, or owned by one operation; a second
activation operation cannot allocate around a busy slot.

This strategy provides one-operation-in-flight enforcement, deterministic
parentage, bounded resource use, generation-aware completion, and a single
place to pin send/cancel calls against reuse. It supports the six-step sequence
without six requests and remains separate from any future continuous-input
request owner.

Rejected alternatives:

- A request allocated per activation step adds failure and cleanup paths and
  allows accidental unbounded allocation without improving the required
  one-in-flight model.
- A device-wide pool permits concurrency the activation protocol does not
  need and makes terminal ownership less direct.
- A shared global request violates per-device isolation and removal safety.
- Reusing an upper-stack request would mix unrelated `xusb22` traffic with
  driver-owned activation work and is prohibited.

The future request may be created dormant with `WDF_NO_HANDLE` as its initial
I/O target and an explicit `WDFDEVICE` parent. Selecting or creating the USB
target remains a separate unresolved and unauthorized gate.

## 4. Selected transfer-buffer strategy

The selected model uses two distinct request-parented `WDFMEMORY` objects:

- an outbound object of exactly `CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH` bytes
  (currently two);
- an inbound object of exactly two bytes, the maximum expected inbound length
  among all six authoritative operations.

Both selected capacities are therefore two bytes. The future compile/model
guard must prove that every authoritative expected inbound length remains at
or below the selected inbound capacity; it must not repurpose the outbound-only
constant as an undocumented inbound contract. No per-operation allocation or
arbitrary large buffer is required. For a zero-length operation the formatter
receives no transfer-memory handle. For a data operation it receives only the
direction-matching object and an exact zero-offset, active-length view stored
in the request context.

The objects and their backing buffers exist from owner initialization until
the request is deleted. Their parent request cannot be reused or deleted while
an operation, send call, cancel call, or completion still owns the slot. This
makes the data valid from formatting through terminal completion.

Fixed raw arrays in device or request context were rejected because KMDF 1.15
`WdfUsbTargetDeviceFormatRequestForControlTransfer` accepts `WDFMEMORY`, not a
raw-buffer `WDF_MEMORY_DESCRIPTOR`. Wrapping such arrays with preallocated
memory would introduce two lifetime authorities. Device-parented memory was
rejected because it could be reused independently of the request. One shared
bidirectional memory object was rejected because separate objects make
direction checks and stale-data invalidation explicit.

The inspected `WDF_MEMORY_DESCRIPTOR` buffer/handle forms are not selected for
the asynchronous path. They are accepted by the synchronous control-transfer
API, while this design requires asynchronous formatting and completion. No
`90 00` outbound value is defined: the only confirmed nonempty outbound bytes
remain `09 00`.

## 5. Request-owner state machine

The state names are binding. `DrainingRequested`, `SendCallActive`,
`CancelCallActive`, `CancellationRequested`, and `TerminalProcessed` are
protected flags that refine the primary state.

| State | Meaning |
| --- | --- |
| `UNAVAILABLE` | Request/memory initialization is incomplete, failed, or permanently faulted until reconstruction. |
| `IDLE` | Objects exist; no operation, generation, token, lifecycle reference, or active framework call owns the slot. |
| `PREPARING` | Slot and lifecycle reference are reserved; pure preparation/copy/validation is outside the lock. |
| `READY` | Prior request state is reusable and request-owned setup/buffers are valid; formatting may begin. |
| `FORMATTED` | Control request is formatted and its completion identity is published; it has not been sent. |
| `SUBMITTING` | Send intent is published and `SendCallActive` pins the slot while `WdfRequestSend` runs outside the lock. |
| `IN_FLIGHT` | Send returned true; completion owns normal terminal retirement. |
| `CANCEL_CALLING` | Cancellation is requested and `CancelCallActive` pins the slot across the outside-lock KMDF cancellation call. |
| `CANCEL_PENDING` | Cancellation was requested; completion is still required. |
| `COMPLETING` | The completion callback is classifying and retiring the operation. |
| `AWAITING_CALL_RETURN` | Completion retired the operation while send or cancel remained on its caller's stack; reuse is still forbidden. |
| `RETIRING` | A no-completion failure path owns exact-once accounting and buffer invalidation. |
| `DRAINING` | No operation owns the slot and the current generation is ending; new admission is closed. |
| `FAULTED` | An ownership/framework invariant or request-reuse failure requires deletion and later reconstruction. |

Transition table:

| From -> to | Initiator | Lock and generation rule | Framework work outside lock | Accounting, failure, and terminal owner |
| --- | --- | --- | --- | --- |
| `UNAVAILABLE` -> `IDLE` | Future PrepareHardware owner | Publish only after all request/context/memory objects exist; no D0 generation | Object creation occurs before publication | No operation count; partial creation deletes the request tree and remains `UNAVAILABLE`. |
| `IDLE` -> `PREPARING` | Sequence initiator | Under lock, require D0-active matching generation and open admission; acquire one lifecycle operation and record token/step | None while locked | Slot owns the exact-one release obligation; admission failure leaves `IDLE`. |
| `PREPARING` -> `READY` | Initiator | Re-lock and revalidate captured identity; slot remains exclusive | Pure preparation, bounded copies, and request reuse occur outside lock | Any failure goes through `RETIRING`; reuse failure ends in `FAULTED`, other pre-send failures return to `IDLE` or `DRAINING`. |
| `READY` -> `FORMATTED` | Initiator | Publish only if identity still matches and cancellation/rundown has not won | Format request and set completion routine outside lock | Format failure: no completion, initiator retires, sequence aborts. |
| `FORMATTED` -> `SUBMITTING` | Initiator | Under lock set `SendCallActive`, operation serial, and send-published state before the call | `WdfRequestSend` only | State publication prevents an early completion from seeing a late in-flight record. |
| `SUBMITTING` -> `IN_FLIGHT` | Send return path | Under lock, same serial, send returned true, no completion/cancel pending | None | Completion is terminal owner. |
| `SUBMITTING` -> `CANCEL_CALLING` | Send return path after a prior cancel request | Under lock clear send pin and install cancel pin | `WdfRequestCancelSentRequest` outside lock | Completion remains terminal owner regardless of cancel-call Boolean result. |
| `SUBMITTING` -> `RETIRING` -> `IDLE`/`DRAINING` | Send return path | Send returned false; framework contract says completion is not expected | Read request status outside lock | Initiator releases accounting once, invalidates buffers, and aborts sequence. |
| `SUBMITTING`/`IN_FLIGHT`/`CANCEL_PENDING`/`CANCEL_CALLING` -> `COMPLETING` | Completion callback | Under lock require matching request/serial and unprocessed terminal marker; classify generation | No blocking call | Completion snapshots bounded data and retires accounting exactly once. |
| `COMPLETING` -> `AWAITING_CALL_RETURN` | Completion callback | A send/cancel pin is still active | None | Terminal facts are stored, but slot cannot become idle or be reused. |
| `COMPLETING` -> `IDLE`/`DRAINING` | Completion callback | No framework-call pin remains | Later logging/scheduling outside lock | Completion releases slot; only a current successful disposition may make delay scheduling eligible. |
| `AWAITING_CALL_RETURN` -> `IDLE`/`DRAINING` | Send/cancel return path | Under lock verify serial, clear final pin, consume stored disposition | Any eligible scheduling occurs after unlock | Accounting was already retired; caller must not retire it again. |
| `IN_FLIGHT` -> `CANCEL_CALLING` | D0/removal/abort/sequence cancel | Under lock set cancellation and cancel pin once | Cancellation call outside lock | A false return is not retirement; wait for completion unless the framework contract explicitly proves no completion. |
| `CANCEL_CALLING` -> `CANCEL_PENDING` | Cancel return path | Under lock same serial and no completion observed | None | Completion remains terminal owner. |
| `IDLE` -> `DRAINING` | D0/removal path | Under lock after lifecycle admission closes | None | No operation count; later cleanup may proceed only after all framework-call pins are clear. |
| Any active state -> `FAULTED` | Invariant guard | Under lock, fail closed and prevent reuse/new sequence work | Cancel only if a valid sent request still exists | Never decrement a different generation; require rundown/reconstruction review. |

No WDF request, memory, target, send, cancel, wait, delay, or lengthy logging
call is permitted while the bookkeeping spinlock is held.

## 6. Synchronous-completion and send-return race

The send protocol uses two-phase publication:

1. Before `WdfRequestSend`, the initiator holds the lock and publishes
   `SUBMITTING`, the operation serial, completion identity, and
   `SendCallActive = true`.
2. It releases the lock and calls `WdfRequestSend`.
3. A completion that arrives before the call returns may retire accounting and
   store the terminal disposition, but it must leave the slot in
   `AWAITING_CALL_RETURN` because the send caller still owns a pin.
4. If send returns true and no completion was seen, the caller clears its pin
   and publishes `IN_FLIGHT` or begins a previously requested cancellation.
   If completion was seen, it clears only its pin and performs the stored
   outside-lock scheduling action, if eligible. It does not retire accounting.
5. If send returns false, completion is not expected. The initiator obtains
   request status, transitions through `RETIRING`, releases the lifecycle
   reference once, invalidates both logical data stages, and aborts sequencing.

The initiating path may inspect only the operation serial, call pins, primary
state, terminal marker, and copied disposition while holding the lock after
send returns. It may not assume the request is still in flight or dereference
operation-owned data after another path made the slot reusable. The slot never
returns to `IDLE` while a send or cancellation call remains active.

## 7. Formatting and immediate-send failure

| Failure | Request/buffer owner and completion | Accounting | Sequence result |
| --- | --- | --- | --- |
| Activation preparation fails | Request remains with device; buffers are cleared; no completion | Initiator retires the reserved lifecycle reference, if already acquired | Abort; no next step. |
| Request reuse fails | Device still owns objects, but request becomes `FAULTED`; no completion | Initiator releases once | Abort; reconstruct only after ReleaseHardware/later PrepareHardware. |
| Transfer-memory preparation fails | Request remains unsent; both memory objects remain request-owned and invalid | Initiator releases once | Abort; no next step. |
| Control formatting fails | Request remains device-owned and requires reuse before any later format; no completion | Initiator releases once | Abort. |
| `WdfRequestSend` returns false | Request and buffers remain device-owned; completion is not expected | Send path releases once after obtaining status | Abort. |
| Completion reports failure | Completion owns terminal processing; buffers remain request-owned | Completion releases once | Abort; failure cannot advance or expose inbound success data. |

`WdfRequestSetCompletionRoutine` has no status return. It is installed only
after successful formatting and before the send publication. No failure path
assumes a callback where KMDF does not guarantee one. Cancellation is
inapplicable until a send has returned true; a request merely formatted or
rejected by send is retired by the initiating path.

## 8. Completion ownership

The future completion callback shall:

1. Use the typed request context and operation serial to identify the slot,
   captured generation, portable token, and step.
2. Under the per-device lock, reject an unexpected request/serial and prevent
   duplicate terminal processing with `TerminalProcessed`.
3. Snapshot `IoStatus.Status`, the USB completion status when present, and the
   control-transfer length. Clamp/cross-check length against the active
   expected length and two-byte capacity before copying any inbound bytes.
4. Classify current, cancelled, stale, failed, or invariant-fault disposition.
5. Complete the portable token only when its identity is valid. Never mutate a
   new generation for a stale callback.
6. Release the captured lifecycle operation exactly once using the slot's
   owned-reference marker. A stale-generation response from the lifecycle core
   is a fatal invariant, not permission to decrement the current generation.
7. Invalidate response success on every non-current or failed disposition.
8. Release the slot immediately only when no send/cancel call pin remains;
   otherwise publish `AWAITING_CALL_RETURN`.
9. After unlocking, perform bounded logging and schedule, but do not execute,
   a separately designed next-step delay only for current successful terminal
   completion.

Completion must not block, wait, sleep, recursively issue the next transfer,
perform lengthy logging under the lock, or expose the inbound `WDFMEMORY`
buffer after the slot is released. Only the copied bounded completion snapshot
may leave the request context.

## 9. Cancellation model

D0 exit, orderly removal, surprise removal, activation abort, generation
shutdown, and explicit future sequence cancellation all use the same
idempotent owner operation.

Under the lock, cancellation first sets `CancellationRequested`. If send is
still on its caller's stack, no cancellation call occurs; the send-return path
will either retire a failed send or install the cancel pin after a successful
send. For `IN_FLIGHT`, the canceller sets `CancelCallActive`, records the
operation serial, and publishes `CANCEL_CALLING`; it then unlocks and calls
`WdfRequestCancelSentRequest`. On return it re-locks, verifies the serial,
clears the pin, and moves to `CANCEL_PENDING`, or releases an
`AWAITING_CALL_RETURN` slot whose completion already ran.

The cancellation API's Boolean result is diagnostic only for ownership. A
false result can mean completion won the race; it does not authorize manual
terminal retirement. Requesting cancellation is never terminal retirement,
normal completion can race cancellation, and completion remains responsible
after a successful send. Duplicate cancellation requests only observe/set the
same flag and must not issue overlapping cancellation calls. The lock is never
held across the KMDF call.

A cancelled or stale completion still consumes the record's one terminal
marker and one lifecycle-release obligation. It cannot advance activation.
The slot is not idle until completion has run and all send/cancel call pins
have returned.

## 10. Generation and lifecycle integration

The operation captures the lifecycle core's current nonzero generation while
the per-device lock is held. `ChatpadFilterLifecycleTryAcquireOperation` must
succeed for that same generation before the slot leaves `IDLE`. The slot then
owns one `LifecycleReferenceHeld` marker until a pre-send failure path or the
completion path consumes it.

D0 rundown calls `ChatpadFilterLifecycleBeginD0Rundown` under the same lock,
closing admission before setting `DrainingRequested`, stopping future delay
eligibility, and requesting cancellation outside the lock. No later operation
can enter `PREPARING`. A submitted operation remains in the lifecycle
outstanding count until terminal retirement.

A future D0-exit coordinator may complete exit only after all of these are
true: lifecycle outstanding count is zero, owner state is `DRAINING`, and no
send/cancel call pin is active. It must use a framework-approved nonblocking or
deferred PnP/power mechanism; it must not wait under the spinlock. The current
lifecycle implementation and callback behavior are unchanged by this design.

The recorded generation and portable token are compared with both current
lifecycle and sequence state on completion. A mismatch is stale: cleanup may
finish for the old record, but no current-generation count, step, delay, or
success state may change. Correct rundown prevents a later generation from
starting while the old operation owns an outstanding reference; therefore an
observed lifecycle stale-release result is a fail-closed invariant violation.

The request becomes reusable for a later generation only after terminal
processing, return of all framework-call pins, invalidation of old buffers and
metadata, and publication of `IDLE`. `DRAINING` must first be returned to
`IDLE` by a later valid D0-entry initialization; active old values are never
carried forward.

## 11. Locking policy

One future per-device `WDFSPINLOCK` protects:

- lifecycle core and transport-adapter mutations;
- request-owner primary state and operation serial;
- generation, token, step, and operation type;
- lifecycle-reference, terminal, submitted, and reuse markers;
- send/cancel call pins and cancellation/draining flags;
- active direction and lengths;
- bounded completion disposition/status/length metadata;
- delay eligibility and diagnostic counters that participate in decisions.

The lock is held only for short transitions, scalar/bounded copies, identity
checks, and calls to the portable state cores. Pure activation preparation may
run outside it after the slot/lifecycle reference protects the operation.
Request reuse, memory access/preparation, control formatting, completion
routine registration, `WdfRequestSend`, cancellation, waits, delays, lengthy
logging, and next-step scheduling all occur outside it.

The initiating path must run at an IRQL valid for every KMDF API it calls and
for accessing the nonpaged request context. Completion may occur at up to the
contract supported by the inspected KMDF APIs, so its bookkeeping and copied
data must remain nonpageable and bounded. Any future passive-only orchestration
must marshal work after the terminal decision; it cannot replace the lock's
completion-once decision. No second lock is selected. Adding one requires a
new design with an explicit lock order.

## 12. Request reuse rules

Reuse is legal only while the slot is `IDLE`, no generation/token/reference is
active, `TerminalProcessed` is true for the prior operation (or the request has
never been sent), and both framework-call pins are false. Cancellation,
completion, and any caller return must be fully resolved.

For every operation after the first formatted attempt, the initiator uses
`WDF_REQUEST_REUSE_PARAMS_INIT` with `WDF_REQUEST_REUSE_NO_FLAGS` and a neutral
status, then calls `WdfRequestReuse` outside the lock. The inspected KMDF 1.15
contract clears prior internal formatting allocations, completion routine and
context, target, and IRP stack state. Previous completion parameters are
therefore invalid as soon as reuse begins and must already have been copied to
the bounded snapshot.

Before reuse, the owner clears setup, active offsets/lengths, completion
status, USB status, actual length, response-valid, cancellation, submitted,
and terminal-disposition fields while retaining only the new reservation
identity required to verify the outside-lock call. Buffers may be overwritten
only after terminal completion and all call pins have returned. A reuse
failure receives no completion, releases the current lifecycle reference,
aborts activation, and marks `FAULTED`; it is not retried in place.

## 13. Activation sequencing

Only one activation step may own the slot. Step N+1 cannot reserve, prepare,
format, or submit until step N has reached terminal disposition and the slot is
`IDLE`. Failed, cancelled, stale, malformed, or invariant-faulted steps abort
the sequence and do not advance.

The step's `DelayAfterMilliseconds` is copied as sequencing metadata. No
request remains in flight to represent a delay, and completion only makes a
current successful delay eligible. A separately designed generation-bound
timer/work mechanism must execute any future delay before the next reservation;
this document neither selects nor authorizes that mechanism. The request owner
must never recursively submit step N+1 from completion.

Activation control operations and future continuous input use separate request
objects, buffers, state machines, cancellation records, and capacity rules.
The activation owner's one-slot rule does not design or constrain a future
bounded continuous reader beyond prohibiting shared ownership.

## 14. Buffer-content rules

After successful `ChatpadPrepareActivationStep`, the initiator validates
direction, `TransferLength`, `OutboundPayloadLength`, and
`ExpectedInboundLength` against each other and the exact two-byte capacity.
It clears both request-owned buffers, then copies exactly the outbound length
from the preparation value for a host-to-device operation. Inbound operations
start with a fully cleared inbound object and an exact expected length. No-data
operations expose neither memory object to formatting.

The outbound object cannot be overwritten until the operation is terminal and
all framework-call pins return. The inbound object cannot be read until a
successful completion reports an actual length. Actual length must be no
larger than both the expected length and capacity; otherwise the completion is
failed and no bytes are published. The copied completion snapshot records only
the validated length and at most two bytes.

Before every operation the response-valid bit, actual length, copied response,
and unused bytes are zeroed. Every preparation, reuse, format, send,
completion, cancellation, stale-generation, or length failure clears response
validity. Thus a later failure can never expose success data from an earlier
operation.

## 15. Parentage and cleanup

Future parentage is exact:

- `WDFDEVICE` parents the reusable activation `WDFREQUEST` and the single
  bookkeeping `WDFSPINLOCK`.
- The request owns its typed context.
- The request parents the separate outbound and inbound `WDFMEMORY` objects.
- A future USB target remains device-owned but is not selected or created by
  this checkpoint.

Initialization publishes `IDLE` only after the request, context, and both
memory objects exist. If request creation fails, the slot remains
`UNAVAILABLE`. If a later child creation fails, deleting the request deletes
already-created request children; the handle fields are cleared and no
operation reference exists. A device that never reaches D0 simply deletes the
unused parent tree during normal framework cleanup.

Normal removal first closes lifecycle admission, marks draining, cancels any
sent operation, and waits through the future approved rundown coordination.
Only after the owner has no active reference or call pin may ReleaseHardware
or device cleanup delete objects. Surprise removal uses the same idempotent
path and never frees transfer storage ahead of completion.

Cleanup callbacks do not perform terminal operation retirement. The state
machine and exact-once marker are authoritative; cleanup may assert that the
slot is `UNAVAILABLE`, `IDLE`, `DRAINING`, or already `FAULTED` without an
owned reference. If cleanup follows an already completed request, its stored
terminal disposition remains authoritative and cleanup only destroys the
object tree.

## 16. Diagnostics and invariants

Required invariants:

1. At most one activation request is formatted/submitting/in flight per device.
2. A request operation belongs to exactly one nonzero generation and one
   portable token.
3. Reuse never begins before terminal completion and return of send/cancel
   pins.
4. Each successful lifecycle acquire has exactly one release attempt; no
   terminal path releases twice.
5. `IDLE` has no active generation, token, step, lifecycle reference,
   cancellation, call pin, or response-valid data.
6. Active outbound and inbound lengths never exceed two bytes and never both
   select transfer memory.
7. A stale, cancelled, failed, or malformed completion cannot advance the
   activation sequence.
8. A cancellation request alone cannot make the slot idle.
9. No WDF request/target/memory call, wait, delay, or lengthy log occurs under
   the bookkeeping lock.
10. No asynchronous request uses stack transfer storage or a stack-backed
    completion context.
11. `AWAITING_CALL_RETURN` cannot be reused even though accounting is retired.
12. `DRAINING` cannot admit a new operation or generation.

The pure state transitions, race permutations, exact-once accounting, length
rules, and sequence dispositions should become semantic guards and portable
unit-model assertions in the first slice. Object parent/type/capacity rules
should become compile-only guards in the second slice. Lock-held API-call,
serial mismatch, impossible state, and call-pin checks should become checked-
build assertions and bounded diagnostics when runtime code is separately
authorized.

## 17. Failure and recovery matrix

| Case | Before -> required transition | Completion | Accounting | Buffer and sequence disposition | Result |
| --- | --- | --- | --- | --- | --- |
| Null preparation output/internal contract | `PREPARING` -> `RETIRING` | No | Release once | Clear both; abort | `IDLE`/`DRAINING` |
| Invalid activation step | `PREPARING` -> `RETIRING` | No | Release once | Clear both; abort | `IDLE`/`DRAINING` |
| Request not available | `UNAVAILABLE` or busy state unchanged | No new callback | No acquire, or release a just-acquired reservation once | Do not touch active buffers; reject step | Unchanged/fail closed |
| Generation no longer admissible | `IDLE` unchanged, or `PREPARING` -> `RETIRING` if rundown wins | No | No acquire, or release once | Clear new operation data; abort | `IDLE`/`DRAINING` |
| Request reuse failure | `PREPARING` -> `RETIRING` -> `FAULTED` | No | Release once | Invalidate; abort; reconstruct later | `FAULTED` |
| Transfer-memory preparation failure | `PREPARING`/`READY` -> `RETIRING` | No | Release once | Clear both; abort | `IDLE`/`DRAINING` |
| Formatting failure | `READY` -> `RETIRING` | No | Release once | Invalidate; set reuse required; abort | `IDLE`/`DRAINING` |
| Send failure with no completion | `SUBMITTING` -> `RETIRING` | No | Send path releases once | Invalidate; abort | `IDLE`/`DRAINING` |
| Successful asynchronous submission | `SUBMITTING` -> `IN_FLIGHT` | Yes | Held for completion | Buffers pinned; sequence waits | `IN_FLIGHT` |
| Immediate completion race | `SUBMITTING` -> `COMPLETING` -> `AWAITING_CALL_RETURN` -> terminal | Yes, may precede send return | Completion releases once | Snapshot bounded result; caller only clears pin; eligible success may schedule later | `IDLE`/`DRAINING` |
| Cancellation before completion | `IN_FLIGHT` -> `CANCEL_CALLING` -> `CANCEL_PENDING` | Yes | Completion releases once | Buffers pinned until completion; abort | `IDLE`/`DRAINING` |
| Normal completion races cancellation | `CANCEL_CALLING` -> `COMPLETING` -> `AWAITING_CALL_RETURN` | Yes | Completion releases once | Completion disposition wins; no reuse until cancel call returns | `IDLE`/`DRAINING` |
| Stale-generation completion | Active -> `COMPLETING` | Yes | Consume record marker; never decrement current generation; lifecycle stale result faults | Clear success; no advance | `DRAINING`/`FAULTED` |
| Duplicate/unexpected completion observation | Terminal marker already set or serial mismatch | Already occurred | No second release | Record bounded diagnostic; no buffer exposure/advance | Unchanged or `FAULTED` |
| D0 exit with request in flight | `IN_FLIGHT` -> cancellation path with draining flag | Yes | Held until completion | No new step/delay; buffers pinned | `DRAINING` after retirement |
| Surprise removal | Any active state -> draining cancellation path | Yes after successful send | Completion releases once; no fabricated release | No target/buffer deletion before retirement; abort | `DRAINING`, then cleanup |
| Cleanup after initialization failure | Partial `UNAVAILABLE` tree -> delete request tree | No | None | No active data or sequence | `UNAVAILABLE` |

Any case that violates KMDF's expected completion/no-completion contract,
reports a lifecycle stale release, exceeds fixed capacity, or loses operation
serial identity enters `FAULTED` and requires design review rather than a
retry.

## 18. Implementation decomposition

Each slice requires its own explicit task and authorization. This design does
not authorize any slice.

1. Implement a pure, WDF-independent request-owner state model and exhaustive
   race/accounting tests only.
2. Add compile-only KMDF request-context, object-parent, capacity, and type
   definitions; create no objects.
3. Add dormant request creation and cleanup with no target and no submission.
4. Add dormant outbound/inbound memory creation, clearing, and format-input
   preparation; do not format against a target.
5. Add one separately authorized asynchronous submission path only after
   target visibility, recovery, and safety gates pass.
6. Integrate completion and cancellation with lifecycle rundown under a
   separately reviewed PnP/power coordination strategy.
7. Integrate six-step sequencing and a separately designed cancelable delay
   mechanism.
8. Perform separately authorized passive hardware/stack observation with no
   activation traffic.
9. Perform separately authorized active Chatpad validation with exact request,
   stop, recovery, and controller-preservation criteria.

The smallest next slice is item 1. It must remain portable and offline and
must not contain WDF calls, object creation, target access, request formatting,
submission, cancellation, driver loading, installation, or hardware access.

## 19. Explicit decisions and open questions

Binding decisions:

1. One device owns exactly one reusable activation `WDFREQUEST`.
2. The request is explicitly parented to that `WDFDEVICE`; no global/pool or
   upper-stack request is used.
3. Separate request-parented two-byte outbound and inbound `WDFMEMORY` objects
   provide asynchronous transfer storage.
4. A device-owned slot plus typed request context binds generation, portable
   token, step, exact-once reference, call pins, and completion snapshot.
5. Send and cancellation use pre-call publication and call-return pins; the
   bookkeeping lock is never held across KMDF calls.
6. Completion is terminal owner after a successful send, including cancel and
   immediate-completion races. A false send is retired by the initiator.
7. One lifecycle acquire maps to one exact release obligation, and stale work
   never decrements the current generation.
8. Reuse requires terminal completion, returned call pins, cleared metadata,
   and `IDLE`.
9. Failed/cancelled/stale steps abort; only current success may make delay
   metadata eligible.
10. Activation request ownership remains separate from continuous input.

Rejected alternatives and reasons:

- Per-operation request allocation: more allocation/cleanup states without a
  concurrency benefit.
- Request pools or globals: violate the one-operation and per-device rules.
- Fixed raw/stack transfer arrays: the asynchronous formatter requires stable
  `WDFMEMORY`; stack lifetime is invalid.
- Device-parented or shared bidirectional memory: weakens request-coupled
  lifetime and stale-data separation.
- Synchronous control transfer or blocking wait: conflicts with cancellation,
  D0 rundown, and the required asynchronous completion model.
- Recursive next-step submission from completion: couples terminal ownership
  to timing and risks deep/racing call chains.

Open questions that do not change the ownership decisions:

- Can the selected lower-filter architecture obtain a supported
  `WDFUSBDEVICE`/default-control target without taking configuration ownership
  from `xusb22`?
- Which framework-approved deferred/nonblocking mechanism will finish D0 exit
  after request retirement?
- What timeout policy, if any, is justified before a first active submission?
- Which USB/NT status combinations and inbound bytes constitute evidence only;
  no acknowledgement or readiness meaning is currently known.
- Which cancelable timer/work mechanism will interpret the 12 ms metadata
  after request-owner implementation is proven?

A new design review is mandatory if any confirmed transfer exceeds two bytes,
more than one activation operation must be concurrent, request reuse cannot be
made legal with the selected target, completion can occur outside the assumed
KMDF lifetime, D0 exit cannot coordinate without blocking under the lock, a
buffer must outlive the request, continuous input would share activation
objects, target access requires replacing/configuring `xusb22`, or any path
would send traffic before recovery and explicit authorization gates pass.

This checkpoint is documentation only. No request, memory object, target,
completion, cancellation, delay, USB access, or runtime path exists because of
this document.
