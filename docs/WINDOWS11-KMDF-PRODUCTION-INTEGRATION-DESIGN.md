# Windows 11 KMDF Production Integration Design

This is the authoritative documentation-only design for introducing the
dormant KMDF activation request-owner object graph into the production
`ChatpadFilter` codebase through separately gated steps.

This document was created before production linkage. Its original baseline was
the pre-integration state where `ChatpadFilter` did not yet link the request
owner, include the authoritative owner header, embed owner storage, or call
ordinary owner initialization. That historical linkage-only checkpoint is
recorded in
[Offline KMDF Production Linkage Checkpoint](OFFLINE-KMDF-PRODUCTION-LINKAGE.md).
Production now also embeds and ordinarily initializes one request owner as
recorded in
[Offline KMDF Production Owner Initialization](OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md).
The later audit-corrections checkpoint clarified evidence and validation-count
wording in
[Offline KMDF Owner Initialization Audit Corrections](OFFLINE-KMDF-OWNER-INITIALIZATION-AUDIT-CORRECTIONS.md).
The production orchestration-invocation binding is now documented in
[Windows 11 KMDF Production Orchestration Invocation Design](WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md).

## 1. Purpose and non-scope

This design covers future production compile/link integration, device-context
placement, initialization sequencing, dormant orchestration invocation, failure
propagation, successful and failed `EvtDeviceAdd` cleanup, publication and
concurrency assumptions, implementation decomposition, and validation/evidence
retention.

This design does not itself authorize implementation. Separately completed
checkpoints implemented project linkage, owner embedding, ordinary storage
initialization, and one additional explicit pre-object validation. A later
documentation-only checkpoint now designs the future dormant orchestration
invocation, but source implementation, WDF object creation or deletion,
dormant orchestration execution, target discovery, request formatting or
submission, completion or cancellation, D0 rundown, signing, staging,
installation, loading, and hardware interaction remain unauthorized.

The dormant object graph remains one device-parented spinlock, one
device-parented targetless request, and two request-parented preallocated
memory objects over exact two-byte owner arrays. Structural readiness does not
admit an operation.

## 2. Current production reality

Current `ChatpadFilter` production code is a compile-validated KMDF
filter-capable lifecycle scaffold with one ordinarily initialized, still
dormant request owner:

- `src/driver/ChatpadFilter/driver.h` includes the authoritative
  `ChatpadKmdfRequestOwnerContext.h` and declares
  `CHATPAD_FILTER_DEVICE_CONTEXT` with `Signature`, `Version`,
  `DiagnosticSequence`, one
  `ChatpadKmdfActivationRequestOwner ActivationRequestOwner`, and
  `ChatpadFilterLifecycleState Lifecycle`.
- `driver.h` declares the device context accessor with
  `WDF_DECLARE_CONTEXT_TYPE_WITH_NAME(CHATPAD_FILTER_DEVICE_CONTEXT,
  ChatpadFilterGetDeviceContext)`.
- `DriverEntry` in `src/driver/ChatpadFilter/driver.c` initializes
  `WDF_DRIVER_CONFIG` with `ChatpadEvtDeviceAdd` and calls `WdfDriverCreate`.
- `ChatpadEvtDeviceAdd` in `src/driver/ChatpadFilter/device.c` marks the
  device as filter-capable, registers prepare/release/D0 callbacks, creates the
  `WDFDEVICE`, initializes scalar context fields, calls ordinary owner storage
  initialization once, performs one additional explicit pre-object validation,
  initializes the lifecycle core only after both steps succeed, marks the
  device created, logs the lifecycle snapshot, and returns the mapped status.
- Current callbacks are `ChatpadEvtDevicePrepareHardware`,
  `ChatpadEvtDeviceReleaseHardware`, `ChatpadEvtDeviceD0Entry`, and
  `ChatpadEvtDeviceD0Exit`. Each retrieves the current device context and
  delegates only to `ChatpadFilterLifecycle`.
- `ChatpadActivationPreparation` is currently compiled directly into
  `ChatpadFilter` and retained by `/INCLUDE:ChatpadPrepareActivationStep`, but
  no production callback calls it.
- `ChatpadFilter.vcxproj` references
  `ChatpadKmdfRequestOwnerContext.vcxproj` and compiles the portable
  `ChatpadRequestOwnerModel.c` as a WDK object. It does not compile the
  isolated KMDF context source directly into production.
- `ChatpadKmdfRequestOwnerInitializeStorage` performs its authoritative
  internal baseline validation. `EvtDeviceAdd` then calls
  `ChatpadKmdfRequestOwnerValidatePreObjectState` once more as a separate
  production integration-boundary invariant check.
- No production code calls dormant orchestration, creation, rollback,
  ready-publication, target, or request-execution helpers. No request-owner WDF
  object is created.
- The driver remains unsigned and not installable as a validated production
  package.

This section is current source and offline-artifact reality. It does not claim
driver loading or runtime execution. Later sections describe still-proposed
integration beyond the completed owner ordinary-initialization slice.

## 3. Current `EvtDeviceAdd` sequence

The current `ChatpadEvtDeviceAdd` implementation in
`src/driver/ChatpadFilter/device.c` has this exact order:

| Step | Source function | Operation | Created object or ordinary state | Failure return behavior | Device context exists | Callback can observe device | Hardware or target access |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `ChatpadEvtDeviceAdd` | Ignore the unused `WDFDRIVER` parameter. | None. | None. | No. | No. | No. |
| 2 | `ChatpadEvtDeviceAdd` | Emit `KdPrintEx` lifecycle scaffold message. | None. | None. | No. | No. | No. |
| 3 | `ChatpadEvtDeviceAdd` | Call `WdfFdoInitSetFilter(DeviceInit)`. | Marks the device init as filter-capable. | No local failure value. | No. | No. | No. |
| 4 | `ChatpadEvtDeviceAdd` | Initialize `WDF_PNPPOWER_EVENT_CALLBACKS`. | Ordinary stack callback structure. | None. | No. | No. | No. |
| 5 | `ChatpadEvtDeviceAdd` | Set `EvtDevicePrepareHardware`, `EvtDeviceReleaseHardware`, `EvtDeviceD0Entry`, and `EvtDeviceD0Exit`. | Callback pointers in the stack callback structure. | None. | No. | No. | No. |
| 6 | `ChatpadEvtDeviceAdd` | Call `WdfDeviceInitSetPnpPowerEventCallbacks(DeviceInit, &pnpPowerCallbacks)`. | Callback registration on `DeviceInit`. | No local failure value. | No. | No. | No. |
| 7 | `ChatpadEvtDeviceAdd` | Call `WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(&objectAttributes, CHATPAD_FILTER_DEVICE_CONTEXT)`. | Stack attributes selecting the current device context type. | None. | No. | No. | No. |
| 8 | `ChatpadEvtDeviceAdd` | Call `WdfDeviceCreate(&DeviceInit, &objectAttributes, &device)`. | Creates `WDFDEVICE` with current device context. | On failed `NTSTATUS`, logs and returns the exact `WdfDeviceCreate` status. | Yes only on success. | No current production callback is invoked before `EvtDeviceAdd` returns. | No. |
| 9 | `ChatpadEvtDeviceAdd` | Retrieve context with `ChatpadFilterGetDeviceContext(device)`. | Typed pointer to current context storage. | No local null check. | Yes. | No current observer before return. | No. |
| 10 | `ChatpadEvtDeviceAdd` | Write `Signature`, `Version`, and `DiagnosticSequence = 0`. | Ordinary context scalar state. | None. | Yes. | No current observer before return. | No. |
| 11 | `ChatpadEvtDeviceAdd` -> `ChatpadKmdfRequestOwnerInitializeStorage` | Initialize ordinary owner storage once; the initializer performs its internal validation. | Embedded owner reaches clean `MODEL_READY` pre-object state. | A non-OK typed result is mapped and returned immediately. | Yes. | No current observer before return. | No. |
| 12 | `ChatpadEvtDeviceAdd` -> `ChatpadKmdfRequestOwnerValidatePreObjectState` | Perform one additional explicit production integration-boundary invariant check. | Caller-owned validation record only. | Any non-OK result returns `STATUS_INVALID_DEVICE_STATE` immediately. | Yes. | No current observer before return. | No. |
| 13 | `ChatpadEvtDeviceAdd` -> `ChatpadFilterLifecycleInitialize` | Initialize lifecycle state only after both owner steps succeed. | Ordinary `Lifecycle` state. | Result is mapped later; no immediate return. | Yes. | No current observer before return. | No. |
| 14 | `ChatpadEvtDeviceAdd` -> `ChatpadFilterLifecycleMarkDeviceCreated` | If lifecycle initialization passed, mark lifecycle phase created. | Ordinary lifecycle phase. | Result is mapped later; no immediate return. | Yes. | No current observer before return. | No. |
| 15 | `ChatpadEvtDeviceAdd` -> `ChatpadLogLifecycle` | Retrieve context again, increment `DiagnosticSequence`, snapshot lifecycle, and log. | Diagnostic sequence and bounded snapshot. | Snapshot failure is converted to an unset diagnostic snapshot; no return failure. | Yes. | Still inside `EvtDeviceAdd`. | No. |
| 16 | `ChatpadEvtDeviceAdd` -> `ChatpadLifecycleResultToStatus` | Map lifecycle result to `NTSTATUS` and return. | None. | Returns `STATUS_SUCCESS`, `STATUS_INVALID_PARAMETER`, `STATUS_INTEGER_OVERFLOW`, `STATUS_DEVICE_BUSY`, or `STATUS_INVALID_DEVICE_STATE` by current mapping. | Yes if success path reached. | After success, registered PnP/power callbacks may later retrieve context. | No. |

Current code creates no queue, device interface, symbolic link, timer, work
item, target, USB object, request, memory object, completion callback, cancel
callback, cleanup callback, destroy callback, or unload callback in this path.

Every invoked helper and failure order is:

1. `WdfFdoInitSetFilter`: no local failure return.
2. `WdfDeviceInitSetPnpPowerEventCallbacks`: no local failure return.
3. `WdfDeviceCreate`: immediate return on failed framework `NTSTATUS`.
4. `ChatpadFilterGetDeviceContext`: no local failure branch.
5. `ChatpadKmdfRequestOwnerInitializeStorage`: immediate mapped return on a
   non-OK result; successful initialization includes internal validation.
6. `ChatpadKmdfRequestOwnerValidatePreObjectState`: one additional explicit
   boundary check; immediate `STATUS_INVALID_DEVICE_STATE` return on failure.
7. `ChatpadFilterLifecycleInitialize`: result captured only after both owner
   steps succeed.
8. `ChatpadFilterLifecycleMarkDeviceCreated`: called only if initialize
   returned `CHATPAD_FILTER_LIFECYCLE_OK`.
9. `ChatpadLogLifecycle`: called regardless of lifecycle result after device
   creation.
10. `ChatpadLifecycleResultToStatus`: final return mapping.

## 4. Production dependency graph

The current production dependency graph is:

```text
ChatpadFilter
  -> ChatpadKmdfRequestOwnerContext static library
       -> ChatpadKmdfRequestOwnerContext.h/.c
       -> ChatpadRequestOwnerModel static library or linked object source
       -> ChatpadActivationPreparation public types
       -> ChatpadWdfControlSetup public types
       -> ChatpadControlSetup public types
       -> ChatpadProtocol public types
       -> ChatpadTransport public token types
  -> ChatpadFilterLifecycle
```

Completed production mechanics:

- `ChatpadFilter.vcxproj` has a native `ProjectReference` to
  `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.vcxproj`.
- `ChatpadFilter.vcxproj` compiles the portable
  `ChatpadRequestOwnerModel.c` source directly as a WDK object because the
  user-mode model library carries user-mode default-library metadata.
- `ChatpadFilter.vcxproj` includes
  `$(RepoRoot)\src\driver\ChatpadKmdfRequestOwnerContext`,
  `$(RepoRoot)\src\transport\ChatpadRequestOwnerModel`, and
  `$(RepoRoot)\src\transport\ChatpadTransport` for the current production
  owner integration.
- Keep Debug/Release x64 configuration compatibility with the current
  `WindowsKernelModeDriver10.0` KMDF toolset and `SignMode=Off`.
- Let native project references define build ordering.
- Do not add `/INCLUDE` for request-owner symbols once a real production call
  exists. A real call from `ChatpadFilter` is sufficient to retain the needed
  library member. `/INCLUDE` is only a dormant-retention mechanism and would
  obscure proof of actual production reachability.

Historical plan recorded before production owner integration: the first
implementation slice was linkage-only. That slice was completed and audited
before owner embedding and ordinary initialization. Linker extraction behavior
for the current checkpoint is now interpreted through source, object, COMDAT,
linker-option, final-image, and manifest evidence.

## 5. Header and ownership boundaries

`ChatpadKmdfActivationRequestOwner` is declared only in
`src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.h`.
`ChatpadFilter` must not duplicate this type.

Selected production header strategy:

- `src/driver/ChatpadFilter/driver.h` includes
  `ChatpadKmdfRequestOwnerContext.h` only in the slice that embeds the owner in
  `CHATPAD_FILTER_DEVICE_CONTEXT`.
- The owner is embedded directly in `CHATPAD_FILTER_DEVICE_CONTEXT`; therefore
  a forward declaration is insufficient because the complete size is required.
- Circular include risk is acceptable only if the current direction remains:
  `driver.h` -> `ChatpadKmdfRequestOwnerContext.h` ->
  `ChatpadActivationPreparation.h`; `ChatpadActivationPreparation.h` does not
  include `driver.h`.
- Internal helper definitions, private validation helpers, masks, and
  orchestration internals remain private to
  `ChatpadKmdfRequestOwnerContext.c`.
- Portable modules remain WDF-free. `ChatpadRequestOwnerModel` and
  `ChatpadTransport` do not include WDF/WDM headers merely because
  `ChatpadFilter` includes the KMDF context header.

Any circular include, duplicate owner type, or leak of WDF-only definitions
into portable model headers is a stop condition.

## 6. Device-context placement

Current production context field:

```c
ChatpadKmdfActivationRequestOwner ActivationRequestOwner;
```

The field is embedded directly in `CHATPAD_FILTER_DEVICE_CONTEXT` with the
other per-device state:

```c
typedef struct _CHATPAD_FILTER_DEVICE_CONTEXT {
    ULONG Signature;
    ULONG Version;
    ULONG DiagnosticSequence;
    ChatpadFilterLifecycleState Lifecycle;
    ChatpadKmdfActivationRequestOwner ActivationRequestOwner;
} CHATPAD_FILTER_DEVICE_CONTEXT, *PCHATPAD_FILTER_DEVICE_CONTEXT;
```

Binding rules:

- Exactly one embedded owner per `WDFDEVICE`.
- No global owner.
- No heap allocation for the owner.
- No pointer to shorter-lived storage.
- Device-context lifetime exceeds every device-parented and request-parented
  child object in the dormant graph.
- The fixed outbound and inbound backing arrays remain valid for the device
  context lifetime.

Embedding is preferred because it gives deterministic per-device identity,
prevents allocation failure and ownership ambiguity for ordinary storage, keeps
the fixed arrays at device lifetime, and lets the WDF child graph be parented
to the same `WDFDEVICE`.

## 7. Exact ordinary initialization location

The completed ordinary owner-storage initializer is called in
`ChatpadEvtDeviceAdd` after these current statements:

```c
context = ChatpadFilterGetDeviceContext(device);
context->Signature = CHATPAD_FILTER_DEVICE_CONTEXT_SIGNATURE;
context->Version = CHATPAD_FILTER_DEVICE_CONTEXT_VERSION;
context->DiagnosticSequence = 0u;
```

and before:

```c
lifecycleResult = ChatpadFilterLifecycleInitialize(&context->Lifecycle);
```

Locations rejected:

- Before `WdfDeviceCreate`: the embedded owner storage does not exist.
- After queue creation: no queue exists today, and waiting that long would
  create a wider observable window in a future queue-bearing driver.
- Prepare-hardware: repeats on hardware resource transitions and is later than
  needed.
- D0 entry: repeats across power cycles and mixes device-lifetime storage with
  D0 generation state.
- Lazy activation initialization: creates first-use races and cannot fail
  `EvtDeviceAdd` deterministically.

The selected location ensures owner storage exists, no current callback can
observe uninitialized owner state, no target or hardware is required,
initialization occurs once per device instance, initialization failure can fail
`EvtDeviceAdd`, and no D0-cycle reconstruction occurs.

The initializer validates the newly initialized storage internally, after which
`EvtDeviceAdd` performs one additional explicit pre-object
integration-boundary validation.

## 8. Exact dormant orchestration location

`ChatpadKmdfRequestOwnerCreateDormantObjectGraph` shall eventually be called
immediately after successful ordinary owner-storage initialization and
pre-object validation, still before the current lifecycle initialization call.

Exact future insertion point:

```c
context->DiagnosticSequence = 0u;

ownerStorageResult =
    ChatpadKmdfRequestOwnerInitializeStorage(&context->ActivationRequestOwner);
if (ownerStorageResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
    return ChatpadKmdfStorageResultToStatus(ownerStorageResult);
}

ownerValidationResult = ChatpadKmdfRequestOwnerValidatePreObjectState(
    &context->ActivationRequestOwner,
    &ownerStorageValidation);
if (ownerValidationResult != CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK) {
    return STATUS_INVALID_DEVICE_STATE;
}

orchestrationResult = ChatpadKmdfRequestOwnerCreateDormantObjectGraph(
    device,
    &context->ActivationRequestOwner,
    &orchestrationReport);
if (orchestrationResult != CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_OK) {
    return ChatpadKmdfOrchestrationResultToStatus(
        orchestrationResult,
        &orchestrationReport);
}

lifecycleResult = ChatpadFilterLifecycleInitialize(&context->Lifecycle);
```

Existing initialization that must precede orchestration:

- `WdfDeviceCreate` succeeded.
- `ChatpadFilterGetDeviceContext(device)` returned the production context.
- `Signature`, `Version`, and `DiagnosticSequence` were set.
- Ordinary activation owner storage was initialized and internally validated by
  the initializer; `EvtDeviceAdd` then performed one additional explicit
  pre-object integration-boundary validation to prove a clean `MODEL_READY`
  baseline.

Current operations that follow orchestration:

- `ChatpadFilterLifecycleInitialize`.
- `ChatpadFilterLifecycleMarkDeviceCreated` if lifecycle initialize succeeds.
- `ChatpadLogLifecycle`.
- Return mapped lifecycle status.

No concurrent observer exists at that point in the current code. The registered
callbacks are reachable only after the framework completes device-add
processing. The dormant graph requires no target or hardware and is created
only once per device instance.

## 9. Production integration call sequence

The current completed call sequence is:

1. Retrieve the device context with `ChatpadFilterGetDeviceContext(device)`.
2. Initialize current context scalar fields.
3. Initialize ordinary owner storage with
   `ChatpadKmdfRequestOwnerInitializeStorage`.
4. Rely on the initializer's internal validation of the newly initialized
   storage.
5. Perform one additional explicit pre-object integration-boundary validation
   with `ChatpadKmdfRequestOwnerValidatePreObjectState`.
6. Continue existing lifecycle setup only after both owner steps succeed.
7. Return success only after all existing required `EvtDeviceAdd` steps
   complete.

The remaining future orchestration sequence begins after step 5 and before
lifecycle initialization: invoke
`ChatpadKmdfRequestOwnerCreateDormantObjectGraph`, require structural
`OWNER_READY` through the orchestration success result and final ready
validation report, then continue existing lifecycle setup.

Status behavior:

- Failed `WdfDeviceCreate`: return the exact framework `NTSTATUS`.
- Null or invalid context state: return a stable local failure status, normally
  `STATUS_INVALID_DEVICE_STATE`.
- Ordinary storage failure: return a stable local status mapped from
  `ChatpadKmdfRequestOwnerStorageResult`.
- Framework creation failure inside orchestration: return the exact
  `FrameworkStatus` when it is a failed `NTSTATUS`.
- Local orchestration validation failure: return `STATUS_INVALID_DEVICE_STATE`.
- Rollback failure: return `STATUS_INVALID_DEVICE_STATE` and retain the
  rollback-failure report; do not return success and do not hide the rollback
  failure.
- Existing lifecycle failure after owner readiness: return the current
  `ChatpadLifecycleResultToStatus` mapping.

No retry is introduced.

## 10. Status mapping and diagnostics

Production integration shall map:

| Source result | Returned `NTSTATUS` principle |
| --- | --- |
| Ordinary initialization result | `STATUS_SUCCESS` for OK; `STATUS_INVALID_PARAMETER` for impossible null integration inputs; `STATUS_INVALID_DEVICE_STATE` for invariant or repeated-initialization failures. |
| Pre-object validation result | `STATUS_SUCCESS` for OK; `STATUS_INVALID_DEVICE_STATE` for any non-OK state. |
| Orchestration result | `STATUS_SUCCESS` for OK; `STATUS_INVALID_PARAMETER` for null production/orchestrator arguments; exact failed `FrameworkStatus` for WDF create failures; `STATUS_INVALID_DEVICE_STATE` for local baseline, already-ready, already-faulted, pre-existing partial-state, validation, rollback-failure, or invariant failures. |
| Underlying framework `NTSTATUS` | Preserve the exact failed status when it caused the failing creation result. |
| Rollback result | Rollback success does not convert a creation failure into success. Rollback failure maps to the stable local failure status and records the original failed stage/status plus rollback result separately. |
| Final ready validation result | Non-OK returns `STATUS_INVALID_DEVICE_STATE`. |
| Existing lifecycle result | Preserve current `ChatpadLifecycleResultToStatus` mapping. |

Diagnostics are limited to bounded result enums, stage names, `NTSTATUS`
values, and counters. They must not expose WDF handles, raw pointers, protocol
payload dumps, device instance paths, private machine data, or key contents.

No new runtime tracing is required for the first production slices unless the
existing repository logging convention is deliberately extended in a later
implementation task.

## 11. Failure matrix before object creation

| Case | Object exists | Rollback called | Resulting owner state | Returned status | `EvtDeviceAdd` fails | Framework device deletion relied upon |
| --- | --- | --- | --- | --- | --- | --- |
| Null or unavailable device context | No request-owner graph. | No. | No valid owner publication. | `STATUS_INVALID_DEVICE_STATE` or `STATUS_INVALID_PARAMETER` by exact cause. | Yes. | No child graph exists. |
| Owner initialization failure | No framework object. | No. | `FAULTED` if initializer marked it; otherwise not ready. | Local mapped failure. | Yes. | Only the `WDFDEVICE` may exist. |
| Pre-object validation failure | No framework object. | No. | Not ready; may be faulted by initializer. | `STATUS_INVALID_DEVICE_STATE`. | Yes. | Only the `WDFDEVICE` may exist. |
| Already-ready state unexpectedly encountered | Ready graph should not exist before first orchestration. | No. | Unchanged; rejected. | `STATUS_INVALID_DEVICE_STATE`. | Yes. | Stop condition; do not proceed. |
| Faulted state unexpectedly encountered | No valid new object creation. | No. | Faulted owner remains faulted. | `STATUS_INVALID_DEVICE_STATE`. | Yes. | Only already-owned device cleanup may occur. |
| Partial state unexpectedly encountered | Some handle/bit may be represented but not owned by this integration path. | No. | Unchanged; rejected. | `STATUS_INVALID_DEVICE_STATE`. | Yes. | Stop condition; do not guess ownership. |
| Invalid model state | No new object creation. | No. | Unchanged or faulted by initializer. | `STATUS_INVALID_DEVICE_STATE`. | Yes. | Only the `WDFDEVICE` may exist. |

Rollback is not called before object creation because there is no framework
object graph to delete and no ownership proof for unexpected partial states.

## 12. Failure matrix during orchestration

| Case | Highest object state reached | Original status | Rollback behavior | Final owner state | Returned `EvtDeviceAdd` status | Stop condition |
| --- | --- | --- | --- | --- | --- | --- |
| Spinlock creation failure | No created bit or handle. | Exact WDF status if available. | No object rollback; mark no-object fault. | `MODEL_READY | FAULTED` if invariant path succeeds. | Exact WDF failure or local invariant failure. | Cannot mark faulted baseline. |
| Request creation failure | Lock created. | Exact WDF status if available. | Delete spinlock through partial rollback. | `MODEL_READY | FAULTED`, handles null. | Exact WDF failure unless rollback fails. | Rollback rejection/failure. |
| Outbound-memory creation failure | Lock and request created. | Exact WDF status if available. | Delete request tree, then spinlock. | `MODEL_READY | FAULTED`, handles null. | Exact WDF failure unless rollback fails. | Rollback rejection/failure. |
| Inbound-memory creation failure | Lock, request, outbound memory created. | Exact WDF status if available. | Delete request tree, then spinlock. | `MODEL_READY | FAULTED`, handles null. | Exact WDF failure unless rollback fails. | Rollback rejection/failure. |
| Partial-state validation failure | Most recent successful object state. | Local validation result. | Delete request tree if request exists, then spinlock. | `MODEL_READY | FAULTED`, handles null. | `STATUS_INVALID_DEVICE_STATE` unless rollback fails. | Any validation failure after rollback. |
| Ready validation failure | Full pre-ready graph briefly existed; `OWNER_READY` was cleared before rollback. | Local validation result. | Delete request tree, then spinlock. | `MODEL_READY | FAULTED`, handles null. | `STATUS_INVALID_DEVICE_STATE` unless rollback fails. | Any retained ready bit. |
| Rollback rejection or failure | Unknown or produced partial state. | Preserved in report with original failed stage/status. | No best-effort direct deletion. | `OWNER_READY` absent; state preserved for failure evidence. | `STATUS_INVALID_DEVICE_STATE`. | Implementation must stop and audit before loading. |

No path returns success with a partial or faulted owner.

## 13. Failure after successful structural readiness

If dormant orchestration succeeds but a later current `EvtDeviceAdd` step
fails, the selected strategy is to return failure from `EvtDeviceAdd` and rely
on framework cleanup of the failed device instance and its parented children.

Current examples are lifecycle initialization failure,
`ChatpadFilterLifecycleMarkDeviceCreated` failure, or future post-insertion
setup failure. No queue, interface, or symbolic link exists today, but future
post-orchestration additions must use the same rule unless a separate design
changes it.

Rejected strategies:

- Explicit destruction of a ready dormant graph in this path: the current
  rollback helper is pre-ready only.
- Clearing ready and invoking partial rollback: misuses the rollback contract.
- Adding a cleanup callback for dormant ready objects: no independent resource
  or active operation exists.

Framework device-parent cleanup is preferred because the failed `EvtDeviceAdd`
destroys the whole device instance, the lock/request are device-parented, the
memory objects are request-parented, no target exists, no request is formatted
or submitted, no completion/cancellation callback exists, and no observer can
access the context after failed device creation unwinds.

The ordinary owner handles become inaccessible with device-context destruction.
There is no explicit lifecycle release because no lifecycle operation was
admitted. This is distinct from normal removal after future runtime use, which
requires separate active-operation teardown.

Implementation stop condition: before coding this slice, the audit must cite a
framework contract proving `WDFDEVICE` children are cleaned up after
`EvtDeviceAdd` returns failure. Installed headers prove parentage through
`WDF_OBJECT_ATTRIBUTES.ParentObject`; the full failure-cleanup contract must
remain evidence-bound.

## 14. Successful `EvtDeviceAdd` outcome

After future successful integration and a successful `EvtDeviceAdd` return:

- owner storage is initialized;
- the dormant object graph is structurally ready;
- lock, request, outbound memory, and inbound memory handles are present;
- the request target remains absent;
- the request is unformatted;
- no completion routine exists;
- no submission occurred;
- no cancellation occurred;
- no lifecycle operation is admitted;
- no active generation or activation step exists;
- the pure model remains non-admitting;
- no Chatpad input behavior changes.

Driver behavior must remain externally unchanged despite dormant internal WDF
object creation.

## 15. Observer and callback analysis

Current paths that retrieve device context after `EvtDeviceAdd`:

| Path | Knows about request owner today | Could observe `OWNER_READY` after future embedding | Runs before or after `EvtDeviceAdd` completion | Concurrent with future initialization | Readiness check required | Locking required |
| --- | --- | --- | --- | --- | --- | --- |
| `ChatpadLogLifecycle` from `EvtDeviceAdd` | No. | Only if later modified; first slices must not modify it. | Before return. | No. | No, unless it starts reading owner. | No owner lock needed today. |
| `ChatpadEvtDevicePrepareHardware` | No. | It could after future code is added, but first linkage slices must not read owner. | After successful add. | No current overlap. | Yes before any future owner observation. | Yes if observing mutable owner state. |
| `ChatpadEvtDeviceReleaseHardware` | No. | Same as above. | After successful add. | No current overlap with initialization. | Yes. | Yes for mutable owner state. |
| `ChatpadEvtDeviceD0Entry` | No. | Same as above. | After successful add. | No current overlap with initialization. | Yes. | Yes before D0 observes or admits operations. |
| `ChatpadEvtDeviceD0Exit` | No. | Same as above. | After successful add. | No current overlap with initialization. | Yes. | Yes before D0/rundown observes owner. |

No current cleanup, destroy, surprise-removal, unload, queue, request,
completion, cancellation, timer, work-item, interface, or symbolic-link path
retrieves the context.

The first production-linkage slices must add no observer other than the
integration code itself.

## 16. Concurrency and publication contract

Current dormant publication assumptions:

- one `EvtDeviceAdd` caller initializes one device instance;
- no current observer reads owner fields;
- no current callback reads owner state before successful `EvtDeviceAdd`
  completion;
- no operation can start;
- no completion or cancellation callback exists;
- no target exists.

Under those constraints, sequential handle publication, bit publication, and
final `OWNER_READY` publication are sufficient for the first dormant
integration slice.

This is not a general thread-safety claim. Stronger synchronization is required
before any of these stop conditions are crossed:

- a D0 callback observes the owner;
- target discovery reads the request;
- an activation operation is admitted;
- a cancellation or completion path exists;
- cleanup can race an external call;
- any callback can observe partial state.

The selected future synchronization object remains the per-owner
device-parented spinlock, but no production callback may begin using it until a
separate synchronization/rundown slice is designed and audited.

## 17. IRQL and callback context

Installed KMDF 1.15 header evidence from
`C:\Program Files (x86)\Windows Kits\10\Include\wdf\kmdf\1.15`:

- `WdfDriverCreate` is annotated `_IRQL_requires_max_(PASSIVE_LEVEL)`.
- `WdfFdoInitSetFilter` is annotated `_IRQL_requires_max_(PASSIVE_LEVEL)`.
- `WdfDeviceCreate` is annotated `_IRQL_requires_max_(PASSIVE_LEVEL)`.
- `EVT_WDF_DEVICE_D0_ENTRY`, `EVT_WDF_DEVICE_D0_EXIT`,
  `EVT_WDF_DEVICE_PREPARE_HARDWARE`, and
  `EVT_WDF_DEVICE_RELEASE_HARDWARE` are annotated
  `_IRQL_requires_max_(PASSIVE_LEVEL)`.
- `WdfSpinLockCreate`, `WdfRequestCreate`,
  `WdfMemoryCreatePreallocated`, and `WdfObjectDelete` are annotated
  `_IRQL_requires_max_(DISPATCH_LEVEL)`.
- `WDF_OBJECT_ATTRIBUTES` contains optional `ParentObject`,
  `EvtCleanupCallback`, `EvtDestroyCallback`, execution level, and
  synchronization scope fields.
- `WDF_DECLARE_CONTEXT_TYPE_WITH_NAME` generates context type information and a
  typed context accessor over `WdfObjectGetTypedContextWorker`.

Expected execution context:

- `EvtDeviceAdd`: PASSIVE_LEVEL because it calls PASSIVE-only framework APIs.
- Ordinary owner initialization: runs at the selected `EvtDeviceAdd` point,
  PASSIVE_LEVEL.
- Orchestration: runs at the selected `EvtDeviceAdd` point, PASSIVE_LEVEL even
  though the individual creation APIs allow DISPATCH_LEVEL.
- Partial rollback during initialization failure: runs inside orchestration at
  the selected point, PASSIVE_LEVEL.
- Later framework deletion after failed `EvtDeviceAdd`: framework-owned; exact
  callback/IRQL behavior must be cited before adding cleanup callbacks.

Unresolved IRQL assumptions are stop conditions before implementation if any
future observer, cleanup path, completion path, cancellation path, or rundown
path would run above the level required by its operations.

## 18. Completed project-linkage-only dormancy

Historical plan recorded before production owner integration. This slice was
completed by the project-linkage checkpoint before commit
`a25d5637487ec6e4e7583a64dcec6c5192e06092`. The completed slice:

- add `ChatpadKmdfRequestOwnerContext.vcxproj` as a production dependency of
  `ChatpadFilter`;
- add only required include paths if the project system needs them for
  dependency evaluation;
- embed no owner;
- invoke no helper;
- change no callback;
- introduce no retained isolated symbol or WDF object-management import in
  `ChatpadFilter.sys` unless native project-system evidence proves a harmless
  import is unavoidable;
- preserve runtime behavior.

At that completed historical checkpoint, the unused static library was expected
not to contribute object members to the final image because no production
symbol referenced it. The completed checkpoint proved that expectation by
symbol/import inspection. Later owner embedding and ordinary initialization
supersede only the no-owner/no-helper portions of this historical boundary.

## 19. Completed device-context embedding

Historical plan recorded before production owner integration. The owner
embedding portion is complete. The completed production checkpoint:

- include `ChatpadKmdfRequestOwnerContext.h` from `driver.h`;
- embed one `ChatpadKmdfActivationRequestOwner ActivationRequestOwner` in
  `CHATPAD_FILTER_DEVICE_CONTEXT`;
- initialized ordinary owner storage in the same completed checkpoint rather
  than leaving it observable as uninitialized storage;
- avoided dormant orchestration and WDF object creation;
- avoid callback changes;
- compile the production driver;
- confirm no object-management imports are introduced merely by embedding
  ordinary storage.

Leaving embedded storage uninitialized remains a rejected future pattern if any
production observer could read it.

## 20. Completed ordinary initialization without WDF creation

Historical plan recorded before production owner integration. The ordinary
initialization slice is complete. The completed production checkpoint:

- calls `ChatpadKmdfRequestOwnerInitializeStorage` exactly once;
- relies on the initializer's internal validation;
- performs one additional explicit pre-object integration-boundary validation
  with `ChatpadKmdfRequestOwnerValidatePreObjectState`;
- perform no WDF object creation;
- validates the clean baseline without publishing `OWNER_READY`;
- run from the selected post-scalar context initialization point;
- return failure on invariant violation;
- remain externally behavior-neutral.

If the driver were loaded in a later authorized environment, this slice would
execute during `EvtDeviceAdd`, but driver loading remains unauthorized during
offline validation. Offline validation must prove no `WdfSpinLockCreate`,
`WdfRequestCreate`, `WdfMemoryCreatePreallocated`, `WdfObjectDelete`, target
discovery, formatting, send, completion, or cancellation call is reachable from
that slice.

## 21. Dormant orchestration invocation

The report-aware documentation-only production orchestration-invocation design
is complete in
[Windows 11 KMDF Production Orchestration Invocation Design](WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md).
It selects the exact future binding point after explicit pre-object validation
and before lifecycle initialization, distinguishes early rejection from
post-baseline no-object stage failure, defines deterministic local report
initialization/lifetime, documents every supported result/report/mask/rollback
category, and binds production status selection. The second independent design
audit failed only because the prior report/status taxonomy and report
initialization wording were incomplete; the corrected early-rejection
semantics remain accepted, and the dormant implementation is unchanged.
A third independent audit then found three remaining documentation-contract
defects: exact report fields `Result` and `ReadyPublicationAttempted` were not
explicitly bound, the later `EvtDeviceAdd` lifecycle category was ambiguous,
and future evidence did not explicitly require highest/final-mask checks. The
report-contract correction binds all 19 report fields, deterministic lifecycle
subcases 22A and 22B, and explicit
`HighestPartialInitializationMask`/`FinalInitializationMask` evidence. Another
independent audit then found remaining implicit taxonomy/effect values,
incomplete exact-field bindings in section 28, and an insufficient
`ReadyPublicationAttempted` semantic guard. The taxonomy-contract correction
now provides closed value/effect/origin sets, a ready-field truth table,
all 19 section-28 field bindings, and source-level ready-attempt guard
requirements. Another independent read-only audit is required before source
implementation.

The later dormant orchestration slice shall:

- invoke `ChatpadKmdfRequestOwnerCreateDormantObjectGraph`;
- create the four dormant framework objects when the driver is loaded;
- set structural `OWNER_READY`;
- acquire no target;
- format or submit no request;
- register no completion or cancellation;
- fail `EvtDeviceAdd` on orchestration failure;
- use explicit rollback only for pre-ready partial creation failure;
- rely on the selected framework device-parent cleanup strategy for later
  post-ready `EvtDeviceAdd` failure.

This will be the first implementation slice that changes runtime WDF object
creation behavior if loaded. It requires a fresh independent audit before any
source implementation and another independent audit before any loading or
installation. This document does not authorize that slice.

## 22. Normal removal boundary

Device-parent cleanup is sufficient only while:

- no operation has ever been admitted;
- no request has been formatted or submitted;
- no completion or cancellation callback exists;
- no external call pin exists;
- no target exists.

Normal removal after future activation work requires separately implemented
admission closure, cancellation, completion terminalization, external-call pin
rundown, lifecycle release, and D0/removal synchronization.

The current rollback helper and failed-`EvtDeviceAdd` framework deletion
strategy do not solve future active-operation teardown.

## 23. Target-discovery boundary

Production integration of the dormant graph must not enumerate USB devices,
open an I/O target, inspect descriptors, acquire a lower target, format a
control transfer, touch the controller, or touch the Chatpad.

Target discovery remains a later architecture and implementation phase.

## 24. Build, binary, and import expectations

| Slice | Source/project changes | Static library inclusion | Retained symbols | WDF imports | Driver size/hash | Runtime behavior | Validation needed |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Project linkage only | `ChatpadFilter.vcxproj` project reference and possibly include path only. | Context library named as dependency. | Expected none if unused. | Expected none new. | May change build metadata/hash only if linker input ordering changes; do not require identical hash. | Unchanged. | Build, import/symbol diff, semantic guard, repository safety. |
| Device-context embedding | Include context header and add embedded field. | Context library still available. | Context type metadata/header effects possible; no helper objects expected. | Expected no object-management imports from embedding alone. | Legitimate hash/size change allowed. | Unchanged because field is unobserved. | Compile, context layout guard, no global owner, no helper calls. |
| Ordinary initialization call | Add storage initializer call and mapping. | Context library member for storage/model may be retained. | Storage/model helper symbols expected. | Expected no `WdfSpinLockCreate`, `WdfRequestCreate`, `WdfMemoryCreatePreallocated`, or `WdfObjectDelete`. | Legitimate hash/size change. | `EvtDeviceAdd` initializes ordinary storage only if loaded. | Compile, semantic guard, import check, offline tests. |
| Dormant orchestration invocation | Add orchestration call and status mapping. | Context object-creation members retained. | Orchestration and creation/rollback helpers expected. | Expected direct WDF imports for lock, request, memory, and rollback delete only. | Legitimate hash/size change. | Creates dormant internal objects if loaded; no target/request activity. | Fresh audit before load, import counts, failure-path guards, no hardware/install. |

Previous driver hashes need not remain identical after legitimate project or
source changes. The validation must explain the expected binary effect of each
slice.

## 25. Semantic-guard contract

Future implementation guards must verify, as applicable:

- exact production project dependency;
- exact owner field count is one;
- no global owner;
- exact initialization call count is one;
- exact orchestration call count is one only in the authorized slice;
- exact insertion location in `ChatpadEvtDeviceAdd`;
- no target discovery;
- no request formatting, reuse, send, completion registration, or cancellation;
- no D0 or removal observer before the authorized observer slice;
- no installation or signing changes;
- no duplicate protocol constants;
- no confirmed outbound `90 00` value;
- expected direct WDF imports for each stage;
- no accidental inclusion of isolated helpers before their authorized stage;
- only ignored evidence beneath `artifacts\` is generated.

Prefer syntax-aware or narrowly scoped checks. The existing semantic wrappers
use targeted text/regex checks in several places; that is useful for narrow
guards but limited for proving call reachability, macro expansion, and link
extraction. Any broad regex guard must be paired with diff inspection and, for
binary effects, import/symbol inspection.

## 26. Validation-evidence retention contract

Future implementation checkpoints shall retain full command logs as ignored
files beneath `artifacts\logs` and record SHA-256 hashes for each retained log.
Each checkpoint must record:

- exact command or wrapper name;
- configuration and platform;
- result and assertion count where applicable;
- starting commit;
- final Git tree identity;
- toolchain identity;
- driver path, size, SHA-256, and Authenticode state when a driver is built;
- repository-safety result;
- Markdown-link result for documentation checkpoints;
- diff-check result.

Selected tracked manifest format:

```text
docs/evidence/<checkpoint-name>-manifest.json
```

The tracked JSON manifest may contain log relative path, log SHA-256,
validation type, configuration, expected count, observed result, driver
artifact hashes, repository-safety result, Markdown-link result, and diff-check
result. Full logs remain ignored and must not be committed.

A tracked manifest cryptographically binds expected retained-log contents to
the Git commit even though ignored log files remain mutable. The containing
commit supplies the final Git tree identity; a manifest does not record its own
commit hash because doing so would be self-referential. The linkage checkpoint
created the manifest, and the later evidence-correction checkpoint completed
its command, path, result, and hash fields.

## 27. Implementation decomposition

Separately authorized slices:

1. Completed: production project-reference and include-path integration only.
2. Completed: independent audit of project linkage and evidence correction.
3. Completed: device-context owner embedding plus ordinary initialization.
4. Completed: independent audit and evidence correction for owner
   initialization, followed by this documentation consistency correction.
5. Remaining future integration: dormant orchestration invocation at the
   selected `EvtDeviceAdd` location.
   Prohibited: target discovery, formatting, submission, completion,
   cancellation, D0/removal observer changes, signing, loading, hardware.
6. Remaining: independent read-only audit of executable dormant orchestration
   integration if that future slice is implemented.
7. Remaining: separately designed target discovery after the dormant owner is
   audited.
8. Remaining: request-formatting design.
9. Remaining: submission, completion, and cancellation implementation.
10. Remaining: D0 and removal rundown.
11. Remaining: signing and package validation.
12. Remaining: separately authorized installation and hardware observation.

No implementation slice is authorized by this document.

## 28. Binding decisions and stop conditions

Binding decisions:

1. Linkage mechanism: native production `ProjectReference` to the existing
   `ChatpadKmdfRequestOwnerContext` static library, plus required native
   dependency resolution for `ChatpadRequestOwnerModel`.
2. Header boundary: `driver.h` includes the authoritative context header; no
   type duplication.
3. Owner placement: one embedded
   `ChatpadKmdfActivationRequestOwner ActivationRequestOwner` in the
   per-device context.
4. Ordinary initialization location: after current context scalar setup and
   before `ChatpadFilterLifecycleInitialize`.
5. Orchestration location: immediately after ordinary owner initialization and
   validation, before lifecycle initialization.
6. Exact call order: context retrieval, scalar setup, owner storage init,
   baseline validation, dormant orchestration, structural ready requirement,
   existing lifecycle setup, return only after existing required steps.
7. Status propagation: preserve exact WDF failure statuses when available; map
   local invariant failures to stable local statuses; never return success
   after rollback.
8. Rollback ownership: current rollback remains pre-ready only.
9. Later `EvtDeviceAdd` failure cleanup: after structural readiness, rely on
   framework deletion of the failed device instance and its parented children;
   do not misuse partial rollback.
10. Concurrency assumptions: sequential `EvtDeviceAdd` publication is
    sufficient only while no observer exists.
11. IRQL assumptions: selected integration runs at PASSIVE_LEVEL; future
    observers require renewed IRQL proof.
12. Evidence-retention format: tracked JSON manifests under `docs/evidence/`
    plus ignored hashed logs under `artifacts\logs`.
13. Production orchestration-invocation binding: documented, including the
    report-aware, report-contract, and taxonomy-contract corrections, in
    `docs/WINDOWS11-KMDF-PRODUCTION-ORCHESTRATION-INVOCATION-DESIGN.md`;
    implementation remains unauthorized.
14. Next repository task: independent read-only audit of the finalized
    taxonomy contract, not source implementation.

Stop conditions:

- circular include or owner type duplication;
- project-configuration mismatch;
- unexpected retained WDF imports during linkage-only slice;
- inability to prove device-context lifetime exceeds child object lifetime;
- callback capable of observing partial state;
- unresolved IRQL issue;
- requirement for active cleanup before a target or submission exists;
- any need to modify INF, install, signing, or hardware behavior;
- any requirement to execute the driver during an offline-only checkpoint;
- inability to prove failed-`EvtDeviceAdd` framework cleanup before the
  orchestration slice;
- any implementation pressure to discover a target, format, send, cancel, load,
  install, sign, or query hardware before its own gate.

Fundamental production integration decisions are selected here; implementation
remains separately gated.

## Implemented ordinary-initialization checkpoint

The `feature/offline-kmdf-owner-embedding-init` checkpoint implements only
the design's header, embedded-storage, ordinary-initialization, and immediate
pre-object-validation slice:

- `driver.h` includes `ChatpadKmdfRequestOwnerContext.h`;
- `CHATPAD_FILTER_DEVICE_CONTEXT` embeds exactly one
  `ChatpadKmdfActivationRequestOwner ActivationRequestOwner`;
- `EvtDeviceAdd` initializes and validates it after
  `context->DiagnosticSequence = 0u;` and before
  `ChatpadFilterLifecycleInitialize(&context->Lifecycle)`;
- the portable model source is compiled directly as a WDK object because the
  existing user-mode model library has user-mode default-library metadata;
- no orchestration, creation, rollback, ready publication, target, request,
  D0, cleanup, or removal slice is implemented.

The checkpoint record is
[Offline KMDF Production Owner Initialization](OFFLINE-KMDF-PRODUCTION-OWNER-INITIALIZATION.md).
The third design audit found missing explicit `Result` and
`ReadyPublicationAttempted` bindings, ambiguous post-orchestration lifecycle
wording, and missing explicit highest/final-mask evidence requirements, not a
dormant implementation defect. The report-contract documentation correction is
complete and requires another independent read-only audit. Dormant
orchestration implementation and execution remain unauthorized. The fourth
audit found implicit taxonomy and rollback-effect values, incomplete section-28
exact-field binding, and insufficient source-level
`ReadyPublicationAttempted` guarding. The taxonomy-contract documentation
correction closes those issues and requires another independent read-only
audit.
