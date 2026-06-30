# Offline KMDF Lock and Request Creation Checkpoint

Follow-up checkpoint: [Offline KMDF Creation Orchestration](OFFLINE-KMDF-CREATION-ORCHESTRATION.md)
now calls the lock helper before the request helper as part of the compile-only
all-or-nothing composition. These helpers remain independent and were not
executed during validation.

## Purpose and scope

This checkpoint compiles isolated dormant creation code for one future
per-device bookkeeping spinlock and one future reusable activation request. It
does not link or invoke that code from `ChatpadFilter`.

- Starting branch: `feature/offline-kmdf-object-attributes`.
- Starting commit: `8b5a5b8b376568c063d521e76693a4067cc579a2`.
- Working branch: `feature/offline-kmdf-lock-request-creation`.
- Installed contract: KMDF 1.15 from Windows Kits 10.0.26100.0.

The installed KMDF 1.15 declarations mark both `WdfSpinLockCreate` and
`WdfRequestCreate` for maximum `DISPATCH_LEVEL`. `WdfRequestCreate` declares
its `WDFIOTARGET` argument optional, so the request helper passes
`WDF_NO_HANDLE` and performs no target discovery.

## Creation APIs

The isolated `ChatpadKmdfRequestOwnerContext` module now exposes:

```c
ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock(
    WDFDEVICE parentDevice,
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus);

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateReusableRequest(
    WDFDEVICE parentDevice,
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus);
```

The only WDF creation calls in the isolated production source are exactly one
`WdfSpinLockCreate` and exactly one `WdfRequestCreate`. The request helper also
uses the generated `ChatpadKmdfGetActivationRequestContext` accessor after a
hypothetical successful request creation.

Both helpers initialize a non-null `frameworkStatus` output to
`STATUS_INVALID_DEVICE_STATE` before local validation. A successful WDF call
leaves the exact returned success status in the output; a failed WDF call
leaves the exact framework failure status. The typed project result remains
separate from the framework status.

## Spinlock creation

`ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock` requires:

- non-null owner, parent device, and framework-status output;
- valid owner signature, version, and known initialization mask;
- exact ordinary pre-object state (`MODEL_READY` only);
- null lock, request, and memory handles;
- no created, ready, draining, or faulted state;
- zero fixed transfer and completion storage;
- valid unavailable pure-model baseline with no operation or lifecycle
  obligation.

It prepares the authoritative device-parented lock attributes, calls
`WdfSpinLockCreate` once, and publishes the returned handle before OR-ing only
`LOCK_CREATED`. It then validates the lock-created partial state.

Repeated lock creation and any pre-existing request are rejected before the
WDF call. A WDF failure publishes neither handle nor bit and does not alter
the model, transfer arrays, completion snapshot, or owner-ready state.

## Reusable targetless request creation

`ChatpadKmdfRequestOwnerCreateReusableRequest` requires:

- the same non-null and owner identity checks;
- exact lock-created partial state;
- `LOCK_CREATED` with a non-null bookkeeping lock;
- no request-created bit or request handle;
- no memory-created bits or memory handles;
- no ready, draining, faulted, operation, or lifecycle state.

It prepares the authoritative typed device-parented request attributes and
calls:

```c
WdfRequestCreate(&attributes, WDF_NO_HANDLE, &request);
```

The local request handle is not published on WDF failure. After hypothetical
success, the generated accessor retrieves the typed request context. The
ordinary initializer clears that context and assigns:

- the owning `ChatpadKmdfActivationRequestOwner` pointer;
- invalid device generation and operation sequence;
- invalid lifecycle generation and activation step;
- `CHATPAD_CONTROL_DATA_DIRECTION_NONE`;
- `CHATPAD_KMDF_REQUEST_OWNER_TRANSFER_NONE`;
- zero actual and expected transfer lengths;
- null active transfer memory;
- zero setup packet;
- zero completion snapshot with completion class `NONE`.

The handle is published before OR-ing only `REQUEST_CREATED`. Memory-created
and owner-ready bits remain absent. Repeated request creation and request
creation before the spinlock are rejected before the WDF call.

The context initializer is infallible for valid non-null inputs. An impossible
null typed-context result after WDF success is reported as an inconsistent
post-creation state, not as an invented initializer failure.

## Typed results and partial-state validation

`ChatpadKmdfRequestOwnerCreationResult` distinguishes null inputs, invalid
signature/version/mask, invalid pre-object state, repeated lock/request
creation, missing lock, unexpected handles, premature memory or owner-ready
state, active operation/lifecycle state, attribute failure, exact WDF creation
failure class, invalid request context, post-creation invariant failure, and
unsupported/inconsistent state.

`ChatpadKmdfRequestOwnerValidateCreationState` distinguishes:

| Expected state | Exact initialization mask | Required handles | Context |
| --- | --- | --- | --- |
| Pre-object | `MODEL_READY` | All null | Null |
| Lock created | `MODEL_READY | LOCK_CREATED` | Lock non-null; request/memory null | Null |
| Lock and request created | `MODEL_READY | LOCK_CREATED | REQUEST_CREATED` | Lock/request non-null; memory null | Exact dormant context |
| Fully ready | Invalid and unreachable | Not accepted | Not accepted |

Every accepted partial state keeps the pure model unavailable/non-admitting,
has no lifecycle obligation, keeps fixed storage zero, and has no memory or
owner-ready state.

## Failure, ordering, and rollback boundary

- Each creation helper calls at most one WDF creation API.
- The helpers do not call one another.
- WDF failure does not publish a handle or created bit.
- A successful creation publishes the handle before its corresponding bit.
- Post-creation inconsistency returns a typed failure while retaining the
  created handle/bit so a future authorized orchestrator can own cleanup.
- No helper deletes, dereferences, rolls back, retries, or fabricates an object.
- A later independent orchestration slice must own reverse-order rollback.

## Compile-only execution boundary

Both projects remain static libraries. The compile-check takes typed function
addresses to prove the APIs and implementations compile but never invokes
either helper. It does not fabricate WDF handles or a fake WDF runtime.

**Creation calls were compiled but never executed; no WDF object was created
during this checkpoint.**

Symbol inspection of the isolated Debug library found the two creation
helpers, partial-state validator, authorized WDF creation symbols, and typed
context worker. Release optimization retained the public helper/validator
symbols while inlining framework wrappers. Import inspection of both final
`ChatpadFilter.sys` images found zero lock/request creation or isolated-helper
matches.

## Validation

All required offline validation passed:

- semantic guard: exactly `WdfSpinLockCreate=1`,
  `WdfRequestCreate=1`;
- project/compile-check counts: one production context C source, three
  compile-check C inputs, zero creation-helper invocations;
- context compile-check: x64 Debug and Release PASS;
- request-owner model: `5002/5002` Debug and Release;
- protocol: `610/610` Debug and Release;
- transport: `186/186` Debug and Release;
- lifecycle: `109/109` Debug and Release;
- control setup: `141/141` Debug and Release;
- protocol kernel compatibility: Debug and Release PASS;
- WDF control setup: Debug and Release PASS;
- full solution: Debug and Release, zero warnings and zero errors;
- repository safety and artifact containment: PASS.

Final context compile-check evidence:

| Configuration | Log | Context library SHA-256 | Compile-check library SHA-256 |
| --- | --- | --- | --- |
| Debug | `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T092442Z.log` | `1A5883D30FCDF93D41182A5B09A13B2EA73A1E56024DDC1C86D216BC6D40AB92` | `C0C6D9F3745BB5FF58B3B36D77FBA27C022FA9089B8035BCF6DE2DCB79FA4FA2` |
| Release | `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T092443Z.log` | `12697F6C4D0D1610664357234DFA3DD34E803A46E1B7809C1561B24FB92833B5` | `CD19C22DD462A80A84FEB1FC96B4E349E00C86717EEC06F070BCE9E602B22E65` |

Full-solution logs:

- `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-lock-request-creation-final-Debug-20260630T092141Z.log`;
- `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-lock-request-creation-final-Release-20260630T092142Z.log`.

Final full-solution driver artifacts:

| Configuration | Path | Size | SHA-256 | Authenticode |
| --- | --- | ---: | --- | --- |
| Debug | `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys` | 15,872 | `54D039D1A99872BF3C0466B192A57A6738917080326D3001A19A934B4C937870` | `NotSigned` |
| Release | `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys` | 12,288 | `4E33D23642B3CE26179C96305B1AEF291F64A1BB0BA74526FFCC455E5E95B852` | `NotSigned` |

## What this milestone proves

This milestone proves only:

- compilation of device-parented spinlock creation code;
- compilation of device-parented targetless reusable-request creation code;
- typed request-context initialization after hypothetical successful creation;
- correct partial initialization-state transitions;
- continued production-driver dormancy.

It does not prove helper execution, actual lock/request/context creation,
memory creation, rollback/deletion, owner-ready publication, production
linkage, target discovery, formatting, submission, completion, cancellation,
D0 rundown, USB visibility, controller preservation, activation, Chatpad
input, signing, staging, installation, loading, lower-filter placement, or a
usable driver.

The next slice is now documented by
[Offline KMDF Preallocated-Memory Creation Checkpoint](OFFLINE-KMDF-PREALLOCATED-MEMORY-CREATION.md).
It compiles independent outbound and inbound one-object helpers without
execution. Rollback orchestration remains the next independent gate.

[Offline KMDF Partial-Creation Rollback Checkpoint](OFFLINE-KMDF-PARTIAL-CREATION-ROLLBACK.md)
now compiles request-first then spinlock rollback for every valid partial
state. The helper remains uninvoked and does not implement normal teardown.
