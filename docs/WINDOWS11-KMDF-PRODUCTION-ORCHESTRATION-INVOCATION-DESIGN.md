# Windows 11 KMDF Production Orchestration Invocation Design

This is the authoritative documentation-only binding design for the first
future production invocation of the existing dormant KMDF activation
request-owner object-graph orchestrator from `ChatpadFilter`'s
`EvtDeviceAdd` path.

It documents a future source change. It does not implement or execute that
change.

## 1. Purpose and non-scope

This design covers the first production invocation of
`ChatpadKmdfRequestOwnerCreateDormantObjectGraph`, its exact
`ChatpadEvtDeviceAdd` placement, status propagation, rollback and failure
handling, successful structural ready-state publication, later
`EvtDeviceAdd` failure cleanup, callback visibility, concurrency assumptions,
IRQL assumptions, implementation decomposition, validation requirements, and
evidence requirements.

This design does not authorize or implement source changes, helper execution,
WDF object creation or deletion, target discovery, request formatting,
request reuse, request submission, completion registration, cancellation,
D0/removal rundown, signing, packaging, staging, installation, driver loading,
Windows mutation, hardware testing, controller access, or Chatpad behavior.

## 2. Current production baseline

The current production baseline was verified from tracked source and project
files:

- `src/driver/ChatpadFilter/ChatpadFilter.vcxproj` has one native
  `ProjectReference` to
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.vcxproj`.
- `src/driver/ChatpadFilter/driver.h` includes
  `ChatpadKmdfRequestOwnerContext.h`.
- `CHATPAD_FILTER_DEVICE_CONTEXT` embeds exactly one
  `ChatpadKmdfActivationRequestOwner ActivationRequestOwner`.
- `ChatpadEvtDeviceAdd` in `src/driver/ChatpadFilter/device.c` calls
  `ChatpadKmdfRequestOwnerInitializeStorage` exactly once after current scalar
  context initialization.
- `ChatpadKmdfRequestOwnerInitializeStorage` in
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`
  internally calls `ChatpadKmdfRequestOwnerValidatePreObjectState` before
  returning success.
- `ChatpadEvtDeviceAdd` then performs one additional explicit
  `ChatpadKmdfRequestOwnerValidatePreObjectState` production
  integration-boundary check.
- Existing lifecycle initialization with
  `ChatpadFilterLifecycleInitialize(&context->Lifecycle)` occurs only after
  ordinary owner initialization and the explicit pre-object validation both
  succeed.
- No production code calls
  `ChatpadKmdfRequestOwnerCreateDormantObjectGraph`,
  `ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock`,
  `ChatpadKmdfRequestOwnerCreateReusableRequest`,
  `ChatpadKmdfRequestOwnerCreateOutboundMemory`,
  `ChatpadKmdfRequestOwnerCreateInboundMemory`, or
  `ChatpadKmdfRequestOwnerRollbackPartialCreation`.
- No production request-owner spinlock, request, outbound memory, or inbound
  memory WDF object exists. `OWNER_READY` is not published. No target exists.
  No request is formatted, submitted, completed, or cancelled.

The production integration has not been executed through driver loading.

## 3. Current `EvtDeviceAdd` sequence

Current `ChatpadEvtDeviceAdd` has this exact tracked-source order:

| Step | Source function | Operation | Failure behavior | Owner state | Lifecycle state | WDF object created | Callback visibility | Target or hardware |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `ChatpadEvtDeviceAdd` | Ignore `Driver`; log lifecycle scaffold message. | None. | No owner storage exists. | Uninitialized. | None. | None. | None. |
| 2 | `ChatpadEvtDeviceAdd` | `WdfFdoInitSetFilter(DeviceInit)`. | No local status. | No owner storage exists. | Uninitialized. | None. | None. | None. |
| 3 | `ChatpadEvtDeviceAdd` | Initialize and populate `WDF_PNPPOWER_EVENT_CALLBACKS`. | No local status. | No owner storage exists. | Uninitialized. | None. | Callback pointers are registered on `DeviceInit`, not invoked. | None. |
| 4 | `ChatpadEvtDeviceAdd` | `WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(&objectAttributes, CHATPAD_FILTER_DEVICE_CONTEXT)`. | None. | No owner storage exists. | Uninitialized. | None. | None. | None. |
| 5 | `ChatpadEvtDeviceAdd` | `WdfDeviceCreate(&DeviceInit, &objectAttributes, &device)`. | On failure, log and return exact framework `NTSTATUS`. | Device context exists only on success. | Uninitialized. | `WDFDEVICE`. | No current callback runs before `EvtDeviceAdd` returns. | None. |
| 6 | `ChatpadEvtDeviceAdd` | `ChatpadFilterGetDeviceContext(device)`. | No local failure branch. | Embedded owner storage address is reachable. | Uninitialized. | None beyond `WDFDEVICE`. | No observer. | None. |
| 7 | `ChatpadEvtDeviceAdd` | Set `Signature`, `Version`, and `DiagnosticSequence = 0`. | None. | Owner storage still not initialized. | Uninitialized. | None beyond `WDFDEVICE`. | No observer. | None. |
| 8 | `ChatpadEvtDeviceAdd` -> `ChatpadKmdfRequestOwnerInitializeStorage` | Initialize ordinary owner storage once. The initializer performs internal validation. | Non-OK result maps through `ChatpadOwnerInitializationResultToStatus` and returns immediately. | Clean `MODEL_READY` pre-object baseline on success. | Uninitialized. | No request-owner WDF object. | No observer. | None. |
| 9 | `ChatpadEvtDeviceAdd` -> `ChatpadKmdfRequestOwnerValidatePreObjectState` | Perform one additional explicit integration-boundary validation. | Non-OK result returns `STATUS_INVALID_DEVICE_STATE` immediately. | Still clean `MODEL_READY` pre-object baseline. | Uninitialized. | No request-owner WDF object. | No observer. | None. |
| 10 | `ChatpadEvtDeviceAdd` -> `ChatpadFilterLifecycleInitialize` | Initialize lifecycle state. | Result captured for later mapping. | Pre-object, structurally non-ready. | Initialized only on success. | No request-owner WDF object. | No owner observer. | None. |
| 11 | `ChatpadEvtDeviceAdd` -> `ChatpadFilterLifecycleMarkDeviceCreated` | If lifecycle initialization passed, mark device created. | Result captured for later mapping. | Pre-object, structurally non-ready. | Created only on success. | No request-owner WDF object. | No owner observer. | None. |
| 12 | `ChatpadEvtDeviceAdd` -> `ChatpadLogLifecycle` | Retrieve context, increment diagnostics, snapshot lifecycle, log. | Snapshot failure is converted to an unset diagnostic snapshot. | Not read by the logger. | Snapshot only. | None. | Still inside `EvtDeviceAdd`. | None. |
| 13 | `ChatpadEvtDeviceAdd` -> `ChatpadLifecycleResultToStatus` | Return mapped lifecycle status. | Final status is returned. | Pre-object, structurally non-ready. | Depends on lifecycle result. | No request-owner WDF object. | Later callbacks can run only after successful add. | None. |

The current path creates no queue, target, request-owner WDF object, memory
object, completion callback, cancellation callback, cleanup callback, destroy
callback, timer, work item, interface, package, or hardware interaction.

## 4. Selected orchestration insertion point

The selected future insertion point is immediately after successful
`ChatpadKmdfRequestOwnerValidatePreObjectState` in `ChatpadEvtDeviceAdd` and
immediately before:

```c
lifecycleResult = ChatpadFilterLifecycleInitialize(&context->Lifecycle);
```

The immediately preceding logical statements are:

```c
ownerValidationResult = ChatpadKmdfRequestOwnerValidatePreObjectState(
    &context->ActivationRequestOwner,
    &ownerStorageValidation);
if (ownerValidationResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
    return STATUS_INVALID_DEVICE_STATE;
}
```

The intended future order is:

1. `WdfDeviceCreate` succeeds and a production `WDFDEVICE` exists.
2. `ChatpadFilterGetDeviceContext(device)` retrieves the current device
   context.
3. `Signature`, `Version`, and `DiagnosticSequence` are initialized.
4. `ChatpadKmdfRequestOwnerInitializeStorage` succeeds and performs its
   internal validation.
5. The additional explicit `ChatpadKmdfRequestOwnerValidatePreObjectState`
   succeeds.
6. `ChatpadKmdfRequestOwnerCreateDormantObjectGraph` runs exactly once.
7. The orchestrator validates structural ready state internally before
   returning success.
8. Existing `ChatpadFilterLifecycleInitialize` runs only after orchestration
   success.
9. Remaining current lifecycle marking, logging, and return mapping proceed.

This order is selected because the device context exists, scalar fields are
initialized, ordinary owner storage has a clean pre-object baseline, the
production boundary validation has passed, no callback observes the owner, and
the dormant graph requires no D0 state, target, translated resources, or
hardware.

## 5. Why orchestration precedes lifecycle initialization

Orchestration should precede the existing lifecycle initializer because no
request-owner operation is admitted, no request-owner lifecycle obligation is
held, and no current callback observes the owner at that point. An
orchestration failure can fail `EvtDeviceAdd` before lifecycle state is
initialized or marked created.

Keeping lifecycle initialization after orchestration prevents a future failure
path from having to unwind a successfully initialized lifecycle state during a
dormant object-graph failure. The dormant graph is device-lifetime structure
only; it requires the `WDFDEVICE` and ordinary owner baseline but does not
require D0 generation state, hardware resources, target discovery, or request
submission. No incompatibility was found in tracked source or installed KMDF
headers.

## 6. Exact future production call sequence

The future production code should add only local orchestration state and a
single orchestrator call in `ChatpadEvtDeviceAdd`:

1. Check `ownerStorageResult` from
   `ChatpadKmdfRequestOwnerInitializeStorage`.
2. Check `ownerValidationResult` from
   `ChatpadKmdfRequestOwnerValidatePreObjectState`.
3. Declare and initialize caller-owned report storage:
   `ChatpadKmdfRequestOwnerOrchestrationReport orchestrationReport;`.
4. Declare a result local:
   `ChatpadKmdfRequestOwnerOrchestrationResult orchestrationResult;`.
5. Invoke exactly once:

```c
orchestrationResult = ChatpadKmdfRequestOwnerCreateDormantObjectGraph(
    device,
    &context->ActivationRequestOwner,
    &orchestrationReport);
```

6. Classify `orchestrationResult` through a private local status mapping.
7. Continue only if the result is
   `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK`.
8. Treat success as requiring the orchestrator's final ready validation and
   `ObjectGraphComplete`/ready-state report evidence in offline validation.
9. Begin `ChatpadFilterLifecycleInitialize` only after success.

No retry, partial resume, second orchestrator call, direct helper call, or
caller-side `OWNER_READY` assignment is allowed.

## 7. Orchestration preconditions

Before the future call, production requires:

- valid non-null `WDFDEVICE`;
- valid non-null `CHATPAD_FILTER_DEVICE_CONTEXT`;
- owner signature `CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_SIGNATURE`;
- owner version `CHATPAD_KMDF_REQUEST_OWNER_CONTEXT_VERSION`;
- exact clean pre-object baseline;
- `MODEL_READY` present;
- `FAULTED` absent;
- `OWNER_READY` absent;
- lock/request/outbound/inbound creation bits absent;
- all WDF handle fields null;
- pure model inactive and unavailable/non-admitting;
- invalid generation;
- invalid operation token;
- invalid activation step;
- no lifecycle obligation;
- no active operation;
- no send call pin;
- no cancellation call pin;
- no sequence-advance eligibility (`SequenceAdvanceEligible == 0u`);
- no submission, completion, or cancellation state;
- zero completion snapshot;
- exact fixed outbound and inbound capacities of two bytes.

The explicit pre-object validator already checks identity, known mask,
`MODEL_READY` only, no framework handles, not owner-ready, zero transfer
storage, zero completion snapshot, pure model invariant, no active operation
or lifecycle, no `SequenceAdvanceEligible` state, and exact capacity. The
orchestrator repeats the baseline classification, rejects ready/faulted/partial
states, rejects a null parent device, creates and validates each partial state,
validates complete pre-ready state, publishes `OWNER_READY`, and validates
final ready state.

## 8. Successful result

Before production continues to lifecycle initialization, success requires:

- `MODEL_READY` present;
- lock, request, outbound-memory, and inbound-memory creation bits present;
- `OWNER_READY` present;
- `FAULTED` absent;
- bookkeeping spinlock handle non-null;
- reusable request handle non-null;
- outbound memory handle non-null;
- inbound memory handle non-null;
- request target absent because the request was created with `WDF_NO_HANDLE`;
- request unformatted;
- no submission;
- no completion routine;
- no cancellation;
- model non-admitting;
- no lifecycle obligation;
- no external-call pin.

Structural readiness means only that the dormant WDF object graph exists. It
adds no target, transfer, activation, input, keyboard, controller, or Chatpad
behavior.

## 9. Result and status mapping

The future `EvtDeviceAdd` mapping is binding:

| Orchestration result | `EvtDeviceAdd` status |
| --- | --- |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK` | Continue to lifecycle initialization; do not return yet. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_OWNER` | `STATUS_INVALID_PARAMETER`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_PARENT_DEVICE` | `STATUS_INVALID_PARAMETER`; this is an early argument rejection after baseline acceptance and before common failure handling. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_NULL_REPORT` | `STATUS_INVALID_PARAMETER`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_SIGNATURE` | `STATUS_INVALID_DEVICE_STATE`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_UNSUPPORTED_VERSION` | `STATUS_INVALID_DEVICE_STATE`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVALID_BASELINE` | `STATUS_INVALID_DEVICE_STATE`; this is an early baseline rejection before common failure handling. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ALREADY_READY` | `STATUS_INVALID_DEVICE_STATE`; this is an early baseline rejection. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ALREADY_FAULTED` | `STATUS_INVALID_DEVICE_STATE`; this is an early baseline rejection. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_PARTIAL_STATE_PRESENT` | `STATUS_INVALID_DEVICE_STATE`; this is an early baseline rejection of pre-existing partial state. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_SPINLOCK_FAILED` | If `report.FrameworkStatus` is a failed `NTSTATUS`, return it; otherwise `STATUS_INVALID_DEVICE_STATE`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_REQUEST_FAILED` | If `report.FrameworkStatus` is a failed `NTSTATUS`, return it; otherwise `STATUS_INVALID_DEVICE_STATE`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OUTBOUND_MEMORY_FAILED` | If `report.FrameworkStatus` is a failed `NTSTATUS`, return it; otherwise `STATUS_INVALID_DEVICE_STATE`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INBOUND_MEMORY_FAILED` | If `report.FrameworkStatus` is a failed `NTSTATUS`, return it; otherwise `STATUS_INVALID_DEVICE_STATE`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_PRE_READY_VALIDATION_FAILED` | `STATUS_INVALID_DEVICE_STATE`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_READY_VALIDATION_FAILED` | `STATUS_INVALID_DEVICE_STATE`. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ROLLBACK_FAILED` | `STATUS_INVALID_DEVICE_STATE`; the report preserves the original failed stage, original framework status if any, and rollback result. |
| `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_INVARIANT_FAILED` | `STATUS_INVALID_DEVICE_STATE`. |

Partial-state validation failures after staged creation do not have a dedicated
orchestration enum. The existing implementation returns the stage result that
was being validated: `SPINLOCK_FAILED`, `REQUEST_FAILED`,
`OUTBOUND_MEMORY_FAILED`, or `INBOUND_MEMORY_FAILED`. It records the exact
`FailedStage`, retains the failed validator value in `report.ValidationResult`,
retains the most recent `report.CreationResult`, and leaves
`report.FrameworkStatus` as the most recent framework status or local sentinel.
Production mapping preserves a failed framework status when one caused the
stage failure; otherwise it returns `STATUS_INVALID_DEVICE_STATE`. The common
failure path then chooses no-object fault marking or partial rollback from the
actual publication state. In the current source, staged partial-state
validation is performed only after the corresponding helper returned OK, so an
object has been published and rollback is selected for those validation
failures.

Binding principles:

- preserve exact framework failure `NTSTATUS` when present;
- use stable local status values for invariant violations;
- never convert a failed orchestration into success;
- never continue to lifecycle initialization after failure;
- expose no WDF handles or protocol payloads in diagnostics;
- preserve the original failure even when rollback also fails.

## 10. Failure taxonomy and early rejection boundaries

The design distinguishes early argument rejection, early baseline rejection,
post-baseline no-object stage failure, partial-object failure, and later
post-success failure. No rule may infer that every failure before object
publication faults the owner.

| Category | Baseline accepted | Object exists | Common failure path | Fault marking | Rollback | Expected final owner state | Orchestration result | Production status | Lifecycle |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Null production integration input before invocation | No call. | No new request-owner object. | No. | No. | No. | No orchestrator-owned transition. | None. | `STATUS_INVALID_PARAMETER`. | Does not run. |
| Null parent-device rejection from orchestrator | Yes. | No. | No. | No. | No. | Report is cleared and populated with `Result` and `FailedStage`; no source-supported fault transition is performed. | `NULL_PARENT_DEVICE`. | `STATUS_INVALID_PARAMETER`. | Does not run. |
| Invalid clean-baseline rejection | No. | No new object. | No. | No. | No. | Report is cleared before validation; populated with baseline result/failure stage when report exists; no source-supported automatic fault transition is performed. | `INVALID_SIGNATURE`, `UNSUPPORTED_VERSION`, or `INVALID_BASELINE`. | `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Already-ready rejection | No. | Existing graph may be represented. | No. | No. | No. | Rejected before creation; report may record ready evidence. | `ALREADY_READY` or `INVALID_BASELINE`. | `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Already-faulted rejection | No. | No new object. | No. | No. | No. | Existing faulted state remains rejected; no repair. | `ALREADY_FAULTED` or `INVALID_BASELINE`. | `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Existing partial-state rejection | No. | Existing handle/bit may be represented. | No. | No. | No. | Rejected without guessing ownership. | `PARTIAL_STATE_PRESENT` or `INVALID_BASELINE`. | `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Post-baseline spinlock-stage failure before publication | Yes. | No. | Yes. | Yes, through `ChatpadKmdfRequestOwnerMarkFaultedWithoutObjects` when its invariant path succeeds. | No. | Exact rolled-back fault baseline: no handles, no creation bits, `OWNER_READY` absent, `MODEL_READY | FAULTED` present. | `SPINLOCK_FAILED` or `INVARIANT_FAILED`. | Failed framework `NTSTATUS` if present; otherwise `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Request-stage failure after lock publication | Yes. | Lock. | Yes. | Through rollback result. | Yes. | On successful rollback, no handles, no creation bits, `OWNER_READY` absent, `MODEL_READY | FAULTED` present. | `REQUEST_FAILED` or `ROLLBACK_FAILED`. | Failed framework `NTSTATUS` if present unless rollback fails; rollback failure maps to `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Outbound-memory-stage failure | Yes. | Lock and request. | Yes. | Through rollback result. | Yes. | On successful rollback, exact faulted clean-object baseline. | `OUTBOUND_MEMORY_FAILED` or `ROLLBACK_FAILED`. | Failed framework `NTSTATUS` if present unless rollback fails; otherwise `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Inbound-memory-stage failure | Yes. | Lock, request, outbound memory. | Yes. | Through rollback result. | Yes. | On successful rollback, exact faulted clean-object baseline. | `INBOUND_MEMORY_FAILED` or `ROLLBACK_FAILED`. | Failed framework `NTSTATUS` if present unless rollback fails; otherwise `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Partial-state validation failure after any stage | Yes. | The just-created stage object exists in the current source. | Yes. | Through rollback result. | Yes. | Object-published validation failure rolls back to the exact faulted clean-object baseline when rollback succeeds. | Stage result for the failed validation, not a dedicated enum. | Failed framework `NTSTATUS` if present; otherwise `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Pre-ready validation failure | Yes. | Full pre-ready graph. | Yes. | Through rollback result. | Yes. | On successful rollback, exact faulted clean-object baseline. | `PRE_READY_VALIDATION_FAILED` or `ROLLBACK_FAILED`. | `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Final-ready validation failure | Yes. | Full graph, with `OWNER_READY` tentatively set then cleared. | Yes. | Through rollback result. | Yes. | On successful rollback, exact faulted clean-object baseline. | `READY_VALIDATION_FAILED` or `ROLLBACK_FAILED`. | `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Rollback rejection or failure | Yes. | Partial or ready-cleared graph may remain. | Yes. | Not proven complete. | Attempted and failed or rejected. | `OWNER_READY` absent; remaining state preserved for failure evidence. | `ROLLBACK_FAILED`. | `STATUS_INVALID_DEVICE_STATE`. | Does not run. |
| Later existing `EvtDeviceAdd` failure after structural readiness | Yes, and orchestration succeeded. | Complete dormant graph. | No orchestration failure path. | No. | No; rollback helper rejects ready owners. | Device context is being destroyed; WDF parent hierarchy owns child deletion. | `OK` from orchestration. | Later lifecycle/status mapping failure. | Lifecycle may have run according to the later failing step. |

Null parent-device rejection is a typed early argument rejection after the
baseline validator has returned success. The existing source clears the report,
sets `Result` to `NULL_PARENT_DEVICE`, sets `FailedStage` to
`VALIDATE_BASELINE`, calls no creation helper, publishes no object, calls no
rollback helper, and performs no automatic fault transition. Production must
not describe the owner as entering `MODEL_READY | FAULTED` for this path.

Invalid baseline rejection is a typed early baseline rejection before creation
starts. The existing source clears the report after a non-null report is
provided, sets default local failure fields, records initial masks when the
owner pointer is valid, may populate baseline validation details, sets
`Result` and `FailedStage`, then returns without creation, rollback, repair,
reinitialization, or fault publication. Production must not instruct `device.c`
to repair, reinitialize, fault, or roll back an invalid baseline.

Post-baseline no-object stage failure is narrower: the initial report,
arguments, and baseline have been accepted, the staged creation path has begun,
and a spinlock-stage helper or validation failure reaches the common
`OrchestrationFailure` label before any WDF object or created bit is
published. Only this path performs the documented no-object fault transition
without rollback.

## 11. Partial-object failure

A partial-object failure is any failure after a framework object handle or
created bit has been published and before final ready success. Future
production behavior:

- the orchestrator invokes centralized rollback exactly once;
- production `device.c` performs no direct deletion;
- there is no retry and no partial-state resume;
- the original framework status is preserved for status mapping when present;
- successful rollback leaves the exact faulted clean-object baseline:
  all framework handles null, all creation bits absent, `OWNER_READY` absent,
  `MODEL_READY | FAULTED` present;
- lifecycle initialization does not run;
- `EvtDeviceAdd` returns failure.

## 12. Final-ready validation failure

If `OWNER_READY` was tentatively published and final ready validation fails,
the orchestrator owns all recovery logic:

1. `OWNER_READY` is cleared inside the orchestrator.
2. The original failure stage is preserved in the report.
3. Rollback runs exactly once.
4. Success is not returned.
5. Lifecycle initialization does not run.

Production code must not duplicate or second-guess that internal logic. It
must only map the returned result and fail `EvtDeviceAdd`.

## 13. Rollback failure

If rollback fails or rejects the state, production handling is:

- require the dedicated
  `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_ROLLBACK_FAILED` result;
- preserve the original creation or validation failure in the report;
- preserve the rollback result in the report;
- perform no direct best-effort deletion in `device.c`;
- perform no retry;
- perform no lifecycle initialization;
- return failure from `EvtDeviceAdd`;
- rely on framework device-parent deletion as the final whole-device cleanup
  boundary.

Rollback failure is a hard stop for future runtime loading until independently
audited. It means offline validation or source reasoning failed to prove the
orchestrator-produced partial states are safely reversible.

## 14. Failure after orchestration succeeds

If orchestration succeeds but a later existing `EvtDeviceAdd` step fails, the
current rollback helper must not be called. It is pre-ready only and rejects
ready owners.

The authoritative strategy is:

- return the later failure from `EvtDeviceAdd`;
- rely on WDF destruction of the failed device object;
- allow the device-parented spinlock and request to be deleted through the
  failed `WDFDEVICE` hierarchy;
- allow request-parented memory deletion through the request hierarchy;
- do not manually clear ordinary owner fields because the containing device
  context is being destroyed;
- require no cleanup callback for this dormant graph because no request has
  been formatted or submitted, no completion/cancellation callback exists, and
  no operation has been admitted.

This is distinct from normal removal after future runtime request use. Once a
request can be formatted, submitted, completed, or cancelled, a separate
D0/removal rundown design must close admission and terminalize active work
before framework hierarchy deletion is treated as sufficient.

## 15. WDF parentage and deletion order

The intended parentage is exact:

- bookkeeping spinlock parent: `WDFDEVICE`;
- reusable activation request parent: `WDFDEVICE`;
- outbound preallocated memory parent: activation request;
- inbound preallocated memory parent: activation request.

Framework hierarchy deletion is therefore expected to delete the device's
children, including the request and spinlock, and to delete request-parented
memory through the request hierarchy. Manual production cleanup is not
required for a successful `EvtDeviceAdd` followed by no active operation and
normal device destruction, nor for a later `EvtDeviceAdd` failure after
structural readiness.

This does not solve future active request rundown. Future submitted requests,
completion callbacks, cancellation calls, external-call pins, lifecycle
obligations, and D0/removal synchronization require their own gate.

## 16. Callback visibility and observer analysis

Current paths that retrieve device context:

| Path | Knows about request owner today | Runs before `EvtDeviceAdd` returns | Could observe partial creation | Could observe `OWNER_READY` after future slice | Locking currently required |
| --- | --- | --- | --- | --- | --- |
| `ChatpadEvtDeviceAdd` | Yes, only at the insertion point. | Yes. | The orchestrator call is sequential; no other observer exists. | Yes, after success and before lifecycle. | No owner lock for the dormant single-threaded initialization path. |
| `ChatpadLogLifecycle` | No. | Yes, after lifecycle work. | No, because it does not read owner fields. | Only if later modified, which is outside this slice. | No owner lock today. |
| `ChatpadEvtDevicePrepareHardware` | No. | No. | No current overlap with initialization. | Only if later modified. | No owner lock today. |
| `ChatpadEvtDeviceReleaseHardware` | No. | No. | No current overlap with initialization. | Only if later modified. | No owner lock today. |
| `ChatpadEvtDeviceD0Entry` | No. | No. | No current overlap with initialization. | Only if later modified. | No owner lock today. |
| `ChatpadEvtDeviceD0Exit` | No. | No. | No current overlap with initialization. | Only if later modified. | No owner lock today. |

No current cleanup, destroy, queue, target, request, completion, cancellation,
timer, work-item, interface, unload, or surprise-removal path observes the
request owner. The first orchestration invocation slice must add no new owner
observer other than the single initialization call and result mapping.

## 17. Concurrency and publication contract

Accepted assumptions for the first production invocation slice:

- one `EvtDeviceAdd` initialization path per device instance;
- no concurrent owner observer;
- no target;
- no admitted operation;
- no formatted request;
- no submitted request;
- no completion callback;
- no cancellation callback;
- no external-call pin;
- no cleanup race.

Under those assumptions, sequential handle publication, bit publication, and
final `OWNER_READY` publication inside the orchestrator are sufficient. This
is not a general synchronization rule.

Stop conditions requiring stronger synchronization before implementation or
before a later slice:

- a D0 callback reads the owner;
- target discovery reads request-owner handles;
- an activation operation can be admitted;
- cancellation or completion exists;
- an external call can race removal;
- cleanup can race owner observation;
- any callback can observe partial state.

## 18. IRQL and execution context

Installed KMDF 1.15 header evidence under
`C:\Program Files (x86)\Windows Kits\10\Include\wdf\kmdf\1.15` shows:

- `WdfFdoInitSetFilter` is annotated
  `_IRQL_requires_max_(PASSIVE_LEVEL)`.
- `WdfDeviceCreate` is annotated `_IRQL_requires_max_(PASSIVE_LEVEL)`.
- `EVT_WDF_DEVICE_PREPARE_HARDWARE`,
  `EVT_WDF_DEVICE_RELEASE_HARDWARE`, `EVT_WDF_DEVICE_D0_ENTRY`, and
  `EVT_WDF_DEVICE_D0_EXIT` are annotated
  `_IRQL_requires_max_(PASSIVE_LEVEL)`.
- `WdfSpinLockCreate`, `WdfRequestCreate`,
  `WdfMemoryCreatePreallocated`, and `WdfObjectDelete` are annotated
  `_IRQL_requires_max_(DISPATCH_LEVEL)`.
- `WDF_OBJECT_ATTRIBUTES` contains optional `ParentObject`,
  `EvtCleanupCallback`, `EvtDestroyCallback`, `ExecutionLevel`, and
  `SynchronizationScope`.
- `WDF_OBJECT_ATTRIBUTES_INIT` defaults execution level and synchronization
  scope to inherit from parent.

Expected execution context:

- `EvtDeviceAdd`: PASSIVE_LEVEL because it calls PASSIVE-only framework APIs.
- Orchestration: PASSIVE_LEVEL at the selected `EvtDeviceAdd` point.
- `WdfSpinLockCreate`, `WdfRequestCreate`, and
  `WdfMemoryCreatePreallocated`: individually valid through DISPATCH_LEVEL
  but called from PASSIVE_LEVEL in this design.
- Rollback during orchestration failure: PASSIVE_LEVEL at the selected
  `EvtDeviceAdd` point, even though `WdfObjectDelete` is valid through
  DISPATCH_LEVEL.
- Framework deletion after failed `EvtDeviceAdd`: framework-owned; no cleanup
  callback is added by this slice.

Any unresolved IRQL conflict is a stop condition before implementation.

## 19. Production source changes for the future slice

The minimum future implementation change is expected to be `device.c` only,
unless a narrowly scoped private status helper needs an existing private
declaration location. The expected source shape is:

- one `ChatpadKmdfRequestOwnerOrchestrationReport` local;
- one `ChatpadKmdfRequestOwnerOrchestrationResult` local;
- one call to `ChatpadKmdfRequestOwnerCreateDormantObjectGraph`;
- one result/status mapping block;
- no new device-context field;
- no new global;
- no new callback;
- no project change;
- no header-boundary change;
- no direct production WDF creation/deletion call;
- no direct production rollback call.

This design does not authorize that implementation.

## 20. Binary-retention expectations

The future orchestration-call slice will intentionally retain:

- orchestration;
- creation helpers;
- rollback;
- ready and creation-state validators;
- object-attribute preparation helpers;
- WDF object-management references required by those helpers.

The future driver may therefore legitimately change size, hash, retained
COMDATs, and WDF function-table references. That implementation will be the
first production slice intentionally changing request-owner WDF object-creation
behavior. Earlier driver hashes must not be required to remain unchanged after
that implementation.

## 21. Semantic-guard design

The future implementation guard must check:

- exactly one production orchestration call;
- exact insertion point after explicit pre-object validation and before
  lifecycle initialization;
- lifecycle initialization reachable only after orchestration success;
- no retry;
- no partial-state resume;
- no direct production `WdfSpinLockCreate`, `WdfRequestCreate`,
  `WdfMemoryCreatePreallocated`, or `WdfObjectDelete` call in `device.c`;
- no direct production rollback call;
- no duplicated `OWNER_READY` assignment outside the orchestrator;
- no target discovery;
- no request formatting, reuse, send, completion routine, or cancellation;
- no D0/removal observer;
- expected retained orchestration, creation, rollback, and validation helpers;
- expected WDF function-table references for object creation/deletion;
- no request-owner `/INCLUDE` or `/WHOLEARCHIVE`;
- artifact containment beneath ignored `artifacts\`;
- evidence-manifest completeness.

Parser and text guards must be described honestly. Regex and source scans can
prove narrow textual properties, but they cannot alone prove macro expansion,
all call reachability, COMDAT retention, or KMDF function-table behavior.
Binary/object/linker evidence remains required.

## 22. Validation plan

Future offline validation must include:

- request-owner context Debug and Release;
- production orchestration guard Debug and Release;
- production linkage guard;
- owner-initialization guard;
- `ChatpadFilter` Debug and Release;
- full solution Debug and Release;
- request-owner model;
- protocol;
- transport;
- lifecycle;
- control setup;
- kernel compatibility;
- WDF control setup;
- object, COMDAT, and linker inspection;
- driver hash, size, Authenticode, and WDF function-table-reference
  inspection;
- repository safety;
- Markdown links;
- JSON parsing;
- unstaged and staged diff checks.

Current assertion baselines must be preserved unless a separately justified
test change is authorized. No driver loading is part of offline validation.

## 23. Evidence contract

The future implementation manifest is:

```text
docs/evidence/production-orchestration-invocation-manifest.json
```

It must record:

- explicit schema version;
- starting commit;
- branch;
- containing-commit binding statement;
- exact command lines;
- configuration;
- relative ignored log paths;
- SHA-256 for retained logs and generated driver artifacts;
- result and metrics;
- driver artifacts;
- retained helper evidence;
- WDF function-table-reference evidence;
- rollback and failure-path semantic evidence;
- repository safety evidence;
- diff evidence.

Full logs remain ignored beneath `artifacts\logs`.

## 24. Independent audit gate

After future orchestration implementation, an independent read-only audit is
required before runtime loading. The audit must confirm:

- exact call placement;
- exact result mapping;
- no lifecycle initialization after orchestration failure;
- no direct production WDF calls;
- no direct production rollback;
- expected retained helper set;
- no target or request operation;
- correct later `EvtDeviceAdd` failure cleanup design;
- evidence hashes;
- no installation or loading.

Offline implementation success does not authorize runtime loading.

## 25. Future runtime observation gate

A later separately authorized runtime observation would be the first time the
orchestrator and WDF object creation execute. Before that gate, require:

- implementation audit PASS;
- driver signing plan;
- rollback or failure-injection strategy where feasible;
- device-instance containment;
- Microsoft `xusb22` preservation;
- no class-wide filter;
- uninstall and recovery plan;
- explicit user authorization.

This document does not design target discovery.

## 26. Normal removal boundary

The dormant graph can rely on WDF object hierarchy only while:

- no target exists;
- no request has been formatted or submitted;
- no operation is active;
- no completion routine exists;
- no cancellation routine or call exists;
- no external-call pin exists.

Future request execution requires separate admission closure, cancellation,
completion terminalization, external-call pin rundown, lifecycle release, and
D0/removal synchronization. Framework hierarchy deletion must not substitute
for operation retirement after runtime request use is introduced.

## 27. Implementation decomposition

The next gates are:

1. Independent read-only audit of this corrected orchestration-invocation
   design.
2. Production orchestration-call implementation, offline only.
3. Independent read-only implementation audit.
4. Documentation-only runtime-observation and signing plan.
5. Separately authorized signed deployment preparation.
6. Separately authorized driver installation/loading.
7. Hardware observation of structural creation only.
8. Target-discovery design.
9. Request formatting/submission/completion/cancellation.
10. D0 and removal rundown.

These gates must not be combined.

## 28. Binding decisions and stop conditions

Binding decisions:

1. Exact insertion point: after explicit pre-object validation and before
   `ChatpadFilterLifecycleInitialize`.
2. Exact call order: scalar context setup, ordinary owner initialization,
   explicit pre-object validation, one orchestration call, structural success
   requirement, lifecycle initialization, existing remaining setup.
3. Status mapping: preserve framework failure `NTSTATUS` when present for
   creation-stage failure; map local invariant, baseline, validation, and
   rollback-failure results to stable local failures; never return success
   after orchestration failure.
4. Clean baseline: no sequence-advance eligibility is part of the required
   `SequenceAdvanceEligible == 0u` pre-object baseline.
5. Early rejection: null-parent and invalid-baseline rejections return before
   common fault handling; they do not receive the post-baseline no-object fault
   transition.
6. Post-baseline no-object stage failure: after baseline acceptance and staged
   creation entry, a no-publication spinlock-stage failure reaches common
   failure handling, does not roll back, and faults through the existing
   no-object helper.
7. Partial-state validation failure: represented through the actual failed
   stage result plus `FailedStage` and `ValidationResult`, not a dedicated
   orchestration enum; rollback is selected only when an object was published.
8. Partial rollback: orchestrator invokes centralized rollback exactly once;
   production `device.c` does not delete objects.
9. Rollback failure: dedicated rollback-failure result, original failure
   preserved in the report, no retry, no direct best-effort deletion, fail
   `EvtDeviceAdd` with the stable local failure mapping.
10. Later `EvtDeviceAdd` failure cleanup: after structural readiness, rely on
   framework deletion of the failed device object and parented children.
11. WDF parentage: spinlock and request parented to `WDFDEVICE`; outbound and
   inbound memory parented to the request.
12. Callback visibility: no new observer beyond the initialization call.
13. Concurrency assumptions: sequential publication is sufficient only while
    there is no observer, target, admitted operation, completion, cancellation,
    external call, or cleanup race.
14. IRQL assumptions: selected call runs at PASSIVE_LEVEL in `EvtDeviceAdd`;
    individual creation/deletion APIs are valid through DISPATCH_LEVEL.
15. Future implementation file scope: expected `device.c` only.
16. Binary retention: helper and WDF object-management retention is expected
    and legitimate in the future implementation slice.
17. Evidence format: tracked JSON manifest plus ignored logs under
    `artifacts\logs`.
18. Next gate: independent read-only audit of this corrected design.

Stop conditions:

- unresolved IRQL conflict;
- callback able to observe partial state;
- requirement for direct production WDF deletion;
- inability to preserve original failure status;
- lifecycle initialization reachable after orchestration failure;
- need for target access;
- requirement to modify INF or deployment;
- requirement to load the driver during an offline checkpoint;
- class-wide filter requirement;
- Microsoft `xusb22` replacement requirement.

No fundamental orchestration-invocation decision remains to be determined in
this design.
