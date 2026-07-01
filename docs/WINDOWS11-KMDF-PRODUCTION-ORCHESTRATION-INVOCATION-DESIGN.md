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

The future production code adds only local orchestration state and one
orchestrator call in `ChatpadEvtDeviceAdd`. The binding call shape is:

```c
ownerStorageResult =
    ChatpadKmdfRequestOwnerInitializeStorage(
        &context->ActivationRequestOwner);
if (ownerStorageResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
    return ChatpadOwnerInitializationResultToStatus(ownerStorageResult);
}

ownerValidationResult = ChatpadKmdfRequestOwnerValidatePreObjectState(
    &context->ActivationRequestOwner,
    &ownerStorageValidation);
if (ownerValidationResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
    return STATUS_INVALID_DEVICE_STATE;
}

ChatpadKmdfRequestOwnerOrchestrationReport orchestrationReport = { 0 };
ChatpadKmdfRequestOwnerOrchestrationResult orchestrationResult;

orchestrationResult =
    ChatpadKmdfRequestOwnerCreateDormantObjectGraph(
        device,
        &context->ActivationRequestOwner,
        &orchestrationReport);
if (orchestrationResult != orchestrationReport.Result) {
    return STATUS_INVALID_DEVICE_STATE;
}
if (orchestrationResult !=
        CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK) {
    return ChatpadOrchestrationResultToStatus(
        orchestrationResult,
        &orchestrationReport);
}
if (orchestrationReport.ObjectGraphComplete == 0u ||
    orchestrationReport.ReadyPublished == 0u) {
    return STATUS_INVALID_DEVICE_STATE;
}

lifecycleResult = ChatpadFilterLifecycleInitialize(&context->Lifecycle);
```

`ChatpadOrchestrationResultToStatus` is a design placeholder for the narrowly
scoped private mapping described in section 9, not an existing function.
Production must either implement that private helper or use an equivalent
local switch without changing the selected mappings.

The caller supplies valid writable report storage, zero-initializes it exactly
once with `{ 0 }`, passes its address to the one synchronous orchestration
call, and reads it only after that call returns. The orchestrator independently
calls `RtlZeroMemory(report, sizeof(*report))` before owner or parent
validation. Caller zero-initialization is therefore defensive rather than an
API precondition, but it is the binding production convention and makes the
future sequence deterministic.

The report is a local `EvtDeviceAdd` diagnostic/result object. It is not
embedded in the device context, contains no WDF handles, is not retained after
`EvtDeviceAdd`, has no concurrent observer, and no pointer to it may escape.
It is safe only for this synchronous call. Production must not prepopulate
report state or handles and must not inspect the report while orchestration is
running.

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

- function return and report `Result` both equal
  `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK`;
- `ReadyPublicationAttempted=TRUE`;
- `ReadyPublished=TRUE`;
- `ObjectGraphComplete=TRUE`;
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

The future `EvtDeviceAdd` mapping is deterministic and binding:

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

Production applies the mapping in this order:

1. Cross-check the function return against report `Result`; any mismatch
   returns `STATUS_INVALID_DEVICE_STATE`, preserves the report for diagnostics,
   does not invoke rollback, and does not initialize lifecycle.
2. `OK` continues; it does not itself become the final `EvtDeviceAdd` status.
3. Null production input, `NULL_OWNER`, `NULL_PARENT_DEVICE`, or `NULL_REPORT`
   returns `STATUS_INVALID_PARAMETER`.
4. A creation-stage result (`SPINLOCK_FAILED`, `REQUEST_FAILED`,
   `OUTBOUND_MEMORY_FAILED`, or `INBOUND_MEMORY_FAILED`) returns
   `report.FrameworkStatus` only when `NT_SUCCESS(report.FrameworkStatus)` is
   false.
5. Every local creation/validation failure for which `FrameworkStatus` is the
   local sentinel or `STATUS_SUCCESS` returns `STATUS_INVALID_DEVICE_STATE`.
6. `ROLLBACK_FAILED` always returns `STATUS_INVALID_DEVICE_STATE`; the
   original stage, helper/validation result, framework status, rollback result,
   effects, and masks remain diagnostic report evidence.
7. Any unrecognized result returns `STATUS_INVALID_DEVICE_STATE`.

Rollback does not overwrite `FrameworkStatus`, `CreationResult`,
`ValidationResult`, or `FailedStage`. No non-success result reaches lifecycle
initialization.

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

The authoritative
`ChatpadKmdfRequestOwnerOrchestrationReport` contract contains exactly these
19 source fields:

1. `Result`;
2. `LastStageEntered`;
3. `LastCompletedStage`;
4. `FailedStage`;
5. `BaselineValidationResult`;
6. `CreationResult`;
7. `ValidationResult`;
8. `FrameworkStatus`;
9. `RollbackResult`;
10. `RollbackEffects`;
11. `InitialInitializationMask`;
12. `HighestPartialInitializationMask`;
13. `FinalInitializationMask`;
14. `CreationHelperCalled`;
15. `ReadyPublicationAttempted`;
16. `ReadyPublished`;
17. `RollbackAttempted`;
18. `RollbackSucceeded`;
19. `ObjectGraphComplete`.

Every taxonomy row below binds all 19 fields through explicitly named grouped
columns. Within a grouped cell, values appear in the same order as the exact
field names in its header. No cell may substitute the function return value
for report `Result`, or `ReadyPublished`, final-mask `OWNER_READY`, or
`ObjectGraphComplete` for `ReadyPublicationAttempted`.

The function return and report `Result` are distinct observables. For every
path with valid report storage, the orchestrator finalizes report `Result`
before return and returns the identical value. Some paths initialize
`Result=INVARIANT_FAILED` and finalize it only after classification or
recovery. If the report pointer is null, the function returns `NULL_REPORT`
and no report field can be written. A pre-invocation production rejection
calls no orchestrator and produces neither observable.

Future production classifies first from the function return and cross-checks
report `Result` whenever valid report storage was supplied. A mismatch is an
invariant failure: preserve the report for diagnostics, do not initialize
lifecycle, return `STATUS_INVALID_DEVICE_STATE`, and do not call rollback
outside the orchestrator. A mismatch can never be treated as success.

Mask abbreviations are exact symbolic combinations:

- `P0 = MODEL_READY`;
- `P1 = P0 | LOCK_CREATED`;
- `P2 = P1 | REQUEST_CREATED`;
- `P3 = P2 | OUTBOUND_MEMORY_CREATED`;
- `P4 = P3 | INBOUND_MEMORY_CREATED`;
- `READY = P4 | OWNER_READY`;
- `FAULT = MODEL_READY | FAULTED`.

To keep the matrices readable without weakening exactness, enum notation is a
mechanical expansion to the source symbol:

- `O(X)` means
  `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_X`;
- `S(X)` means
  `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_X`;
- `C(X)` means `CHATPAD_KMDF_REQUEST_OWNER_CREATION_X`;
- `B(X)` means `CHATPAD_KMDF_REQUEST_OWNER_STORAGE_X`;
- `R(X)` means `CHATPAD_KMDF_REQUEST_OWNER_ROLLBACK_X`.

Thus `O(REQUEST_FAILED)`, for example, is the exact source enum
`CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_REQUEST_FAILED`, not a new value.

The closed non-OK validator sets used below are:

- `V_LOCK = { C(NULL_OWNER), C(INVALID_SIGNATURE),
  C(UNSUPPORTED_VERSION), C(INVALID_INITIALIZATION_MASK),
  C(OWNER_READY_PREMATURE), C(UNSUPPORTED_OR_INCONSISTENT_STATE),
  C(ACTIVE_OPERATION_OR_LIFECYCLE), C(SPINLOCK_REQUIRED),
  C(UNEXPECTED_FRAMEWORK_HANDLE) }`;
- `V_REQUEST = { C(NULL_OWNER), C(INVALID_SIGNATURE),
  C(UNSUPPORTED_VERSION), C(INVALID_INITIALIZATION_MASK),
  C(OWNER_READY_PREMATURE), C(UNSUPPORTED_OR_INCONSISTENT_STATE),
  C(ACTIVE_OPERATION_OR_LIFECYCLE), C(SPINLOCK_REQUIRED),
  C(REQUEST_REQUIRED), C(UNEXPECTED_MEMORY_HANDLE),
  C(REQUEST_CONTEXT_INVALID) }`;
- `V_OUTBOUND = { C(NULL_OWNER), C(INVALID_SIGNATURE),
  C(UNSUPPORTED_VERSION), C(INVALID_INITIALIZATION_MASK),
  C(OWNER_READY_PREMATURE), C(UNSUPPORTED_OR_INCONSISTENT_STATE),
  C(ACTIVE_OPERATION_OR_LIFECYCLE), C(SPINLOCK_REQUIRED),
  C(REQUEST_REQUIRED), C(OUTBOUND_MEMORY_REQUIRED),
  C(UNEXPECTED_MEMORY_HANDLE), C(REQUEST_CONTEXT_INVALID) }`;
- `V_ALL_MEMORY = { C(NULL_OWNER), C(INVALID_SIGNATURE),
  C(UNSUPPORTED_VERSION), C(INVALID_INITIALIZATION_MASK),
  C(OWNER_READY_PREMATURE), C(UNSUPPORTED_OR_INCONSISTENT_STATE),
  C(ACTIVE_OPERATION_OR_LIFECYCLE), C(SPINLOCK_REQUIRED),
  C(REQUEST_REQUIRED), C(OUTBOUND_MEMORY_REQUIRED),
  C(UNEXPECTED_MEMORY_HANDLE), C(INVALID_BACKING_BUFFER_CAPACITY),
  C(REQUEST_CONTEXT_INVALID) }`;
- `V_READY = { C(NULL_OWNER), C(INVALID_SIGNATURE),
  C(UNSUPPORTED_VERSION), C(INVALID_INITIALIZATION_MASK),
  C(UNSUPPORTED_OR_INCONSISTENT_STATE),
  C(ACTIVE_OPERATION_OR_LIFECYCLE), C(SPINLOCK_REQUIRED),
  C(REQUEST_REQUIRED), C(OUTBOUND_MEMORY_REQUIRED),
  C(UNEXPECTED_MEMORY_HANDLE), C(INVALID_BACKING_BUFFER_CAPACITY),
  C(REQUEST_CONTEXT_INVALID) }`.

These sets enumerate every non-OK return in
`ChatpadKmdfRequestOwnerValidateCreationState` for the named expected state.
They are closed sets; a guard must reject a taxonomy value outside them.

`RollbackEffects` contains exactly seven members. The production reachability
model is deliberately narrow and matches sections 16 and 17: one sequential
`EvtDeviceAdd` path, no concurrent owner/report writer, no callback observer,
no target, no admitted operation, no submitted request, and no cleanup race.
Under that ordinary model, every R1-R20 rollback entry is an exact P1-P4
prefix, the first classifier returns `R(OK)`, deletion completes, the final
classifier returns `R(OK)`, and only `S1`-`S4` below are reachable.

The only defensive mutation model retained for future offline fault-injection
evidence is finite and out of production scope:

1. immediately before the first rollback classifier, inject exactly one state
   from the closed `J0`, `A0`, or `AF` rows and the rollback-result table below;
2. or, after deletion/effect publication and before the final classifier,
   invalidate only signature, version, pure-model invariant, or active-model
   state while leaving all handles null and the mask exactly `FAULT`, producing
   one of `F1`-`F4`;
3. no other owner, handle, mask, report, callback, or concurrent mutation is
   permitted by the model. Anything else is an implementation stop, not an
   additional taxonomy state.

These labels are documentation labels, not source enums. The closed effect
state set is exactly 12 labels: `{ N0, J0, A0, AF, S1, S2, S3, S4, F1, F2,
F3, F4 }`.

| State | `PriorInitializationMask` | `ResultingInitializationMask` | `RequestHierarchyDeletionInitiated` | `SpinlockDeletionInitiated` | `OutboundMemoryRepresented` | `InboundMemoryRepresented` | `AlreadyClean` | Exact final owner/handles and mask | Rollback/result/success/graph/status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `N0` | `0` | `0` | `FALSE` | `FALSE` | `FALSE` | `FALSE` | `FALSE` | Rollback was not attempted. The exact remaining handles, bits, `OWNER_READY`, `FAULTED`, and final mask are the independently complete no-rollback taxonomy subcase values; the report effect record itself is all zero. | `RollbackAttempted=FALSE`; zero enum `R(OK)`; `RollbackSucceeded=FALSE`; graph completeness is the exact taxonomy value; production status is the exact taxonomy status. |
| `J0` | `0` | `0` | `FALSE` | `FALSE` | `FALSE` | `FALSE` | `FALSE` | First-classifier rejection before deletion. The exact finite injected mask/handles are unchanged and are enumerated by result in the rollback-result table; `OWNER_READY`/`FAULTED` are exactly those injected values; final mask equals that injected mask. | `RollbackAttempted=TRUE`; exact rejection result from the rollback-result table; `RollbackSucceeded=FALSE`; `ObjectGraphComplete=FALSE`; `O(ROLLBACK_FAILED)` and `STATUS_INVALID_DEVICE_STATE`; lifecycle false. |
| `A0` | `P0` | `P0` | `FALSE` | `FALSE` | `FALSE` | `FALSE` | `TRUE` | All handles null; only `MODEL_READY` retained; `OWNER_READY=FALSE`; `FAULTED=FALSE`; final mask `P0`. | `R(ALREADY_CLEAN)`; rollback attempted but not successful; graph false; `O(ROLLBACK_FAILED)`; `STATUS_INVALID_DEVICE_STATE`; lifecycle false. |
| `AF` | `FAULT` | `FAULT` | `FALSE` | `FALSE` | `FALSE` | `FALSE` | `TRUE` | All handles null; only `MODEL_READY \| FAULTED` retained; `OWNER_READY=FALSE`; final mask `FAULT`. | `R(ALREADY_CLEAN)`; rollback attempted but not successful; graph false; `O(ROLLBACK_FAILED)`; `STATUS_INVALID_DEVICE_STATE`; lifecycle false. |
| `S1` | `P1` | `FAULT` | `FALSE` | `TRUE` | `FALSE` | `FALSE` | `FALSE` | All handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; final mask `FAULT`. | `R(OK)`; rollback attempted and successful; graph false; original orchestration failure/result retained; production status follows that original failure; lifecycle false. |
| `S2` | `P2` | `FAULT` | `TRUE` | `TRUE` | `FALSE` | `FALSE` | `FALSE` | All handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; final mask `FAULT`. | `R(OK)`; rollback attempted and successful; graph false; original orchestration failure/result retained; production status follows that original failure; lifecycle false. |
| `S3` | `P3` | `FAULT` | `TRUE` | `TRUE` | `TRUE` | `FALSE` | `FALSE` | All handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; final mask `FAULT`. | `R(OK)`; rollback attempted and successful; graph false; original orchestration failure/result retained; production status follows that original failure; lifecycle false. |
| `S4` | `P4` | `FAULT` | `TRUE` | `TRUE` | `TRUE` | `TRUE` | `FALSE` | All handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; final mask `FAULT`; this includes final-ready failure after `OWNER_READY` is cleared. | `R(OK)`; rollback attempted and successful; graph false; original orchestration failure/result retained; production status follows that original failure; lifecycle false. |
| `F1` | `P1` | `FAULT` | `FALSE` | `TRUE` | `FALSE` | `FALSE` | `FALSE` | All handles null; creation bits and `OWNER_READY` absent; `FAULTED` present; final mask remains `FAULT`; only the finite post-effect identity/model fault is present. | `R(POST_ROLLBACK_INVARIANT_FAILED)`; attempted, not successful; graph false; `O(ROLLBACK_FAILED)`; `STATUS_INVALID_DEVICE_STATE`; lifecycle false. |
| `F2` | `P2` | `FAULT` | `TRUE` | `TRUE` | `FALSE` | `FALSE` | `FALSE` | All handles null; creation bits and `OWNER_READY` absent; `FAULTED` present; final mask remains `FAULT`; only the finite post-effect identity/model fault is present. | `R(POST_ROLLBACK_INVARIANT_FAILED)`; attempted, not successful; graph false; `O(ROLLBACK_FAILED)`; `STATUS_INVALID_DEVICE_STATE`; lifecycle false. |
| `F3` | `P3` | `FAULT` | `TRUE` | `TRUE` | `TRUE` | `FALSE` | `FALSE` | All handles null; creation bits and `OWNER_READY` absent; `FAULTED` present; final mask remains `FAULT`; only the finite post-effect identity/model fault is present. | `R(POST_ROLLBACK_INVARIANT_FAILED)`; attempted, not successful; graph false; `O(ROLLBACK_FAILED)`; `STATUS_INVALID_DEVICE_STATE`; lifecycle false. |
| `F4` | `P4` | `FAULT` | `TRUE` | `TRUE` | `TRUE` | `TRUE` | `FALSE` | All handles null; creation bits and `OWNER_READY` absent; `FAULTED` present; final mask remains `FAULT`; only the finite post-effect identity/model fault is present. | `R(POST_ROLLBACK_INVARIANT_FAILED)`; attempted, not successful; graph false; `O(ROLLBACK_FAILED)`; `STATUS_INVALID_DEVICE_STATE`; lifecycle false. |

The complete source-derived rollback-result inventory is:

| Exact rollback result | Classification/deletion | Exact seven effects | Exact selected entry and final owner state | Ordinary reachability | Finite defensive reachability and production handling |
| --- | --- | --- | --- | --- | --- |
| `R(OK)` | First classification accepted; P1-P4 deletion begins and final classification accepts. | One exact state `S1`, `S2`, `S3`, or `S4`; every member is expanded in the closed-state table. | Entry P1-P4 with nominal handles; final all handles null, creation/`OWNER_READY` bits absent, `FAULTED` present, mask `FAULT`. | The only reachable R1-R20 result. | Also the non-error classifier result; original orchestration result/status retained; rollback success true. |
| `R(ALREADY_CLEAN)` | First classification accepts exact P0 or `FAULT`; no deletion begins. | `A0`: `Prior=P0`, `Resulting=P0`, request-delete false, spinlock-delete false, outbound-represented false, inbound-represented false, `AlreadyClean=TRUE`; or `AF` with both masks `FAULT` and the other five Boolean members identical. | All handles null; exact P0 or `FAULT` remains unchanged. | Excluded because rollback entry was selected only after an object was observed. | Finite pre-classifier injection may replace the prefix with exact P0 or `FAULT` and null every handle; top-level/report result `O(ROLLBACK_FAILED)`, final mask P0 or `FAULT`, `STATUS_INVALID_DEVICE_STATE`, lifecycle false. |
| `R(NULL_OWNER)` | Rejection before deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | No owner exists; no final owner mask can be read. | Excluded: orchestrator passes its non-null owner. | Excluded from the finite injection model; if API misuse occurred, `O(ROLLBACK_FAILED)`, zero final report mask, stable local failure, lifecycle false. |
| `R(NULL_STATE)` | Classifier-only null-output rejection; the rollback helper cannot return it because it passes an internal non-null state address. | No rollback-report effect state is produced by this unreachable helper path. | Owner unchanged. | Excluded. | Excluded; API inventory only. |
| `R(NULL_EFFECTS)` | Rollback helper rejects before clearing effect storage or deleting. | No writable effect object exists; no report effect value can be produced. | Owner unchanged. | Excluded: orchestrator passes the report's non-null effect address. | Excluded; API inventory only. |
| `R(INVALID_SIGNATURE)` | First-classifier rejection; no deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | Finite injection: nominal P1-P4 mask/handles with signature invalid; state otherwise unchanged; final mask remains that P1-P4 prefix. | Excluded. | Permitted finite pre-classifier identity injection; `O(ROLLBACK_FAILED)`, `STATUS_INVALID_DEVICE_STATE`, lifecycle false. |
| `R(UNSUPPORTED_VERSION)` | First-classifier rejection; no deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | Nominal P1-P4 mask/handles with version invalid; unchanged; final mask remains the prefix. | Excluded. | Permitted finite pre-classifier identity injection; `O(ROLLBACK_FAILED)`, stable local failure, lifecycle false. |
| `R(INVALID_INITIALIZATION_MASK)` | First-classifier rejection; no deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | Finite injection is exactly `Pj \| DRAINING`, `j in {1,2,3,4}`, with nominal Pj handles; unchanged; final mask remains `Pj \| DRAINING`. | Excluded. | Permitted finite mask injection; `O(ROLLBACK_FAILED)`, stable local failure, lifecycle false. Unknown-bit and other mask mutations are not admitted states. |
| `R(OWNER_READY)` | First-classifier rejection; no deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | Finite injection is exactly `Pj \| OWNER_READY`, `j in {1,2,3,4}`, with nominal Pj handles; unchanged; final mask remains that value. | Excluded because the common label clears `OWNER_READY`. | Permitted finite mask injection; `O(ROLLBACK_FAILED)`, stable local failure, lifecycle false. |
| `R(ACTIVE_OPERATION_OR_LIFECYCLE)` | First-classifier rejection; no deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | Nominal P1-P4 mask/handles with exactly an active model operation/lifecycle condition; unchanged. | Excluded. | Permitted finite model injection; `O(ROLLBACK_FAILED)`, stable local failure, lifecycle false. |
| `R(INCONSISTENT_REQUEST_STATE)` | First-classifier rejection; no deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | Exact Pj mask; lock and memory handles nominal; request-handle presence is toggled relative to `REQUEST_CREATED`; unchanged. | Excluded. | Permitted finite handle injection; `O(ROLLBACK_FAILED)`, stable local failure, lifecycle false. |
| `R(INCONSISTENT_MEMORY_STATE)` | First-classifier rejection; no deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | Exact Pj mask; lock/request/inbound handles nominal; outbound-handle presence is toggled relative to `OUTBOUND_MEMORY_CREATED`; unchanged. | Excluded. | Permitted finite handle injection; `O(ROLLBACK_FAILED)`, stable local failure, lifecycle false. |
| `R(INCONSISTENT_LOCK_STATE)` | First-classifier rejection; no deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | Exact P1-P4 mask with `LOCK_CREATED` retained, `BookkeepingLock=NULL`, and remaining prefix handles nominal; unchanged. | Excluded. | Permitted finite handle injection; `O(ROLLBACK_FAILED)`, stable local failure, lifecycle false. |
| `R(INVALID_MODEL_STATE)` | First-classifier rejection; no deletion. | `Prior=0`; `Resulting=0`; request-delete false; spinlock-delete false; outbound-represented false; inbound-represented false; `AlreadyClean=FALSE` (`J0`). | Nominal P1-P4 mask/handles with exactly an invalid pure-model invariant/baseline/snapshot condition; unchanged. | Excluded. | Permitted finite model injection; `O(ROLLBACK_FAILED)`, stable local failure, lifecycle false. |
| `R(POST_ROLLBACK_INVARIANT_FAILED)` | P1-P4 deletion/effect publication completed; final classification rejected and helper collapses the classifier result to this value. | Exact `F1`, `F2`, `F3`, or `F4`; all seven members are expanded in the closed-state table. | All handles null; created/`OWNER_READY` bits absent; exact mask `FAULT`; finite injection changes only signature/version/model invariant/active-model state after effects. | Excluded; without mutation final classification accepts `FAULT`. | Permitted only at the finite post-effect injection point; `O(ROLLBACK_FAILED)`, stable local failure, lifecycle false. |
| `R(UNSUPPORTED_OR_INCONSISTENT_STATE)` | Classifier default rejection before deletion. | If ever returned with non-null effects: `Prior=0`; `Resulting=0`; all five Boolean members false (`J0`). | No selected finite entry state reaches this result after earlier ordered checks; owner would remain unchanged. | Excluded. | Excluded from the finite injection model; any observation is an implementation stop mapped to `O(ROLLBACK_FAILED)` and stable local failure. |

Before rollback, the exact nominal prefix handle contract is:

| Prefix | `BookkeepingLock` | `Request` | `OutboundMemory` | `InboundMemory` |
| --- | --- | --- | --- | --- |
| `P1` | non-null | null | null | null |
| `P2` | non-null | non-null | null | null |
| `P3` | non-null | non-null | non-null | null |
| `P4` | non-null | non-null | non-null | non-null |

After `RtlZeroMemory`, zero-valued report defaults are `LastCompletedStage =
NONE`, `FailedStage = NONE`, `BaselineValidationResult = STORAGE_OK`,
`CreationResult = CREATION_OK`, `ValidationResult = CREATION_OK`,
`RollbackResult = ROLLBACK_OK`, zero masks, zero effects, and all six flags
`FALSE`. The orchestrator then sets `Result = INVARIANT_FAILED`,
`FrameworkStatus = STATUS_INVALID_DEVICE_STATE`, and `LastStageEntered =
VALIDATE_BASELINE`. “Zero effects” below means every member of
`RollbackEffects` remains zero.
For every non-null owner, `InitialInitializationMask`,
`HighestPartialInitializationMask`, and `FinalInitializationMask` are first
set to the incoming mask. `CreationHelperCalled` becomes `1` after the
spinlock helper returns and remains `1` for every later stage. A successful
baseline records `BaselineValidationResult=STORAGE_OK`; later stages do not
change that field.

### Early rejection matrix

| Category | Baseline accepted / object published / common path | Function return; report `Result` | `LastStageEntered`; `LastCompletedStage`; `FailedStage` | `BaselineValidationResult`; `CreationResult`; `ValidationResult`; `FrameworkStatus` | `InitialInitializationMask`; `HighestPartialInitializationMask`; `FinalInitializationMask` | `CreationHelperCalled`; `ReadyPublicationAttempted`; `ReadyPublished`; `RollbackAttempted`; `RollbackSucceeded`; `ObjectGraphComplete` | `RollbackResult`; `RollbackEffects` | Final owner state | Production status / lifecycle / `EvtDeviceAdd` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Null production integration input before invocation | No call; none; no. | Function not called; report `Result` not produced. | Not applicable; not applicable; not applicable. | Not applicable; not applicable; not applicable; not applicable. | Not applicable; not applicable; not applicable. | Not applicable; not applicable; not applicable; not applicable; not applicable; not applicable. | Not applicable; not applicable. | No orchestrator-owned transition. | `STATUS_INVALID_PARAMETER`; lifecycle initializer not called; return that failure. |
| Null report pointer | No baseline; none; no. | Function returns `O(NULL_REPORT)`; report `Result` is unavailable because valid report storage does not exist. | Unavailable because valid report storage does not exist; unavailable because valid report storage does not exist; unavailable because valid report storage does not exist. | Unavailable because valid report storage does not exist; unavailable because valid report storage does not exist; unavailable because valid report storage does not exist; unavailable because valid report storage does not exist. | Unavailable because valid report storage does not exist; unavailable because valid report storage does not exist; unavailable because valid report storage does not exist. | Unavailable because valid report storage does not exist; unavailable because valid report storage does not exist; unavailable because valid report storage does not exist; unavailable because valid report storage does not exist; unavailable because valid report storage does not exist; unavailable because valid report storage does not exist. | Unavailable because valid report storage does not exist; unavailable because valid report storage does not exist. | Owner is not inspected or changed. | `STATUS_INVALID_PARAMETER`; lifecycle initializer not called; return that failure. |
| Null parent device | Yes; none; no. | Function and report `Result` are both `O(NULL_PARENT_DEVICE)`. | `S(VALIDATE_BASELINE)`; `S(NONE)`; `S(VALIDATE_BASELINE)`. | `B(OK)`; `C(OK)`; `C(OK)`; `STATUS_INVALID_DEVICE_STATE`. | `P0`; `P0`; `P0`. | `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`. | `R(OK)`; `N0`. | Clean `P0`; no automatic fault transition. | `STATUS_INVALID_PARAMETER`; lifecycle initializer not called; return that failure. |
| Null owner | No; none; no. | Function and report `Result` are both `O(NULL_OWNER)`. | `S(VALIDATE_BASELINE)`; `S(NONE)`; `S(VALIDATE_BASELINE)`. | `B(OK)`; `C(OK)`; `C(OK)`; `STATUS_INVALID_DEVICE_STATE`. | `0`; `0`; `0`. | `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`. | `R(OK)`; `N0`. | Not applicable; no owner exists. | `STATUS_INVALID_PARAMETER`; lifecycle initializer not called; return that failure. |
| Invalid clean baseline, signature, or version | No; no new object; no. | Function and report `Result` are both one member of `{ O(INVALID_SIGNATURE), O(UNSUPPORTED_VERSION), O(INVALID_BASELINE) }`. | `S(VALIDATE_BASELINE)`; `S(NONE)`; `S(VALIDATE_BASELINE)`. | For signature, version, or unknown-mask rejection `B(OK)`; after those checks, pre-object validation can write one member of `{ B(INVALID_INITIALIZATION_MASK), B(INVALID_MODEL_STATE), B(ACTIVE_OPERATION_OR_LIFECYCLE), B(INVALID_COMPLETION_SNAPSHOT), B(INVALID_TRANSFER_STORAGE) }`; `C(OK)`; `C(OK)`; `STATUS_INVALID_DEVICE_STATE`. | Actual incoming owner mask; that same incoming mask; that same incoming mask. | `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`. | `R(OK)`; `N0`. | Incoming invalid state unchanged; no repair or fault publication. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return that failure. |
| `OWNER_READY`-present baseline classification | Subcase 6A, valid already-ready: no clean baseline; exact full graph already published; no common path. Subcase 6B, invalid ready-shaped baseline: no clean baseline; incoming objects are not normalized or repaired; no common path. | 6A: function and report `Result` are both `O(ALREADY_READY)`. 6B: both are `O(INVALID_BASELINE)`. | Both: `S(VALIDATE_BASELINE)`; `S(NONE)`; `S(VALIDATE_BASELINE)`. | 6A: `B(OK)`; `C(OK)`; `C(OK)`; `STATUS_INVALID_DEVICE_STATE`. 6B: `B(OK)`; `C(OK)`; one member of `V_READY`; `STATUS_INVALID_DEVICE_STATE`. | 6A: `READY`; `READY`; `READY`. 6B: actual `IncomingInitializationMask`; the same `IncomingInitializationMask`; the same `IncomingInitializationMask`. For 6B the closed condition is: signature/version valid, no unknown initialization bit, `OWNER_READY` present, and the complete-ready validator returns a non-OK member of `V_READY`. | 6A: `FALSE`; `FALSE`; `TRUE`; `FALSE`; `FALSE`; `TRUE`. 6B: `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`. | Both: `R(OK)`; `N0` (rollback not attempted and all seven report effect members remain zero). | 6A: exact `READY`, all four required handles non-null, exact dormant request context/capacities, model baseline valid, no active operation/lifecycle, no `FAULTED` or `DRAINING`; unchanged. 6B: structurally invalid incoming owner and actual incoming mask unchanged; no faulting, rollback, repair, or reinitialization. Example: `MODEL_READY \| OWNER_READY` with missing/null required handles returns `O(INVALID_BASELINE)`, not `O(ALREADY_READY)`, and all three masks retain `MODEL_READY \| OWNER_READY`. | Both: `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Already faulted | No clean baseline; none in the accepted rolled-back-fault form; no. | Function and report `Result` are both `O(ALREADY_FAULTED)` when rollback classification proves `FAULT`, otherwise both `O(INVALID_BASELINE)`. | `S(VALIDATE_BASELINE)`; `S(NONE)`; `S(VALIDATE_BASELINE)`. | `B(OK)`; `C(OK)`; `C(OK)`; `STATUS_INVALID_DEVICE_STATE`. | Actual incoming `FAULT` or other fault-bearing mask; that same incoming mask; that same incoming mask. | `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`. | `R(OK)`; `N0`; baseline classification does not write report rollback fields. | Existing state unchanged. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return that failure. |
| Existing partial state | No clean baseline; existing prefix handles/bits may exist; no. | Function and report `Result` are both `O(PARTIAL_STATE_PRESENT)` for a recognized non-clean prefix, otherwise both `O(INVALID_BASELINE)`. | `S(VALIDATE_BASELINE)`; `S(NONE)`; `S(VALIDATE_BASELINE)`. | `B(OK)`; `C(OK)`; `C(OK)`; `STATUS_INVALID_DEVICE_STATE`. | Actual incoming partial or invalid mask; that same incoming mask; that same incoming mask. | `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`. | `R(OK)`; `N0`; baseline classification does not write report rollback fields. | Existing state unchanged; ownership is not guessed. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return that failure. |

### Creation and validation failure matrix

| Category | Baseline accepted / object published / common path | Function return; report `Result` | `LastStageEntered`; `LastCompletedStage`; `FailedStage` | `BaselineValidationResult`; `CreationResult`; `ValidationResult`; `FrameworkStatus` | `InitialInitializationMask`; `HighestPartialInitializationMask`; `FinalInitializationMask` | `CreationHelperCalled`; `ReadyPublicationAttempted`; `ReadyPublished`; `RollbackAttempted`; `RollbackSucceeded`; `ObjectGraphComplete` | `RollbackResult`; `RollbackEffects` | Final owner / fault marking | Production status / lifecycle / `EvtDeviceAdd` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Spinlock framework/local failure before publication | Yes; none; yes. | Function and report `Result` are both `O(SPINLOCK_FAILED)`. | `S(CREATE_SPINLOCK)`; `S(VALIDATE_BASELINE)`; `S(CREATE_SPINLOCK)`. | `B(OK)`; one of `{ C(ATTRIBUTE_PREPARATION_FAILED), C(WDF_SPINLOCK_CREATE_FAILED), C(POST_CREATION_INVARIANT_FAILED) }`; `C(OK)`; respectively `STATUS_INVALID_DEVICE_STATE`, the failing status returned by `WdfSpinLockCreate`, or `STATUS_SUCCESS`. | `P0`; `P0`; `FAULT`. | `TRUE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`; `FALSE`. | `R(OK)`; `N0`. | No-object helper publishes `FAULT`; no rollback. | Failing `WdfSpinLockCreate` status only for `C(WDF_SPINLOCK_CREATE_FAILED)`, otherwise `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Spinlock post-success validation failure | Yes; lock; yes. | Function and report `Result` are both `O(SPINLOCK_FAILED)`. | `S(ROLLBACK)`; `S(ROLLBACK)`; `S(CREATE_SPINLOCK)`. | `B(OK)`; helper-internal subcase `C(POST_CREATION_INVARIANT_FAILED)` or outer-validator subcase `C(OK)`; respectively `C(OK)` or one member of `V_LOCK`; `STATUS_SUCCESS`. | `P0`; `P1`; `FAULT`. | `TRUE`; `FALSE`; `FALSE`; `TRUE`; `TRUE`; `FALSE`. | `R(OK)`; `S1`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Request framework/local failure | Yes; lock only; yes. | Function and report `Result` are both `O(REQUEST_FAILED)`. | `S(ROLLBACK)`; `S(ROLLBACK)`; `S(CREATE_REQUEST)`. | `B(OK)`; one of `{ C(ATTRIBUTE_PREPARATION_FAILED), C(WDF_REQUEST_CREATE_FAILED), C(POST_CREATION_INVARIANT_FAILED) }`; `C(OK)`; respectively `STATUS_INVALID_DEVICE_STATE`, the failing status returned by `WdfRequestCreate`, or `STATUS_SUCCESS`. | `P0`; `P1`; `FAULT`. | `TRUE`; `FALSE`; `FALSE`; `TRUE`; `TRUE`; `FALSE`. | `R(OK)`; `S1`. | Rollback publishes `FAULT`. | Failing `WdfRequestCreate` status only for `C(WDF_REQUEST_CREATE_FAILED)`, otherwise `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Request post-success validation failure | Yes; lock and request; yes. | Function and report `Result` are both `O(REQUEST_FAILED)`. | `S(ROLLBACK)`; `S(ROLLBACK)`; `S(CREATE_REQUEST)`. | `B(OK)`; helper-internal subcase one of `{ C(REQUEST_CONTEXT_INVALID), C(POST_CREATION_INVARIANT_FAILED) }` or outer-validator subcase `C(OK)`; respectively `C(OK)` or one member of `V_REQUEST`; `STATUS_SUCCESS`. | `P0`; `P2`; `FAULT`. | `TRUE`; `FALSE`; `FALSE`; `TRUE`; `TRUE`; `FALSE`. | `R(OK)`; `S2`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Outbound-memory framework/local failure | Yes; lock and request; yes. | Function and report `Result` are both `O(OUTBOUND_MEMORY_FAILED)`. | `S(ROLLBACK)`; `S(ROLLBACK)`; `S(CREATE_OUTBOUND_MEMORY)`. | `B(OK)`; one of `{ C(ATTRIBUTE_PREPARATION_FAILED), C(WDF_MEMORY_CREATE_PREALLOCATED_FAILED), C(POST_CREATION_INVARIANT_FAILED) }`; `C(OK)`; respectively `STATUS_INVALID_DEVICE_STATE`, the failing status returned by outbound `WdfMemoryCreatePreallocated`, or `STATUS_SUCCESS`. | `P0`; `P2`; `FAULT`. | `TRUE`; `FALSE`; `FALSE`; `TRUE`; `TRUE`; `FALSE`. | `R(OK)`; `S2`. | Rollback publishes `FAULT`. | Failing outbound `WdfMemoryCreatePreallocated` status only for `C(WDF_MEMORY_CREATE_PREALLOCATED_FAILED)`, otherwise `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Outbound-memory post-success validation failure | Yes; lock, request, outbound memory; yes. | Function and report `Result` are both `O(OUTBOUND_MEMORY_FAILED)`. | `S(ROLLBACK)`; `S(ROLLBACK)`; `S(CREATE_OUTBOUND_MEMORY)`. | `B(OK)`; helper-internal subcase `C(POST_CREATION_INVARIANT_FAILED)` or outer-validator subcase `C(OK)`; respectively `C(OK)` or one member of `V_OUTBOUND`; `STATUS_SUCCESS`. | `P0`; `P3`; `FAULT`. | `TRUE`; `FALSE`; `FALSE`; `TRUE`; `TRUE`; `FALSE`. | `R(OK)`; `S3`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Inbound-memory framework/local failure | Yes; lock, request, outbound memory; yes. | Function and report `Result` are both `O(INBOUND_MEMORY_FAILED)`. | `S(ROLLBACK)`; `S(ROLLBACK)`; `S(CREATE_INBOUND_MEMORY)`. | `B(OK)`; one of `{ C(ATTRIBUTE_PREPARATION_FAILED), C(WDF_MEMORY_CREATE_PREALLOCATED_FAILED), C(POST_CREATION_INVARIANT_FAILED) }`; `C(OK)`; respectively `STATUS_INVALID_DEVICE_STATE`, the failing status returned by inbound `WdfMemoryCreatePreallocated`, or `STATUS_SUCCESS`. | `P0`; `P3`; `FAULT`. | `TRUE`; `FALSE`; `FALSE`; `TRUE`; `TRUE`; `FALSE`. | `R(OK)`; `S3`. | Rollback publishes `FAULT`. | Failing inbound `WdfMemoryCreatePreallocated` status only for `C(WDF_MEMORY_CREATE_PREALLOCATED_FAILED)`, otherwise `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Inbound-memory post-success validation failure | Yes; full pre-ready graph; yes. | Function and report `Result` are both `O(INBOUND_MEMORY_FAILED)`. | `S(ROLLBACK)`; `S(ROLLBACK)`; `S(CREATE_INBOUND_MEMORY)`. | `B(OK)`; helper-internal subcase `C(POST_CREATION_INVARIANT_FAILED)` or outer-validator subcase `C(OK)`; respectively `C(OK)` or one member of `V_ALL_MEMORY`; `STATUS_SUCCESS`. | `P0`; `P4`; `FAULT`. | `TRUE`; `FALSE`; `FALSE`; `TRUE`; `TRUE`; `FALSE`. | `R(OK)`; `S4`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Complete pre-ready validation failure | Yes; full pre-ready graph; yes. | Function and report `Result` are both `O(PRE_READY_VALIDATION_FAILED)`. | `S(ROLLBACK)`; `S(ROLLBACK)`; `S(VALIDATE_PRE_READY)`. | `B(OK)`; `C(OK)`; one member of `V_ALL_MEMORY`; `STATUS_SUCCESS`. | `P0`; `P4`; `FAULT`. | `TRUE`; `FALSE`; `FALSE`; `TRUE`; `TRUE`; `FALSE`. | `R(OK)`; `S4`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |
| Final-ready validation failure | Yes; full graph; yes. | Function and report `Result` are both `O(READY_VALIDATION_FAILED)`. | `S(ROLLBACK)`; `S(ROLLBACK)`; `S(VALIDATE_READY)`. | `B(OK)`; `C(OK)`; one member of `V_READY`; `STATUS_SUCCESS`. | `P0`; `P4`; `FAULT`. | `TRUE`; `TRUE`; `FALSE`; `TRUE`; `TRUE`; `FALSE`. | `R(OK)`; `S4`. | `OWNER_READY` is tentatively set, validation fails, `OWNER_READY` is cleared, and rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; return failure. |

### Rollback, success, and later-failure matrix

| Category | Baseline accepted / object published / common path | Function return; report `Result` | `LastStageEntered`; `LastCompletedStage`; `FailedStage` | `BaselineValidationResult`; `CreationResult`; `ValidationResult`; `FrameworkStatus` | `InitialInitializationMask`; `HighestPartialInitializationMask`; `FinalInitializationMask` | `CreationHelperCalled`; `ReadyPublicationAttempted`; `ReadyPublished`; `RollbackAttempted`; `RollbackSucceeded`; `ObjectGraphComplete` | `RollbackResult`; `RollbackEffects` | Final owner state | Production status / lifecycle / `EvtDeviceAdd` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Finite defensive rollback rejection before deletion | Baseline was accepted and an R1-R20 failure reached common handling, but this category is excluded from ordinary production. It exists only for the finite pre-classifier injections in the rollback-result table. | Function and report `Result` are both `O(ROLLBACK_FAILED)`. | `LastStageEntered=S(ROLLBACK)`; `LastCompletedStage` and `FailedStage` retain the exact independently complete R1-R20 origin values. | `BaselineValidationResult=B(OK)`; `CreationResult`, `ValidationResult`, and `FrameworkStatus` retain the exact R1-R20 original values. | `InitialInitializationMask=P0`; `HighestPartialInitializationMask` retains the origin P1-P4; `FinalInitializationMask` is exactly the selected finite injected mask: unchanged Pj, `Pj \| DRAINING`, `Pj \| OWNER_READY`, P0, or `FAULT`. | `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE` for R1-R19 and `TRUE` for R20; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE`; `ObjectGraphComplete=FALSE`. | Exact result is one of `{ R(INVALID_SIGNATURE), R(UNSUPPORTED_VERSION), R(INVALID_INITIALIZATION_MASK), R(OWNER_READY), R(ACTIVE_OPERATION_OR_LIFECYCLE), R(INCONSISTENT_REQUEST_STATE), R(INCONSISTENT_MEMORY_STATE), R(INCONSISTENT_LOCK_STATE), R(INVALID_MODEL_STATE), R(ALREADY_CLEAN) }`; `RollbackEffects` is `J0`, `A0`, or `AF`, with all seven values expanded above. | No deletion begins. Final handles/mask are the exact finite state in the result table; no repair follows. This category cannot occur without explicit offline fault injection and is not a permitted production execution. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; `EvtDeviceAdd` returns failure. |
| Finite post-effect rollback failure | Baseline was accepted and an R1-R20 failure reached common handling, but this category is excluded from ordinary production. It exists only for the finite identity/model injection after effect publication. | Function and report `Result` are both `O(ROLLBACK_FAILED)`. | `LastStageEntered=S(ROLLBACK)`; `LastCompletedStage` and `FailedStage` retain the exact origin values because rollback did not succeed. | `BaselineValidationResult=B(OK)`; original `CreationResult`, `ValidationResult`, and `FrameworkStatus` remain unchanged. | `InitialInitializationMask=P0`; highest mask remains the origin P1-P4; final mask exactly `FAULT`. | `CreationHelperCalled=TRUE`; attempt false for R1-R19 and true for R20; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE`; `ObjectGraphComplete=FALSE`. | `R(POST_ROLLBACK_INVARIANT_FAILED)`; exact `F1`, `F2`, `F3`, or `F4`, with all seven members expanded above. | All handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; only the finite signature/version/model fault differs. This category cannot occur in ordinary no-mutation production. | `STATUS_INVALID_DEVICE_STATE`; lifecycle initializer not called; `EvtDeviceAdd` returns failure. |
| Success | Yes with `BaselineValidationResult=B(OK)`; full graph; no failure path. | Function and report `Result` are both `O(OK)`. | `S(VALIDATE_READY)`; `S(VALIDATE_READY)`; `S(NONE)`. | `B(OK)`; `C(OK)`; `C(OK)`; `STATUS_SUCCESS`. | `P0`; `P4`; `READY`. | `TRUE`; `TRUE`; `TRUE`; `FALSE`; `FALSE`; `TRUE`. | `R(OK)`; `N0`. | Structurally ready dormant owner, no target or operation. | Continue; lifecycle initializer called; later setup continues rather than returning orchestration success directly. |
| Later existing `EvtDeviceAdd` failure after orchestration success | Yes with `BaselineValidationResult=B(OK)`; full graph; no orchestration failure path. | Function return and unchanged report `Result` are both `O(OK)`. | `S(VALIDATE_READY)`; `S(VALIDATE_READY)`; `S(NONE)`. | `B(OK)`; `C(OK)`; `C(OK)`; `STATUS_SUCCESS`. | `P0`; `P4`; `READY`. | `TRUE`; `TRUE`; `TRUE`; `FALSE`; `FALSE`; `TRUE`. | `R(OK)`; `N0`. | Ready owner exists until failed-device destruction removes its context and parented children. | Subcase 22A: lifecycle initializer returns `NULL_STATE`, device-created transition is not called, and `EvtDeviceAdd` returns `STATUS_INVALID_PARAMETER`. Subcase 22B: lifecycle initialized successfully, device-created transition returns `NOT_MARKED` or `INVALID_PHASE`, and `EvtDeviceAdd` returns `STATUS_INVALID_DEVICE_STATE`. In both: no pre-ready rollback or manual owner clearing; failed-device WDF hierarchy destruction is authoritative. |

The complete rollback-result table above supersedes the former incomplete
rejection set. Ordinary sequential orchestration permits no rejection and no
post-effect failure: R1-R20 each enter with a validated P1-P4 prefix and can
produce only `R(OK)` plus `S1`-`S4`. The finite offline fault-injection model
permits exactly the table's `J0`, `A0`, `AF`, and `F1`-`F4` cases. In
particular, `R(INVALID_INITIALIZATION_MASK)`, `R(OWNER_READY)`, and
`R(ALREADY_CLEAN)` are explicitly represented; `R(ALREADY_CLEAN)` is never
misreported as an all-zero effect record.

The following compact source-site index is informational. The independently
complete record for every origin follows it and is authoritative.

| Profile | Source category/subcase | `LastCompletedStage` | `FailedStage` | `CreationResult` | `ValidationResult` | `FrameworkStatus` | Highest prefix | Ordinary effect state |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `R1` | 10 helper-internal | `S(VALIDATE_BASELINE)` | `S(CREATE_SPINLOCK)` | `C(POST_CREATION_INVARIANT_FAILED)` | `C(OK)` | `STATUS_SUCCESS` | `P1` | `S1` |
| `R2` | 10 outer validator | `S(VALIDATE_BASELINE)` | `S(CREATE_SPINLOCK)` | `C(OK)` | one member of `V_LOCK` | `STATUS_SUCCESS` | `P1` | `S1` |
| `R3` | 11 attribute preparation | `S(CREATE_SPINLOCK)` | `S(CREATE_REQUEST)` | `C(ATTRIBUTE_PREPARATION_FAILED)` | `C(OK)` | `STATUS_INVALID_DEVICE_STATE` | `P1` | `S1` |
| `R4` | 11 `WdfRequestCreate` failure | `S(CREATE_SPINLOCK)` | `S(CREATE_REQUEST)` | `C(WDF_REQUEST_CREATE_FAILED)` | `C(OK)` | failing status returned by `WdfRequestCreate` | `P1` | `S1` |
| `R5` | 11 request null-handle anomaly | `S(CREATE_SPINLOCK)` | `S(CREATE_REQUEST)` | `C(POST_CREATION_INVARIANT_FAILED)` | `C(OK)` | `STATUS_SUCCESS` | `P1` | `S1` |
| `R6` | 12 null request context | `S(CREATE_SPINLOCK)` | `S(CREATE_REQUEST)` | `C(REQUEST_CONTEXT_INVALID)` | `C(OK)` | `STATUS_SUCCESS` | `P2` | `S2` |
| `R7` | 12 helper-internal validator | `S(CREATE_SPINLOCK)` | `S(CREATE_REQUEST)` | `C(POST_CREATION_INVARIANT_FAILED)` | `C(OK)` | `STATUS_SUCCESS` | `P2` | `S2` |
| `R8` | 12 outer validator | `S(CREATE_SPINLOCK)` | `S(CREATE_REQUEST)` | `C(OK)` | one member of `V_REQUEST` | `STATUS_SUCCESS` | `P2` | `S2` |
| `R9` | 13 attribute preparation | `S(CREATE_REQUEST)` | `S(CREATE_OUTBOUND_MEMORY)` | `C(ATTRIBUTE_PREPARATION_FAILED)` | `C(OK)` | `STATUS_INVALID_DEVICE_STATE` | `P2` | `S2` |
| `R10` | 13 outbound WDF failure | `S(CREATE_REQUEST)` | `S(CREATE_OUTBOUND_MEMORY)` | `C(WDF_MEMORY_CREATE_PREALLOCATED_FAILED)` | `C(OK)` | failing status returned by outbound `WdfMemoryCreatePreallocated` | `P2` | `S2` |
| `R11` | 13 outbound null-handle anomaly | `S(CREATE_REQUEST)` | `S(CREATE_OUTBOUND_MEMORY)` | `C(POST_CREATION_INVARIANT_FAILED)` | `C(OK)` | `STATUS_SUCCESS` | `P2` | `S2` |
| `R12` | 14 helper-internal validator | `S(CREATE_REQUEST)` | `S(CREATE_OUTBOUND_MEMORY)` | `C(POST_CREATION_INVARIANT_FAILED)` | `C(OK)` | `STATUS_SUCCESS` | `P3` | `S3` |
| `R13` | 14 outer validator | `S(CREATE_REQUEST)` | `S(CREATE_OUTBOUND_MEMORY)` | `C(OK)` | one member of `V_OUTBOUND` | `STATUS_SUCCESS` | `P3` | `S3` |
| `R14` | 15 attribute preparation | `S(CREATE_OUTBOUND_MEMORY)` | `S(CREATE_INBOUND_MEMORY)` | `C(ATTRIBUTE_PREPARATION_FAILED)` | `C(OK)` | `STATUS_INVALID_DEVICE_STATE` | `P3` | `S3` |
| `R15` | 15 inbound WDF failure | `S(CREATE_OUTBOUND_MEMORY)` | `S(CREATE_INBOUND_MEMORY)` | `C(WDF_MEMORY_CREATE_PREALLOCATED_FAILED)` | `C(OK)` | failing status returned by inbound `WdfMemoryCreatePreallocated` | `P3` | `S3` |
| `R16` | 15 inbound null-handle anomaly | `S(CREATE_OUTBOUND_MEMORY)` | `S(CREATE_INBOUND_MEMORY)` | `C(POST_CREATION_INVARIANT_FAILED)` | `C(OK)` | `STATUS_SUCCESS` | `P3` | `S3` |
| `R17` | 16 helper-internal validator | `S(CREATE_OUTBOUND_MEMORY)` | `S(CREATE_INBOUND_MEMORY)` | `C(POST_CREATION_INVARIANT_FAILED)` | `C(OK)` | `STATUS_SUCCESS` | `P4` | `S4` |
| `R18` | 16 outer validator | `S(CREATE_OUTBOUND_MEMORY)` | `S(CREATE_INBOUND_MEMORY)` | `C(OK)` | one member of `V_ALL_MEMORY` | `STATUS_SUCCESS` | `P4` | `S4` |
| `R19` | 17 pre-ready validator | `S(CREATE_INBOUND_MEMORY)` | `S(VALIDATE_PRE_READY)` | `C(OK)` | one member of `V_ALL_MEMORY` | `STATUS_SUCCESS` | `P4` | `S4` |
| `R20` | 18 final-ready validator | `S(PUBLISH_READY)` | `S(VALIDATE_READY)` | `C(OK)` | one member of `V_READY` | `STATUS_SUCCESS` | `P4`; ready attempt true | `S4` |

The valid closed ordinary origin set is `{ R1, R2, R3, R4, R5, R6, R7, R8,
R9, R10, R11, R12, R13, R14, R15, R16, R17, R18, R19, R20 }`. Each source
failure site maps to one identifier. The complete records below are the only
binding origin definitions.

+### Independently complete ordinary rollback-origin records

Each record below contains 27 binding groups and is complete without category 19, category 20, another origin row, or effect-state prose. The selected ordinary production model permits no rejection result and no post-effect failure state for any R1-R20 origin.

#### R1: spinlock helper-internal post-publication invariant failure

- **Exact `RollbackEffects` field:** `S1` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F1` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S1` and `F1` both record `PriorInitializationMask=P1`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=FALSE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(SPINLOCK_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(VALIDATE_BASELINE)`; `FailedStage=S(CREATE_SPINLOCK)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(POST_CREATION_INVARIANT_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P1`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P1`; BookkeepingLock non-null; request/outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P1` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P1 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P1 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P1`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P1`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P1`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F1`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P1`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S1` with PriorInitializationMask=P1; ResultingInitializationMask=FAULT; request-delete false; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(SPINLOCK_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R2: spinlock outer creation-state validator failure

- **Exact `RollbackEffects` field:** `S1` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F1` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S1` and `F1` both record `PriorInitializationMask=P1`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=FALSE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(SPINLOCK_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(VALIDATE_BASELINE)`; `FailedStage=S(CREATE_SPINLOCK)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(OK)`; `ValidationResult=one member of `V_LOCK``; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P1`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P1`; BookkeepingLock non-null; request/outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P1` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P1 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P1 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P1`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P1`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P1`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F1`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P1`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S1` with PriorInitializationMask=P1; ResultingInitializationMask=FAULT; request-delete false; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(SPINLOCK_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R3: request attribute-preparation failure

- **Exact `RollbackEffects` field:** `S1` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F1` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S1` and `F1` both record `PriorInitializationMask=P1`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=FALSE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(REQUEST_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_SPINLOCK)`; `FailedStage=S(CREATE_REQUEST)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(ATTRIBUTE_PREPARATION_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_INVALID_DEVICE_STATE`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P1`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P1`; BookkeepingLock non-null; request/outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P1` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P1 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P1 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P1`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P1`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P1`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F1`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P1`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S1` with PriorInitializationMask=P1; ResultingInitializationMask=FAULT; request-delete false; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(REQUEST_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R4: WdfRequestCreate failure

- **Exact `RollbackEffects` field:** `S1` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F1` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S1` and `F1` both record `PriorInitializationMask=P1`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=FALSE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(REQUEST_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_SPINLOCK)`; `FailedStage=S(CREATE_REQUEST)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(WDF_REQUEST_CREATE_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=failing WdfRequestCreate status`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P1`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P1`; BookkeepingLock non-null; request/outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P1` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P1 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P1 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P1`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P1`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P1`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F1`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P1`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S1` with PriorInitializationMask=P1; ResultingInitializationMask=FAULT; request-delete false; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(REQUEST_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `failing WdfRequestCreate status`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R5: request success/null-handle anomaly before publication

- **Exact `RollbackEffects` field:** `S1` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F1` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S1` and `F1` both record `PriorInitializationMask=P1`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=FALSE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(REQUEST_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_SPINLOCK)`; `FailedStage=S(CREATE_REQUEST)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(POST_CREATION_INVARIANT_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P1`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P1`; BookkeepingLock non-null; request/outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P1` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P1 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P1 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P1`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P1`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P1`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F1`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P1`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S1` with PriorInitializationMask=P1; ResultingInitializationMask=FAULT; request-delete false; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(REQUEST_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R6: request-context lookup returns null after request publication

- **Exact `RollbackEffects` field:** `S2` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F2` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S2` and `F2` both record `PriorInitializationMask=P2`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(REQUEST_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_SPINLOCK)`; `FailedStage=S(CREATE_REQUEST)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(REQUEST_CONTEXT_INVALID)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P2`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P2`; lock and request non-null; outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P2` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P2 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P2 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P2`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P2`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P2`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F2`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P2`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S2` with PriorInitializationMask=P2; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(REQUEST_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R7: request helper-internal post-publication validator failure

- **Exact `RollbackEffects` field:** `S2` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F2` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S2` and `F2` both record `PriorInitializationMask=P2`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(REQUEST_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_SPINLOCK)`; `FailedStage=S(CREATE_REQUEST)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(POST_CREATION_INVARIANT_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P2`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P2`; lock and request non-null; outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P2` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P2 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P2 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P2`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P2`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P2`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F2`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P2`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S2` with PriorInitializationMask=P2; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(REQUEST_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R8: request outer creation-state validator failure

- **Exact `RollbackEffects` field:** `S2` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F2` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S2` and `F2` both record `PriorInitializationMask=P2`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(REQUEST_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_SPINLOCK)`; `FailedStage=S(CREATE_REQUEST)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(OK)`; `ValidationResult=one member of `V_REQUEST``; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P2`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P2`; lock and request non-null; outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P2` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P2 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P2 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P2`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P2`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P2`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F2`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P2`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S2` with PriorInitializationMask=P2; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(REQUEST_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R9: outbound-memory attribute-preparation failure

- **Exact `RollbackEffects` field:** `S2` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F2` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S2` and `F2` both record `PriorInitializationMask=P2`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(OUTBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_REQUEST)`; `FailedStage=S(CREATE_OUTBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(ATTRIBUTE_PREPARATION_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_INVALID_DEVICE_STATE`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P2`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P2`; lock and request non-null; outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P2` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P2 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P2 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P2`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P2`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P2`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F2`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P2`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S2` with PriorInitializationMask=P2; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(OUTBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R10: outbound WdfMemoryCreatePreallocated failure

- **Exact `RollbackEffects` field:** `S2` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F2` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S2` and `F2` both record `PriorInitializationMask=P2`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(OUTBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_REQUEST)`; `FailedStage=S(CREATE_OUTBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(WDF_MEMORY_CREATE_PREALLOCATED_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=failing outbound WDF status`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P2`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P2`; lock and request non-null; outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P2` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P2 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P2 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P2`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P2`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P2`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F2`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P2`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S2` with PriorInitializationMask=P2; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(OUTBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `failing outbound WDF status`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R11: outbound-memory success/null-handle anomaly before publication

- **Exact `RollbackEffects` field:** `S2` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F2` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S2` and `F2` both record `PriorInitializationMask=P2`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=FALSE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(OUTBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_REQUEST)`; `FailedStage=S(CREATE_OUTBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(POST_CREATION_INVARIANT_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P2`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P2`; lock and request non-null; outbound/inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P2` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P2 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P2 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P2`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P2`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P2`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F2`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P2`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S2` with PriorInitializationMask=P2; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented false; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(OUTBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R12: outbound helper-internal post-publication validator failure

- **Exact `RollbackEffects` field:** `S3` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F3` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S3` and `F3` both record `PriorInitializationMask=P3`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=TRUE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(OUTBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_REQUEST)`; `FailedStage=S(CREATE_OUTBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(POST_CREATION_INVARIANT_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P3`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P3`; lock, request, and outbound non-null; inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P3` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P3 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P3 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P3`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P3`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P3`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F3`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P3`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S3` with PriorInitializationMask=P3; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented true; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(OUTBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R13: outbound outer creation-state validator failure

- **Exact `RollbackEffects` field:** `S3` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F3` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S3` and `F3` both record `PriorInitializationMask=P3`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=TRUE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(OUTBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_REQUEST)`; `FailedStage=S(CREATE_OUTBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(OK)`; `ValidationResult=one member of `V_OUTBOUND``; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P3`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P3`; lock, request, and outbound non-null; inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P3` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P3 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P3 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P3`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P3`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P3`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F3`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P3`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S3` with PriorInitializationMask=P3; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented true; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(OUTBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R14: inbound-memory attribute-preparation failure

- **Exact `RollbackEffects` field:** `S3` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F3` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S3` and `F3` both record `PriorInitializationMask=P3`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=TRUE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(INBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_OUTBOUND_MEMORY)`; `FailedStage=S(CREATE_INBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(ATTRIBUTE_PREPARATION_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_INVALID_DEVICE_STATE`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P3`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P3`; lock, request, and outbound non-null; inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P3` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P3 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P3 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P3`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P3`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P3`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F3`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P3`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S3` with PriorInitializationMask=P3; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented true; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(INBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R15: inbound WdfMemoryCreatePreallocated failure

- **Exact `RollbackEffects` field:** `S3` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F3` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S3` and `F3` both record `PriorInitializationMask=P3`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=TRUE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(INBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_OUTBOUND_MEMORY)`; `FailedStage=S(CREATE_INBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(WDF_MEMORY_CREATE_PREALLOCATED_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=failing inbound WDF status`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P3`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P3`; lock, request, and outbound non-null; inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P3` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P3 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P3 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P3`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P3`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P3`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F3`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P3`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S3` with PriorInitializationMask=P3; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented true; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(INBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `failing inbound WDF status`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R16: inbound-memory success/null-handle anomaly before publication

- **Exact `RollbackEffects` field:** `S3` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F3` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S3` and `F3` both record `PriorInitializationMask=P3`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=TRUE`, `InboundMemoryRepresented=FALSE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(INBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_OUTBOUND_MEMORY)`; `FailedStage=S(CREATE_INBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(POST_CREATION_INVARIANT_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P3`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P3`; lock, request, and outbound non-null; inbound null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P3` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P3 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P3 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P3`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P3`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P3`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F3`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P3`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S3` with PriorInitializationMask=P3; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented true; inbound-represented false; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(INBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R17: inbound helper-internal post-publication validator failure

- **Exact `RollbackEffects` field:** `S4` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F4` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S4` and `F4` both record `PriorInitializationMask=P4`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=TRUE`, `InboundMemoryRepresented=TRUE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(INBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_OUTBOUND_MEMORY)`; `FailedStage=S(CREATE_INBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(POST_CREATION_INVARIANT_FAILED)`; `ValidationResult=C(OK)`; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P4`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P4`; all four handles non-null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P4` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P4 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P4 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P4`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P4`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P4`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F4`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P4`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S4` with PriorInitializationMask=P4; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented true; inbound-represented true; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(INBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R18: inbound outer creation-state validator failure

- **Exact `RollbackEffects` field:** `S4` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F4` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S4` and `F4` both record `PriorInitializationMask=P4`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=TRUE`, `InboundMemoryRepresented=TRUE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(INBOUND_MEMORY_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_OUTBOUND_MEMORY)`; `FailedStage=S(CREATE_INBOUND_MEMORY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(OK)`; `ValidationResult=one member of `V_ALL_MEMORY``; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P4`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P4`; all four handles non-null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P4` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P4 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P4 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P4`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P4`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P4`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F4`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P4`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S4` with PriorInitializationMask=P4; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented true; inbound-represented true; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(INBOUND_MEMORY_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R19: complete pre-ready validator failure

- **Exact `RollbackEffects` field:** `S4` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F4` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S4` and `F4` both record `PriorInitializationMask=P4`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=TRUE`, `InboundMemoryRepresented=TRUE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(PRE_READY_VALIDATION_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(CREATE_INBOUND_MEMORY)`; `FailedStage=S(VALIDATE_PRE_READY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(OK)`; `ValidationResult=one member of `V_ALL_MEMORY``; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P4`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=FALSE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P4`; all four handles non-null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P4` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P4 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P4 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P4`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P4`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P4`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F4`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P4`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S4` with PriorInitializationMask=P4; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented true; inbound-represented true; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(PRE_READY_VALIDATION_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

#### R20: final-ready validator failure after tentative publication and clearing

- **Exact `RollbackEffects` field:** `S4` for the ordinary permitted outcome; `J0`, `A0`, or `AF` for a finite pre-classifier injection; `F4` for the finite post-effect injection. Every label is expanded within this record's permitted/outcome bullets.
- **Exact seven-member expansion:** `S4` and `F4` both record `PriorInitializationMask=P4`, `ResultingInitializationMask=FAULT`, `RequestHierarchyDeletionInitiated=TRUE`, `SpinlockDeletionInitiated=TRUE`, `OutboundMemoryRepresented=TRUE`, `InboundMemoryRepresented=TRUE`, and `AlreadyClean=FALSE`. `J0` records both masks `0` and all five Boolean members `FALSE`. `A0` records both masks `P0`, four deletion/representation members `FALSE`, and `AlreadyClean=TRUE`; `AF` records both masks `FAULT`, those same four members `FALSE`, and `AlreadyClean=TRUE`.
- **Original classification and report:** local `orchestrationResult` before rollback is `O(READY_VALIDATION_FAILED)`; report `Result` before rollback classification remains its initialized `O(INVARIANT_FAILED)`; `LastStageEntered=S(ROLLBACK)` at helper entry; `LastCompletedStage=S(PUBLISH_READY)`; `FailedStage=S(VALIDATE_READY)`; `BaselineValidationResult=B(OK)`; `CreationResult=C(OK)`; `ValidationResult=one member of `V_READY``; `FrameworkStatus=STATUS_SUCCESS`; `InitialInitializationMask=P0`; `HighestPartialInitializationMask=P4`; `CreationHelperCalled=TRUE`; `ReadyPublicationAttempted=TRUE`; `ReadyPublished=FALSE`; `RollbackAttempted=TRUE`; `RollbackSucceeded=FALSE` before the helper result; `ObjectGraphComplete=FALSE`.
- **Rollback-entry preconditions:** signature/version valid; initial P0 baseline accepted; exact mask `P4`; all four handles non-null; `OWNER_READY=FALSE`; `FAULTED=FALSE`; pure model valid and inactive; no lifecycle obligation, admitted operation, target, formatted/submitted request, completion, cancellation, external-call pin, callback observer, cleanup race, or concurrent owner/report mutation.
- **Permitted outcomes, complete:** ordinary production permits no rejection and no post-effect failure. Finite offline pre-classifier injection permits exactly: `R(INVALID_SIGNATURE)`, `R(UNSUPPORTED_VERSION)`, `R(INVALID_MODEL_STATE)`, or `R(ACTIVE_OPERATION_OR_LIFECYCLE)` with mask `P4` and nominal prefix handles except the named identity/model fault; `R(INVALID_INITIALIZATION_MASK)` with exact mask `P4 | DRAINING` and nominal handles; `R(OWNER_READY)` with exact mask `P4 | OWNER_READY` and nominal handles; `R(INCONSISTENT_LOCK_STATE)` with mask `P4`, lock null, other prefix handles nominal; `R(INCONSISTENT_REQUEST_STATE)` with mask `P4`, request-handle presence opposite its bit, other handles nominal; `R(INCONSISTENT_MEMORY_STATE)` with mask `P4`, outbound-handle presence opposite its bit, other handles nominal; or `R(ALREADY_CLEAN)` after exact replacement by P0 or `FAULT` with every handle null. Every rejection except `ALREADY_CLEAN` has `J0`: all seven effects zero, no deletion, rollback not successful, final mask/owner equal the injected state. `ALREADY_CLEAN` has `A0` or `AF`: prior/resulting mask P0 or `FAULT`, both delete flags false, both represented flags false, `AlreadyClean=TRUE`, rollback not successful, and final owner unchanged. Finite post-effect injection permits only `R(POST_ROLLBACK_INVARIANT_FAILED)` with `F4`: all handles null, final mask `FAULT`, rollback not successful, and the seven effect values explicitly bound in this record's ordinary effect tuple except the result is post-effect failure. Every finite injected outcome changes final function/report result to `O(ROLLBACK_FAILED)`, preserves the original failure fields and highest mask `P4`, leaves `ReadyPublished=FALSE` and `ObjectGraphComplete=FALSE`, returns `STATUS_INVALID_DEVICE_STATE`, does not call lifecycle, and makes `EvtDeviceAdd` return failure.
- **Only permitted ordinary outcome:** `RollbackResult=R(OK)`; effect state `S4` with PriorInitializationMask=P4; ResultingInitializationMask=FAULT; request-delete true; spinlock-delete true; outbound-represented true; inbound-represented true; AlreadyClean=FALSE; `RollbackSucceeded=TRUE`; `LastCompletedStage=S(ROLLBACK)`; final function result and report `Result` both remain `O(READY_VALIDATION_FAILED)`; `FinalInitializationMask=FAULT`; all handles null; all creation bits and `OWNER_READY` absent; `FAULTED` present; `ReadyPublished=FALSE`; `ObjectGraphComplete=FALSE`; production returns `STATUS_INVALID_DEVICE_STATE`; lifecycle is not called; `EvtDeviceAdd` returns that failure.

The source-site mapping is one-to-one: the two spinlock post-publication exits map to R1-R2; request exits map to R3-R8; outbound exits map to R9-R13; inbound exits map to R14-R18; complete pre-ready validation maps to R19; and final-ready validation maps to R20. No additional `goto OrchestrationFailure` site creates another ordinary rollback origin.


#### Category 22A: lifecycle initialization fails

Orchestration has already succeeded and the completed-success report remains
unchanged. `ChatpadFilterLifecycleInitialize` is called and returns
`CHATPAD_FILTER_LIFECYCLE_NULL_STATE`, its only source-supported failure. No
lifecycle fields are initialized. `ChatpadFilterLifecycleMarkDeviceCreated`
is not called. `EvtDeviceAdd` returns `STATUS_INVALID_PARAMETER` through
`ChatpadLifecycleResultToStatus(lifecycleResult)`. Production does not call
pre-ready orchestration rollback or clear owner state manually. WDF destruction
of the failed device object deletes the request-owner graph through its
established object parentage. With the current valid device-context pointer,
this remains a defensive failure path rather than an expected path.

#### Category 22B: device-created transition fails

Orchestration has already succeeded and the completed-success report remains
unchanged. `ChatpadFilterLifecycleInitialize` returns
`CHATPAD_FILTER_LIFECYCLE_OK`, so lifecycle is initialized successfully.
`ChatpadFilterLifecycleMarkDeviceCreated` is then called. Its source-supported
failures after a non-null successful initializer are
`CHATPAD_FILTER_LIFECYCLE_NOT_MARKED` or
`CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE`; either maps to
`STATUS_INVALID_DEVICE_STATE`. Production does not call pre-ready orchestration
rollback or clear owner state manually. Failed-device WDF hierarchy
destruction remains authoritative. This is distinct from future normal removal
after active request work. The current successful initializer establishes the
required mark and unset phase, so this is also a defensive unexpected-state
path.

Current `device.c` has no other failure point after lifecycle initialization
and the device-created transition, so 22A and 22B are the only current
post-orchestration failure subcases.

### Ready-field truth table

`OWNER_READY` never contributes to
`HighestPartialInitializationMask` during an accepted creation run. Early
rejection instead retains the incoming mask, so the ready-state early rows are
listed separately.

| Path | `ReadyPublicationAttempted` | `ReadyPublished` | `OWNER_READY` in `HighestPartialInitializationMask` | `OWNER_READY` in `FinalInitializationMask` | `ObjectGraphComplete` |
| --- | --- | --- | --- | --- | --- |
| Null report | Unavailable because valid report storage does not exist | Unavailable because valid report storage does not exist | Unavailable because valid report storage does not exist | Unavailable because valid report storage does not exist | Unavailable because valid report storage does not exist |
| Early rejection without incoming `OWNER_READY` | `FALSE` | `FALSE` | No | No | `FALSE` |
| `O(ALREADY_READY)` | `FALSE` | `TRUE` | Yes | Yes | `TRUE` |
| Ready-bit state rejected as `O(INVALID_BASELINE)` | `FALSE` | `FALSE` | Yes | Yes | `FALSE` |
| Spinlock failure | `FALSE` | `FALSE` | No | No (`FAULT`) | `FALSE` |
| Request failure | `FALSE` | `FALSE` | No | No (`FAULT`) | `FALSE` |
| Outbound-memory failure | `FALSE` | `FALSE` | No | No (`FAULT`) | `FALSE` |
| Inbound-memory failure | `FALSE` | `FALSE` | No | No (`FAULT`) | `FALSE` |
| Pre-ready validation failure | `FALSE` | `FALSE` | No | No (`FAULT`) | `FALSE` |
| Final-ready validation failure with successful rollback | `TRUE` | `FALSE` | No (`P4`) | No (`FAULT`) | `FALSE` |
| Finite category-19 injection after final-ready failure (`R20`) | `TRUE` | `FALSE` | No (`P4`) | Yes only for exact injected `P4 \| OWNER_READY`; otherwise no for the closed J0/A0/AF final masks | `FALSE` |
| Category 20 post-effect failure after final-ready failure (`R20`) | `TRUE` | `FALSE` | No (`P4`) | No (`FAULT`) | `FALSE` |
| Successful orchestration | `TRUE` | `TRUE` | No (`P4`) | Yes (`READY`) | `TRUE` |
| Later `EvtDeviceAdd` failure after orchestration success | `TRUE` | `TRUE` | No (`P4`) | Yes (`READY`) | `TRUE` |

`HighestPartialInitializationMask` is initialized from the incoming owner mask
for every non-null owner, so an early rejection retains that incoming mask and
can include pre-existing `OWNER_READY` or `FAULTED`. After an accepted clean
`P0` baseline it is updated after each successfully validated publication to
`P1`, `P2`, `P3`, and `P4`. At the common failure label it is recomputed from
the then-current mask with `OWNER_READY` removed, so a failure before spinlock
publication records `P0`, each partial failure records its actual published
prefix, and tentative ready publication still records `P4`. In an accepted
creation run it never includes the later no-object/rollback `FAULTED`
publication, and rollback does not change it. On success it remains `P4`, not
`READY`.

`FinalInitializationMask` is initialized from the incoming mask for every
non-null owner and is captured again immediately before each success or
failure return that passes the early classifier. Early rejection therefore
retains the incoming mask; null owner retains zero because no owner mask can be
read. Successful no-object fault marking and successful partial rollback record
`FAULT`; final-ready validation failure followed by successful rollback also
records `FAULT`; success records `READY`. Finite category-19 rejection before
deletion retains exactly one selected injected mask from `{ Pj, Pj | DRAINING,
Pj | OWNER_READY, P0, FAULT }`, with `j in {1,2,3,4}`, and the exact handles
bound by the rollback-result table. Finite category-20 failure after effects
records exactly `FAULT`. Unlike the
highest-partial mask, the final mask may contain `FAULTED` or `OWNER_READY`.

`ValidationResult` always retains the most recent orchestrator-level
creation-state validator result. It remains its zero default when no such
validator ran, may remain the prior successful stage result when a helper
itself fails, records each successful post-stage validation in turn, and holds
the exact failing pre-ready or ready validator result. `FrameworkStatus`
starts as `STATUS_INVALID_DEVICE_STATE`, changes after each helper to that
helper's status, normally ends as `STATUS_SUCCESS` after successful WDF
creation, and is never overwritten by rollback.

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

1. The ready-publication stage is entered.
2. Exact report field `ReadyPublicationAttempted` becomes `TRUE`.
3. `OWNER_READY` is tentatively present in the owner mask.
4. Final-ready validation fails.
5. `OWNER_READY` is cleared inside the orchestrator.
6. The original failed stage and validation result are preserved, and rollback
   runs exactly once.
7. `FinalInitializationMask` captures the actual final return state.
8. Function return and report `Result` remain the same failure
   (`READY_VALIDATION_FAILED` after successful rollback or `ROLLBACK_FAILED`
   after rollback failure).
9. Lifecycle initialization does not run.

Production code must not duplicate or second-guess that internal logic. It
must map the function return, cross-check report `Result`, and fail
`EvtDeviceAdd`.

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

Production must inspect `RollbackAttempted`, `RollbackResult`,
`RollbackSucceeded`, `RollbackEffects`, and `FinalInitializationMask`; it must
not infer cleanup completion from the top-level orchestration result alone.

Rollback failure is a hard stop for future runtime loading until independently
audited. It means offline validation or source reasoning failed to prove the
orchestrator-produced partial states are safely reversible.

## 14. Failure after orchestration succeeds

If orchestration succeeds but a later existing `EvtDeviceAdd` step fails, the
current rollback helper must not be called. It is pre-ready only and rejects
ready owners. The only current subcases are taxonomy subcases 22A and 22B:
the lifecycle initializer is called and fails, or it succeeds and the
device-created lifecycle transition is called and fails.

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

LTCG can inline, fold, rename, or remove individually observable symbols.
Absence of a named symbol from the final PE image does not prove that its code
or object was absent from linker input, and a source/object reference does not
guarantee a separately visible final-image symbol. Retention proof must combine
source references, object inputs, COMDAT/function-level-linking evidence,
linker settings, observed LTCG behavior, WDF function-table references, and
final-image inspection. The design does not require disabling LTCG.

## 21. Semantic-guard design

The future implementation guard must check:

- exactly one zero-initialized local
  `ChatpadKmdfRequestOwnerOrchestrationReport` declaration;
- no report field embedded in the device context and no report pointer escape;
- exactly one production orchestration call;
- the one call receives the local report and the result/report are checked
  before lifecycle initialization;
- taxonomy binds exact report fields `Result` and
  `ReadyPublicationAttempted`;
- valid `O(ALREADY_READY)` requires exact `READY` plus the complete ready
  invariants, while an invalid `OWNER_READY`-bearing baseline preserves its
  actual incoming mask in all three report-mask fields and is never normalized
  to `READY`;
- source/semantic inspection proves
  `ReadyPublicationAttempted=FALSE` on every accepted path before
  `S(PUBLISH_READY)`, including all framework, post-stage, and pre-ready
  failures;
- source/semantic inspection proves
  `ReadyPublicationAttempted=TRUE` for final-ready validation failure,
  category 19/20 profile `R20`, success, and later `EvtDeviceAdd` failure
  after orchestration success;
- rollback must preserve `ReadyPublicationAttempted=TRUE` for profile `R20`;
  no rollback assignment may clear it;
- the guard compares the ready-field truth table and rejects any earlier
  framework or validation failure with `ReadyPublicationAttempted=TRUE`;
- `ReadyPublicationAttempted` is checked independently from `ReadyPublished`,
  `ObjectGraphComplete`, and `OWNER_READY` in `FinalInitializationMask`;
- production classification reads the function return and cross-checks report
  `Result`;
- a return/report mismatch is a hard `STATUS_INVALID_DEVICE_STATE` failure,
  preserves diagnostics, invokes no production rollback, and cannot reach
  lifecycle initialization;
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
- `FrameworkStatus` used only for a failed creation-stage result and only when
  it contains a failing `NTSTATUS`;
- rollback failure kept distinguishable and mask/report fields available for
  offline evidence;
- every taxonomy category and closed subcase resolves all 19 report fields;
- every one of the 16 source rollback-result enum values is classified by the
  complete rollback-result table, including `R(ALREADY_CLEAN)`,
  `R(INVALID_INITIALIZATION_MASK)`, and `R(OWNER_READY)`;
- `RollbackEffects` must match exactly one of the 12 closed documentation
  labels `{ N0, J0, A0, AF, S1, S2, S3, S4, F1, F2, F3, F4 }`;
  `R(ALREADY_CLEAN)` must use `A0` or `AF`, never `N0` or `J0`;
- ordinary production permits only `R(OK)` and `S1`-`S4` for R1-R20; finite
  offline injected outcomes must match the exact J0/A0/AF/F1-F4 definitions,
  and no unbounded mutation state is accepted;
- all independently complete R1-R20 records must exist one-to-one with source
  failure sites, R1-R19 must record ready-attempt false, R20 must record true,
  and every record must state its exact permitted outcomes;
- evidence validation must require one manifest/test entry for every identifier
  in the exact closed range R1-R20;
- taxonomy subcases 22A and 22B distinguish lifecycle-initializer failure from
  device-created-transition failure;
- `HighestPartialInitializationMask` and `FinalInitializationMask` remain
  explicitly available for evidence;
- no diagnostic output containing WDF handles or protocol payloads;
- expected retained orchestration, creation, rollback, and validation helpers;
- expected WDF function-table references for object creation/deletion;
- no request-owner `/INCLUDE` or `/WHOLEARCHIVE`;
- artifact containment beneath ignored `artifacts\`;
- evidence-manifest completeness.

Parser and text guards must be described honestly. Regex and source scans can
prove narrow textual properties, but they cannot alone prove macro expansion,
all call reachability, COMDAT retention, LTCG transformation, report-pointer
non-escape, or KMDF function-table behavior. Binary/object/linker evidence and
focused source review remain required; no parser-grade claim is permitted.

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
- orchestration result-mapping guard evidence;
- report zero-initialization and lifetime guard evidence;
- failure-taxonomy guard evidence and expected statically testable report
  fields;
- category/subcase evidence for every exact report field:
  `Result`, `LastStageEntered`, `LastCompletedStage`, `FailedStage`,
  `BaselineValidationResult`, `CreationResult`, `ValidationResult`,
  `FrameworkStatus`, `RollbackResult`, `RollbackEffects`,
  `InitialInitializationMask`, `HighestPartialInitializationMask`,
  `FinalInitializationMask`, `CreationHelperCalled`,
  `ReadyPublicationAttempted`, `ReadyPublished`, `RollbackAttempted`,
  `RollbackSucceeded`, and `ObjectGraphComplete`;
- exact `RollbackEffects` member evidence proving one of the 12 closed labels
  `{ N0, J0, A0, AF, S1, S2, S3, S4, F1, F2, F3, F4 }`, including populated
  prior/resulting masks and `AlreadyClean=TRUE` for `A0`/`AF`;
- one-to-one evidence entries for every identifier in the exact closed range
  R1-R20: `R1`, `R2`, `R3`, `R4`, `R5`, `R6`, `R7`, `R8`, `R9`, `R10`,
  `R11`, `R12`, `R13`, `R14`, `R15`, `R16`, `R17`, `R18`, `R19`, and `R20`;
- every R1-R20 entry must record the origin identifier and named source
  stage/site; all expected report fields; expected rollback result; all seven
  exact rollback-effect member values; expected highest and final masks; final
  owner state; final orchestration function result and report `Result`;
  production status; lifecycle false; command; configuration; result;
  assertion count when applicable; repository-relative evidence path; and
  SHA-256;
- R1-R19 entries must prove `ReadyPublicationAttempted=FALSE`; R20 must prove
  `ReadyPublicationAttempted=TRUE`; all must prove `ReadyPublished=FALSE`, no
  `OWNER_READY` in highest/final masks, and `ObjectGraphComplete=FALSE` for the
  ordinary successful-rollback outcome;
- each R1-R20 entry must prove its ordinary `R(OK)`/S1-S4 outcome and every
  finite permitted J0/A0/AF/F1-F4 injected outcome listed in that origin's
  self-contained record, including preservation of original failure fields,
  final result/status/mask, and no lifecycle;
- ready-field truth-table evidence, including source-level proof that only
  `S(PUBLISH_READY)` sets `ReadyPublicationAttempted` and rollback does not
  clear it;
- function-return/report-`Result` consistency evidence and mismatch hard-fail
  evidence;
- deterministic category 22A/22B lifecycle evidence;
- no-external-rollback and no-lifecycle-after-orchestration-failure evidence;
- static or test evidence for exact
  `HighestPartialInitializationMask` progression through `P0`, `P1`, `P2`,
  `P3`, and `P4`, including proof that rollback does not rewrite it;
- static or test evidence for exact `FinalInitializationMask` behavior on
  early rejection with valid report storage, post-baseline no-object fault,
  successful partial rollback, rollback failure, final-ready validation
  failure, and success;
- evidence that each final mask equals the actual final owner state and that
  `OWNER_READY` and `FAULTED` presence matches the documented category;
- exact command, result, and SHA-256 binding for both mask checks;
- retained helper evidence;
- COMDAT/function-level-linking and LTCG analysis;
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

1. Independent read-only audit of this finalized defensive taxonomy and
   report-contract design.
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

The exact 19-field binding is:

| Exact field | Binding meaning and authoritative source | Production use | Guard/evidence requirement |
| --- | --- | --- | --- |
| `Result` | Final orchestration classification written on every return with valid report storage; authoritative assignments are in `ChatpadKmdfRequestOwnerCreateDormantObjectGraph`. | Cross-check against the function return before status selection; mismatch is failure. | Prove equality on every valid-report category and hard failure on mismatch. |
| `LastStageEntered` | Most recent orchestration stage entered; rollback overwrites it with `S(ROLLBACK)`. | Diagnostic only; never independently selects success. | Check every category and rollback transition. |
| `LastCompletedStage` | Last stage completed successfully; becomes `S(ROLLBACK)` only after rollback succeeds. | Diagnostic only. | Check defaults, every stage completion, rollback success, and rollback failure preservation. |
| `FailedStage` | Stage that caused the orchestration failure; rollback does not overwrite it. | Diagnostic classification; never independently maps to success. | Check every failure category and profile `R1`-`R20`. |
| `BaselineValidationResult` | Exact result of pre-object validation when it runs; otherwise zero enum `B(OK)`. | Diagnostic only. | Check early-return defaults and accepted-baseline `B(OK)`. |
| `CreationResult` | Latest creation-helper result; later validators and rollback preserve it. | Diagnostic; interpreted with `Result` and `FrameworkStatus`. | Check every helper subcase and profile `R1`-`R20`. |
| `ValidationResult` | Latest orchestrator-level creation-state validator result; helper failures preserve the preceding value. | Diagnostic; never substitutes for function return. | Check every closed validator set and retained `C(OK)` case. |
| `FrameworkStatus` | Sentinel before helper calls, then exact status output from the latest helper; rollback never overwrites it. | Return only for a creation-stage `Result` when it is failing. | Prove conditional use and preservation through rollback. |
| `RollbackResult` | Zero enum `R(OK)` until rollback runs; then exact rollback-helper result. | Diagnostic; top-level `O(ROLLBACK_FAILED)` still maps to stable local failure. | Classify all 16 source enum values; ordinary R1-R20 permits only `R(OK)`; finite injected results must match the complete result table. |
| `RollbackEffects` | Seven-member record; no-attempt, rejection, already-clean, successful, and post-effect cases use exactly one of the 12 closed labels `{ N0, J0, A0, AF, S1, S2, S3, S4, F1, F2, F3, F4 }`. | Diagnose cleanup; production must not perform follow-up deletion from it. | Check every member; prove `A0`/`AF` populated masks and `AlreadyClean=TRUE`; reject any state outside the closed table. |
| `InitialInitializationMask` | Incoming owner mask captured before classification for every non-null owner. | Diagnostic only. | Check zero for null owner, incoming mask for early rejection, and `P0` for accepted runs. |
| `HighestPartialInitializationMask` | Highest published pre-ready prefix before recovery; excludes tentative `OWNER_READY` and later `FAULTED`. | Diagnostic/evidence only. | Check `P0`-`P4` progression and prove rollback does not rewrite it. |
| `FinalInitializationMask` | Actual owner mask immediately before return. | Diagnose final state; never infer cleanup from `Result` alone. | Check actual incoming early masks, `FAULT`, `READY`, finite J0/A0/AF injected masks, and F1-F4 exact `FAULT`. |
| `CreationHelperCalled` | Becomes `TRUE` after the spinlock helper returns and remains true for every later stage. | Diagnostic only. | Check `FALSE` on early rejection and `TRUE` for categories 9-22 after invocation. |
| `ReadyPublicationAttempted` | Becomes `TRUE` only at `S(PUBLISH_READY)` and rollback never clears it. | Diagnostic/semantic cross-check; distinct from structural success. | Enforce the ready-field truth table and profile `R20`. |
| `ReadyPublished` | Becomes `TRUE` only for already-ready classification or completed ready validation; failure handling clears it. | Required with `ObjectGraphComplete` before lifecycle initialization. | Check independently from attempt, mask, graph completion, and `Result`. |
| `RollbackAttempted` | Becomes `TRUE` immediately before the one rollback-helper call. | Diagnostic only; production never retries. | Check object-published failures only and one-call behavior. |
| `RollbackSucceeded` | Becomes `TRUE` only after `R(OK)` rollback. | Diagnostic only. | Check successful rollback versus category 19/20 false values. |
| `ObjectGraphComplete` | Becomes `TRUE` only for already-ready classification or successful final-ready validation. | Required with `ReadyPublished` before lifecycle initialization. | Check success/already-ready true and every failure false. |

Every field is sourced from the existing report assignments. Production
consumes only the fields identified above; the remaining fields are retained
for diagnostics and evidence and cannot independently authorize lifecycle or
success.

1. Exact insertion point: after explicit pre-object validation and before
   `ChatpadFilterLifecycleInitialize`.
2. Exact call order: scalar context setup, ordinary owner initialization,
   explicit pre-object validation, zero-initialized local report, one
   orchestration call, result/report classification, structural success
   requirement, lifecycle initialization, existing remaining setup.
3. Report initialization and lifetime: caller zero-initializes exactly one
   local report with `{ 0 }`; the orchestrator clears it again internally; it
   is synchronous, contains no handles, is read only after return, is not
   retained, and cannot escape `EvtDeviceAdd`.
4. Function return and report `Result`: production classifies from the
   function return and cross-checks the exact report `Result`; valid report
   paths require equality. A mismatch is a hard invariant failure mapped to
   `STATUS_INVALID_DEVICE_STATE`, preserves the report, invokes no direct
   rollback, and cannot reach lifecycle initialization.
5. Status mapping: preserve a failing framework `NTSTATUS` only for a
   creation-stage failure; map null arguments to `STATUS_INVALID_PARAMETER`;
   map baseline, repeated/partial state, local validation, rollback failure,
   invariant failure, and unknown results to `STATUS_INVALID_DEVICE_STATE`;
   never return success or run lifecycle after a non-success result.
6. Report masks: early rejection retains the incoming non-null-owner mask.
   Valid already-ready classification requires exact `READY` and the complete
   ready invariants. An `OWNER_READY`-bearing state that fails those invariants
   returns `O(INVALID_BASELINE)` and preserves its actual incoming mask in
   initial, highest, and final fields; it is never normalized to `READY`.
   After an accepted clean baseline, `HighestPartialInitializationMask` is the
   greatest published pre-ready prefix observed before recovery and excludes
   tentative `OWNER_READY` and later `FAULTED`; `FinalInitializationMask` is
   the actual non-null-owner mask at return and may contain `FAULTED` or
   `OWNER_READY`.
7. Ready-publication fields: exact `ReadyPublicationAttempted` becomes `TRUE`
   only when the `PUBLISH_READY` stage executes and remains `TRUE` if final
   ready validation later fails. It is distinct from `ReadyPublished`, final
   mask `OWNER_READY`, `ObjectGraphComplete`, and report `Result`.
8. Early report behavior: a non-null report is cleared first; null owner leaves
   zero masks, while every non-null owner seeds initial/highest/final masks;
   early rejection preserves the incoming owner and performs no rollback.
9. Stage report behavior: preserve the original `FailedStage`, latest helper
   and validator results, framework status, highest pre-ready prefix, and ready
   flags; common failure chooses no-object faulting or one rollback attempt
   from actual publication state.
10. Rollback report behavior: rollback changes `LastStageEntered`, report
    `Result`,
   rollback fields/effects, completion state, and final mask as source
   dictates, but does not erase original failure fields or framework status.
11. Clean baseline: no sequence-advance eligibility is part of the required
   `SequenceAdvanceEligible == 0u` pre-object baseline.
12. Early rejection: null-parent and invalid-baseline rejections return before
    common fault handling; they do not receive the post-baseline no-object
    fault transition.
13. Post-baseline no-object stage failure: after baseline acceptance and staged
    creation entry, a no-publication spinlock-stage failure reaches common
    failure handling, does not roll back, and faults through the existing
    no-object helper.
14. Partial-state validation failure: represented through the actual failed
    stage result plus `FailedStage` and `ValidationResult`, not a dedicated
    orchestration enum; rollback is selected only when an object was published.
15. Partial rollback: orchestrator invokes centralized rollback exactly once;
    production `device.c` does not delete objects.
16. Rollback model: ordinary sequential R1-R20 rollback permits only `R(OK)`
    and `S1`-`S4`. The finite offline injection model is closed by the complete
    16-result table and J0/A0/AF/F1-F4 states; `R(ALREADY_CLEAN)` has populated
    masks and `AlreadyClean=TRUE`; invalid-mask and owner-ready rejections begin
    no deletion. No other mutation premise is admitted.
17. R1-R20 completeness: every named source failure site maps one-to-one to an
    independently complete 27-group origin record; R1-R19 bind ready-attempt
    false and R20 true; each record expands its sole ordinary S1-S4 outcome and
    every permitted finite J0/A0/AF/F1-F4 injected outcome without a cross-row
    lookup.
18. Rollback failure: dedicated rollback-failure result, original failure
    preserved in the report, no retry, no direct best-effort deletion, fail
    `EvtDeviceAdd` with the stable local failure mapping. No orchestration or
    rollback failure may reach lifecycle initialization.
19. Later failure subcase 22A: lifecycle initializer is called and fails;
    device-created transition is not called; return its mapped failure without
    pre-ready rollback or manual owner clearing.
20. Later failure subcase 22B: lifecycle initializes successfully;
    device-created transition is called and fails; return its mapped failure
    without pre-ready rollback or manual owner clearing.
21. Later `EvtDeviceAdd` failure cleanup: after structural readiness, rely on
    framework deletion of the failed device object and parented children.
22. WDF parentage: spinlock and request parented to `WDFDEVICE`; outbound and
    inbound memory parented to the request.
23. Callback visibility: no new observer beyond the initialization call.
24. Concurrency assumptions: sequential publication is sufficient only while
    there is no observer, target, admitted operation, completion, cancellation,
    external call, or cleanup race.
25. IRQL assumptions: selected call runs at PASSIVE_LEVEL in `EvtDeviceAdd`;
    individual creation/deletion APIs are valid through DISPATCH_LEVEL.
26. Future implementation file scope: expected `device.c` only.
27. Binary retention: helper and WDF object-management retention is expected
    and legitimate in the future implementation slice.
28. LTCG audit limitation: retention evidence combines source, object, COMDAT,
    linker/LTCG, WDF function-table, and final-image inspection; no
    named-symbol check is sufficient alone and LTCG need not be disabled.
29. Mask evidence: the manifest explicitly binds
    `HighestPartialInitializationMask` progression and rollback stability plus
    `FinalInitializationMask` final-state behavior, with exact commands,
    results, and SHA-256 values.
30. Origin evidence: the manifest requires one-to-one R1-R20 entries with
    source site, all report/effect/mask/status fields, command, configuration,
    result, assertion count when applicable, relative path, and SHA-256.
31. Evidence format: tracked JSON manifest plus ignored logs under
    `artifacts\logs`.
32. Next gate: independent read-only audit of this finalized defensive
    taxonomy and report-contract design. Production implementation remains
    unauthorized until that audit passes.

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
