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

1. `OK` continues; it does not itself become the final `EvtDeviceAdd` status.
2. Null production input, `NULL_OWNER`, `NULL_PARENT_DEVICE`, or `NULL_REPORT`
   returns `STATUS_INVALID_PARAMETER`.
3. A creation-stage result (`SPINLOCK_FAILED`, `REQUEST_FAILED`,
   `OUTBOUND_MEMORY_FAILED`, or `INBOUND_MEMORY_FAILED`) returns
   `report.FrameworkStatus` only when `NT_SUCCESS(report.FrameworkStatus)` is
   false.
4. Every local creation/validation failure for which `FrameworkStatus` is the
   local sentinel or `STATUS_SUCCESS` returns `STATUS_INVALID_DEVICE_STATE`.
5. `ROLLBACK_FAILED` always returns `STATUS_INVALID_DEVICE_STATE`; the
   original stage, helper/validation result, framework status, rollback result,
   effects, and masks remain diagnostic report evidence.
6. Any unrecognized result returns `STATUS_INVALID_DEVICE_STATE`.

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

The tables below use the authoritative field name `LastCompletedStage`. Mask
abbreviations are exact symbolic combinations:

- `P0 = MODEL_READY`;
- `P1 = P0 | LOCK_CREATED`;
- `P2 = P1 | REQUEST_CREATED`;
- `P3 = P2 | OUTBOUND_MEMORY_CREATED`;
- `P4 = P3 | INBOUND_MEMORY_CREATED`;
- `READY = P4 | OWNER_READY`;
- `FAULT = MODEL_READY | FAULTED`.

After `RtlZeroMemory`, zero-valued report defaults are `LastCompletedStage =
NONE`, `FailedStage = NONE`, `BaselineValidationResult = STORAGE_OK`,
`CreationResult = CREATION_OK`, `ValidationResult = CREATION_OK`,
`RollbackResult = ROLLBACK_OK`, zero masks, zero effects, and zero flags. The
orchestrator then sets `Result = INVARIANT_FAILED`, `FrameworkStatus =
STATUS_INVALID_DEVICE_STATE`, and `LastStageEntered = VALIDATE_BASELINE`.
“Zero effects” below means every member of `RollbackEffects` remains zero.
For every non-null owner, `InitialInitializationMask`,
`HighestPartialInitializationMask`, and `FinalInitializationMask` are first
set to the incoming mask. `CreationHelperCalled` becomes `1` after the
spinlock helper returns and remains `1` for every later stage. A successful
baseline records `BaselineValidationResult=STORAGE_OK`; later stages do not
change that field.

### Early rejection matrix

| Category | Baseline accepted / object published / common path | Returned result | Stages (`LastStageEntered`; `LastCompletedStage`; `FailedStage`) | Helper / validators / `FrameworkStatus` | `HighestPartialInitializationMask`; `FinalInitializationMask` | Ready flags | Rollback attempted / result / effects | Final owner state | Production status / lifecycle / `EvtDeviceAdd` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Null production integration input before invocation | No call; none; no. | Not applicable. | Not applicable. | Not applicable. | Not applicable; not applicable. | Not applicable. | No report and no rollback. | No orchestrator-owned transition. | `STATUS_INVALID_PARAMETER`; lifecycle no; return that failure. |
| Null report pointer | No baseline; none; no. | `NULL_REPORT`. | No writable report; no fields are available. | No helper or validator; no report status. | No report; no report. | No report. | No report and no rollback. | Owner is not inspected or changed. | `STATUS_INVALID_PARAMETER`; lifecycle no; return that failure. |
| Null parent device | Yes; none; no. | `NULL_PARENT_DEVICE`. | `VALIDATE_BASELINE`; `NONE`; `VALIDATE_BASELINE`. | No helper; baseline `STORAGE_OK`; `ValidationResult=CREATION_OK`; sentinel `STATUS_INVALID_DEVICE_STATE`. | `P0`; `P0`. | Attempted `0`; published `0`; complete `0`. | Attempted `0`; default `ROLLBACK_OK`; zero effects. | Clean `P0`; no automatic fault transition. | `STATUS_INVALID_PARAMETER`; lifecycle no; return that failure. |
| Null owner | No; none; no. | `NULL_OWNER`. | `VALIDATE_BASELINE`; `NONE`; `VALIDATE_BASELINE`. | No helper; baseline field remains default `STORAGE_OK` because validation cannot run; `ValidationResult=CREATION_OK`; sentinel status. | `0`; `0`. | All zero. | Attempted `0`; default `ROLLBACK_OK`; zero effects. | Not applicable; no owner exists. | `STATUS_INVALID_PARAMETER`; lifecycle no; return that failure. |
| Invalid clean baseline, signature, or version | No; no new object; no. | `INVALID_SIGNATURE`, `UNSUPPORTED_VERSION`, or `INVALID_BASELINE`. | `VALIDATE_BASELINE`; `NONE`; `VALIDATE_BASELINE`. | No helper; `BaselineValidationResult` is the actual storage failure when the pre-object validator ran, otherwise its zero default; `ValidationResult=CREATION_OK`; sentinel status. | Incoming owner mask; same incoming mask. | All zero. | Attempted `0`; default `ROLLBACK_OK`; zero effects. | Incoming invalid state unchanged; no repair or fault publication. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return that failure. |
| Already ready | No clean baseline; pre-existing full graph; no. | `ALREADY_READY` when fully-ready validation passes, otherwise `INVALID_BASELINE`. | `VALIDATE_BASELINE`; `NONE`; `VALIDATE_BASELINE`. | No helper; baseline field default; `ValidationResult` is the fully-ready validator result; sentinel status. | Incoming `READY`; incoming `READY`. | Attempted `0`; published `1` and complete `1` only for `ALREADY_READY`. | Attempted `0`; default `ROLLBACK_OK`; zero effects. | Existing ready owner unchanged. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return that failure. |
| Already faulted | No clean baseline; none in the accepted rolled-back-fault form; no. | `ALREADY_FAULTED` when rollback classification proves `FAULT`, otherwise `INVALID_BASELINE`. | `VALIDATE_BASELINE`; `NONE`; `VALIDATE_BASELINE`. | No helper; validation fields default; sentinel status. | Incoming `FAULT` or invalid incoming mask; same mask. | All zero. | Attempted `0`; report result remains default `ROLLBACK_OK`; zero effects; classification is not an orchestrator rollback attempt. | Existing state unchanged. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return that failure. |
| Existing partial state | No clean baseline; existing prefix handles/bits may exist; no. | `PARTIAL_STATE_PRESENT` when rollback classification recognizes a non-clean prefix, otherwise `INVALID_BASELINE`. | `VALIDATE_BASELINE`; `NONE`; `VALIDATE_BASELINE`. | No creation helper; validation fields default; sentinel status. | Incoming partial mask; same incoming mask. | All zero. | Attempted `0`; report result default `ROLLBACK_OK`; zero effects; classification only. | Existing state unchanged; ownership is not guessed. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return that failure. |

### Creation and validation failure matrix

| Category | Baseline accepted / object published / common path | Returned result after successful recovery | Stages (`LastStageEntered`; `LastCompletedStage`; `FailedStage`) | Helper / validators / `FrameworkStatus` | `HighestPartialInitializationMask`; `FinalInitializationMask` | Ready flags | Rollback attempted / result / effects | Final owner / fault marking | Production status / lifecycle / `EvtDeviceAdd` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Spinlock framework/local failure before publication | Yes; none; yes. | `SPINLOCK_FAILED`; `INVARIANT_FAILED` only if no-object fault marking or final classification fails. | `CREATE_SPINLOCK`; `VALIDATE_BASELINE`; `CREATE_SPINLOCK`. | `CreationResult` is exact helper failure; `ValidationResult` retains prior/default `CREATION_OK`; `FrameworkStatus` is exact failing WDF status when WDF failed, otherwise sentinel or `STATUS_SUCCESS` for a local anomaly. | `P0`; `FAULT` when no-object marking succeeds, otherwise actual unchanged/invalid mask. | All zero. | No rollback attempt; default `ROLLBACK_OK`; zero effects. | No-object helper publishes `FAULT`; no rollback. | Exact failing framework status, else `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Spinlock post-success validation failure | Yes; lock; yes. | `SPINLOCK_FAILED`. | `ROLLBACK`; `ROLLBACK`; `CREATE_SPINLOCK`. | Internal helper validation: `CreationResult=POST_CREATION_INVARIANT_FAILED`, report `ValidationResult` remains prior/default; outer validation: `CreationResult=CREATION_OK`, report `ValidationResult` is exact failure. `FrameworkStatus=STATUS_SUCCESS`. | `P1`; `FAULT`. | All zero. | Attempted `1`; `ROLLBACK_OK`; succeeded `1`; spinlock deletion initiated `1`; request hierarchy and memory representation `0`; `AlreadyClean=0`; prior `P1`, resulting `FAULT`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Request framework/local failure | Yes; lock only; yes. | `REQUEST_FAILED`. | `ROLLBACK`; `ROLLBACK`; `CREATE_REQUEST`. | Exact request helper failure; `ValidationResult` retains successful spinlock validation; exact failing WDF status when present, otherwise sentinel. | `P1`; `FAULT`. | All zero. | Attempted `1`; `ROLLBACK_OK`; succeeded `1`; spinlock deletion `1`; request hierarchy `0`; memory representation `0`; prior `P1`, resulting `FAULT`. | Rollback publishes `FAULT`. | Exact failing framework status, else `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Request post-success validation failure | Yes; lock and request; yes. | `REQUEST_FAILED`. | `ROLLBACK`; `ROLLBACK`; `CREATE_REQUEST`. | Internal helper failure or `CreationResult=CREATION_OK` plus exact outer `ValidationResult`; `FrameworkStatus=STATUS_SUCCESS`. | `P2`; `FAULT`. | All zero. | Attempted `1`; `ROLLBACK_OK`; succeeded `1`; request hierarchy and spinlock deletion `1`; memory representation `0`; prior `P2`, resulting `FAULT`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Outbound-memory framework/local failure | Yes; lock and request; yes. | `OUTBOUND_MEMORY_FAILED`. | `ROLLBACK`; `ROLLBACK`; `CREATE_OUTBOUND_MEMORY`. | Exact outbound helper failure; `ValidationResult` retains successful request-stage validation; exact failing WDF status when present, otherwise sentinel. | `P2`; `FAULT`. | All zero. | Attempted `1`; `ROLLBACK_OK`; succeeded `1`; request hierarchy and spinlock deletion `1`; outbound/inbound representation `0`; prior `P2`, resulting `FAULT`. | Rollback publishes `FAULT`. | Exact failing framework status, else `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Outbound-memory post-success validation failure | Yes; lock, request, outbound memory; yes. | `OUTBOUND_MEMORY_FAILED`. | `ROLLBACK`; `ROLLBACK`; `CREATE_OUTBOUND_MEMORY`. | Internal helper failure or `CreationResult=CREATION_OK` plus exact outer `ValidationResult`; `FrameworkStatus=STATUS_SUCCESS`. | `P3`; `FAULT`. | All zero. | Attempted `1`; `ROLLBACK_OK`; succeeded `1`; request hierarchy and spinlock deletion `1`; outbound represented `1`, inbound `0`; prior `P3`, resulting `FAULT`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Inbound-memory framework/local failure | Yes; lock, request, outbound memory; yes. | `INBOUND_MEMORY_FAILED`. | `ROLLBACK`; `ROLLBACK`; `CREATE_INBOUND_MEMORY`. | Exact inbound helper failure; `ValidationResult` retains successful outbound-stage validation; exact failing WDF status when present, otherwise sentinel. | `P3`; `FAULT`. | All zero. | Attempted `1`; `ROLLBACK_OK`; succeeded `1`; request hierarchy and spinlock deletion `1`; outbound represented `1`, inbound `0`; prior `P3`, resulting `FAULT`. | Rollback publishes `FAULT`. | Exact failing framework status, else `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Inbound-memory post-success validation failure | Yes; full pre-ready graph; yes. | `INBOUND_MEMORY_FAILED`. | `ROLLBACK`; `ROLLBACK`; `CREATE_INBOUND_MEMORY`. | Internal helper failure or `CreationResult=CREATION_OK` plus exact outer `ValidationResult`; `FrameworkStatus=STATUS_SUCCESS`. | `P4`; `FAULT`. | All zero. | Attempted `1`; `ROLLBACK_OK`; succeeded `1`; request hierarchy and spinlock deletion `1`; outbound/inbound represented `1`; prior `P4`, resulting `FAULT`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Complete pre-ready validation failure | Yes; full pre-ready graph; yes. | `PRE_READY_VALIDATION_FAILED`. | `ROLLBACK`; `ROLLBACK`; `VALIDATE_PRE_READY`. | Last helper result remains inbound `CREATION_OK`; `ValidationResult` is exact pre-ready failure; `FrameworkStatus=STATUS_SUCCESS`. | `P4`; `FAULT`. | All zero. | Attempted `1`; `ROLLBACK_OK`; succeeded `1`; request hierarchy and spinlock deletion `1`; both memories represented; prior `P4`, resulting `FAULT`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Final-ready validation failure | Yes; full graph; yes. | `READY_VALIDATION_FAILED`. | `ROLLBACK`; `ROLLBACK`; `VALIDATE_READY`. | Last helper result remains inbound `CREATION_OK`; `ValidationResult` is exact final-ready failure; `FrameworkStatus=STATUS_SUCCESS`. | `P4`; `FAULT`. | Attempted `1`; published `0`; complete `0`; `OWNER_READY` is cleared before failure handling. | Attempted `1`; `ROLLBACK_OK`; succeeded `1`; request hierarchy and spinlock deletion `1`; both memories represented; prior `P4`, resulting `FAULT`. | Rollback publishes `FAULT`. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |

### Rollback, success, and later-failure matrix

| Category | Baseline accepted / object published / common path | Returned result | Stages / helper / validation fields | `FrameworkStatus`; masks | Ready flags | Rollback attempted / result / effects | Final owner state | Production status / lifecycle / `EvtDeviceAdd` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Rollback rejection before deletion | Yes; partial/full pre-ready graph; yes. | `ROLLBACK_FAILED`. | `LastStageEntered=ROLLBACK`; `LastCompletedStage` remains the last pre-failure completed stage; original `FailedStage`, `CreationResult`, and `ValidationResult` are preserved. | Original framework status; `HighestPartialInitializationMask` is the pre-rollback prefix excluding `OWNER_READY`; `FinalInitializationMask` is the unchanged rejected state after ready clearing. | Original attempt flag preserved; published `0`; complete `0`. | Attempted `1`; exact non-OK rollback result; succeeded `0`; effects remain zero because classification rejected before deletion. | Partial/full pre-ready state may remain; `OWNER_READY` absent. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Rollback failure after effects begin | Yes; partial/full pre-ready graph; yes. | `ROLLBACK_FAILED`. | `LastStageEntered=ROLLBACK`; rollback is not marked completed; original `FailedStage`, `CreationResult`, and `ValidationResult` are preserved. | Original framework status; highest mask remains the pre-rollback prefix excluding `OWNER_READY`; final mask is the actual variable post-effect state captured at return. | Original attempt flag preserved; published `0`; complete `0`. | Attempted `1`; exact non-OK result such as `POST_ROLLBACK_INVARIANT_FAILED`; succeeded `0`; effects preserve initiated deletions, represented memories, prior mask, and resulting mask. | Variable report-described failure state; do not invent a fixed mask or retry. | `STATUS_INVALID_DEVICE_STATE`; lifecycle no; return failure. |
| Success | Yes with `BaselineValidationResult=STORAGE_OK`; full graph; no failure path. | `OK`. | `LastStageEntered=VALIDATE_READY`; `LastCompletedStage=VALIDATE_READY`; `FailedStage=NONE`; `CreationResult=CREATION_OK`; `ValidationResult=CREATION_OK`. | `FrameworkStatus=STATUS_SUCCESS`; highest `P4`; final `READY`. | Attempted `1`; published `1`; complete `1`. | Attempted `0`; default `ROLLBACK_OK`; zero effects; succeeded `0`. | Structurally ready dormant owner, no target or operation. | Continue; lifecycle runs; final status comes from remaining existing `EvtDeviceAdd` work. |
| Later existing `EvtDeviceAdd` failure after orchestration success | Yes with `BaselineValidationResult=STORAGE_OK`; full graph; no orchestration failure path. | `OK`. | `LastStageEntered=VALIDATE_READY`; `LastCompletedStage=VALIDATE_READY`; `FailedStage=NONE`; `CreationResult=CREATION_OK`; `ValidationResult=CREATION_OK`. | `FrameworkStatus=STATUS_SUCCESS`; highest `P4`; final `READY`. | Attempted `1`; published `1`; complete `1`. | Attempted `0`; default `ROLLBACK_OK`; zero effects; succeeded `0`; no later orchestrator rollback. | Ready owner exists until failed-device destruction removes its context and parented children. | Return the later existing failure; lifecycle may have run; do not call pre-ready rollback. |

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
records `FAULT`; success records `READY`. Rollback rejection/failure records
the actual state at that return and can vary. Unlike the highest-partial mask,
the final mask may contain `FAULTED` or `OWNER_READY`.

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

Production must inspect `RollbackAttempted`, `RollbackResult`,
`RollbackSucceeded`, `RollbackEffects`, and `FinalInitializationMask`; it must
not infer cleanup completion from the top-level orchestration result alone.

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
   explicit pre-object validation, zero-initialized local report, one
   orchestration call, result/report classification, structural success
   requirement, lifecycle initialization, existing remaining setup.
3. Report initialization and lifetime: caller zero-initializes exactly one
   local report with `{ 0 }`; the orchestrator clears it again internally; it
   is synchronous, contains no handles, is read only after return, is not
   retained, and cannot escape `EvtDeviceAdd`.
4. Status mapping: preserve a failing framework `NTSTATUS` only for a
   creation-stage failure; map null arguments to `STATUS_INVALID_PARAMETER`;
   map baseline, repeated/partial state, local validation, rollback failure,
   invariant failure, and unknown results to `STATUS_INVALID_DEVICE_STATE`;
   never return success or run lifecycle after a non-success result.
5. Report masks: early rejection retains the incoming non-null-owner mask.
   After an accepted clean baseline, `HighestPartialInitializationMask` is the
   greatest published pre-ready prefix observed before recovery and excludes
   tentative `OWNER_READY` and later `FAULTED`; `FinalInitializationMask` is
   the actual non-null-owner mask at return and may contain `FAULTED` or
   `OWNER_READY`.
6. Early report behavior: a non-null report is cleared first; null owner leaves
   zero masks, while every non-null owner seeds initial/highest/final masks;
   early rejection preserves the incoming owner and performs no rollback.
7. Stage report behavior: preserve the original `FailedStage`, latest helper
   and validator results, framework status, highest pre-ready prefix, and ready
   flags; common failure chooses no-object faulting or one rollback attempt
   from actual publication state.
8. Rollback report behavior: rollback changes `LastStageEntered`, result,
   rollback fields/effects, completion state, and final mask as source
   dictates, but does not erase original failure fields or framework status.
9. Clean baseline: no sequence-advance eligibility is part of the required
   `SequenceAdvanceEligible == 0u` pre-object baseline.
10. Early rejection: null-parent and invalid-baseline rejections return before
    common fault handling; they do not receive the post-baseline no-object
    fault transition.
11. Post-baseline no-object stage failure: after baseline acceptance and staged
    creation entry, a no-publication spinlock-stage failure reaches common
    failure handling, does not roll back, and faults through the existing
    no-object helper.
12. Partial-state validation failure: represented through the actual failed
    stage result plus `FailedStage` and `ValidationResult`, not a dedicated
    orchestration enum; rollback is selected only when an object was published.
13. Partial rollback: orchestrator invokes centralized rollback exactly once;
    production `device.c` does not delete objects.
14. Rollback failure: dedicated rollback-failure result, original failure
    preserved in the report, no retry, no direct best-effort deletion, fail
    `EvtDeviceAdd` with the stable local failure mapping.
15. Later `EvtDeviceAdd` failure cleanup: after structural readiness, rely on
    framework deletion of the failed device object and parented children.
16. WDF parentage: spinlock and request parented to `WDFDEVICE`; outbound and
    inbound memory parented to the request.
17. Callback visibility: no new observer beyond the initialization call.
18. Concurrency assumptions: sequential publication is sufficient only while
    there is no observer, target, admitted operation, completion, cancellation,
    external call, or cleanup race.
19. IRQL assumptions: selected call runs at PASSIVE_LEVEL in `EvtDeviceAdd`;
    individual creation/deletion APIs are valid through DISPATCH_LEVEL.
20. Future implementation file scope: expected `device.c` only.
21. Binary retention: helper and WDF object-management retention is expected
    and legitimate in the future implementation slice.
22. LTCG audit limitation: retention evidence combines source, object, COMDAT,
    linker/LTCG, WDF function-table, and final-image inspection; no
    named-symbol check is sufficient alone and LTCG need not be disabled.
23. Evidence format: tracked JSON manifest plus ignored logs under
    `artifacts\logs`.
24. Next gate: independent read-only audit of this corrected report-aware
    design.

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
