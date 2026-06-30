# Offline KMDF Creation Orchestration Checkpoint

This checkpoint records the isolated, dormant all-or-nothing KMDF activation
request-owner object-graph orchestration helper.

## Scope

The milestone compiles one orchestration API in the isolated
`ChatpadKmdfRequestOwnerContext` static-library module. It composes the
existing one-object creation helpers, existing creation-state validation, and
existing partial-creation rollback helper.

It proves only:

- compilation of all-or-nothing dormant object-graph orchestration;
- deterministic helper ordering;
- rollback invocation for partial failure;
- final structural ready-state publication;
- continued production-driver dormancy.

It does not prove orchestration execution, actual WDF object creation or
deletion, actual framework parentage, runtime synchronization, safe concurrent
publication, production linkage, `EvtDeviceAdd` integration, target discovery,
request formatting, request submission, completion, cancellation, D0 rundown,
USB visibility, controller preservation, activation effectiveness, Chatpad
input, signing, staging, installation, loading, lower-filter placement, or a
usable driver.

## Starting and branch state

- Starting branch: `feature/offline-kmdf-creation-rollback`.
- Starting commit: `9d5301e3c18deffbf4f90b5d3c2f058b00fe5b46`.
- Starting parent: `142f8e11bebac78cf2e10367c96d3b409d9c8db7`.
- Starting subject: `driver: define dormant creation rollback`.
- New branch: `feature/offline-kmdf-creation-orchestration`.

## Orchestration API

```c
ChatpadKmdfRequestOwnerOrchestrationResult
ChatpadKmdfRequestOwnerCreateDormantObjectGraph(
    WDFDEVICE parentDevice,
    ChatpadKmdfActivationRequestOwner *owner,
    ChatpadKmdfRequestOwnerOrchestrationReport *report);
```

The API is caller-owned and allocation-free. The report is cleared before
validation and contains no WDF handles.

## Stages, result, and report surface

`ChatpadKmdfRequestOwnerOrchestrationStage` records:

1. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_NONE`
2. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_VALIDATE_BASELINE`
3. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_CREATE_SPINLOCK`
4. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_CREATE_REQUEST`
5. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_CREATE_OUTBOUND_MEMORY`
6. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_CREATE_INBOUND_MEMORY`
7. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_VALIDATE_PRE_READY`
8. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_PUBLISH_READY`
9. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_VALIDATE_READY`
10. `CHATPAD_KMDF_REQUEST_OWNER_ORCHESTRATION_STAGE_ROLLBACK`

`ChatpadKmdfRequestOwnerOrchestrationResult` records success, null owner,
null parent device, null report, invalid signature, unsupported version,
invalid baseline, already ready, already faulted, partial state present,
spinlock failure, request failure, outbound-memory failure, inbound-memory
failure, pre-ready validation failure, ready validation failure, rollback
failure, and invariant failure.

`ChatpadKmdfRequestOwnerOrchestrationReport` records result, last stage
entered, last completed stage, failed stage, baseline validation result,
creation-helper result, validation result, framework `NTSTATUS`, rollback
result, rollback effects, initial mask, highest partial mask, final mask,
creation-helper-called flag, ready-publication-attempted flag, ready-published
flag, rollback-attempted flag, rollback-succeeded flag, and object-graph
complete flag.

## Required baseline

The orchestrator requires a non-null parent device, owner, and report; valid
owner signature and version; exact clean `MODEL_READY` baseline; no `FAULTED`;
no `OWNER_READY`; no creation bits; all framework handles null; no active
lifecycle obligation; no operation; no generation; no activation step; no send
or cancel pin; no completion/submission/cancellation state; and the pure model
in the authoritative non-admitting baseline.

Ready owners return already-ready without helper calls. Faulted owners return
already-faulted without helper calls. Valid partial states return
partial-state-present without helper calls, without rollback, and without
resuming creation.

## Helper call order

The success path calls existing helpers exactly in this order:

1. `ChatpadKmdfRequestOwnerCreateBookkeepingSpinLock`
2. `ChatpadKmdfRequestOwnerCreateReusableRequest`
3. `ChatpadKmdfRequestOwnerCreateOutboundMemory`
4. `ChatpadKmdfRequestOwnerCreateInboundMemory`

After each helper succeeds, the orchestrator validates the expected partial
state, records the completed stage and mask, and keeps `OWNER_READY` absent.
Outbound memory still precedes inbound memory. No helper is retried.

## Ready-state meaning and publication order

The completed ready state requires `MODEL_READY`, `LOCK_CREATED`,
`REQUEST_CREATED`, `OUTBOUND_MEMORY_CREATED`, `INBOUND_MEMORY_CREATED`,
`OWNER_READY`, no `FAULTED`, all four framework handles non-null, inactive
typed request context, exact two-byte fixed storage, and a non-admitting pure
model with no active operation or lifecycle state.

`OWNER_READY` means only:

> The dormant reusable object graph exists and is structurally prepared for a
> later separately authorized target and request-formatting phase.

It does not admit an activation operation.

Publication order is:

1. creation helpers publish each handle and bit only after framework success;
2. the orchestrator validates the complete pre-ready graph;
3. the orchestrator sets only `OWNER_READY`;
4. final ready-state validation must pass before the report returns success.

No caller-visible success is reported before final ready validation.

## Failure path and rollback ownership

Creation or validation failure enters one centralized failure path. The report
preserves failed stage, creation-helper result, framework status, and highest
partial mask reached.

If any framework object bit or handle was published, the orchestrator clears
`OWNER_READY`, invokes `ChatpadKmdfRequestOwnerRollbackPartialCreation` exactly
once, records rollback result and effects, and requires the final state to be
the documented faulted non-ready baseline. Rollback deletes the request
hierarchy before the independent spinlock; memory children are deleted only
through request parentage.

If no object was published, the orchestrator does not call rollback merely to
manufacture a deletion report. It validates the clean ordinary baseline and
marks the owner as `MODEL_READY | FAULTED`.

If final ready validation fails after tentative ready publication, the
orchestrator records that publication was attempted, clears `OWNER_READY`
before rollback, invokes rollback once, and returns ready-validation failure
unless rollback itself fails.

If rollback fails or is rejected, orchestration returns the dedicated rollback
failure result, preserves the original creation/validation failure evidence,
does not attempt direct best-effort deletion, and leaves `OWNER_READY` absent.
Production linkage remains prohibited until rollback failure is proven
unreachable for all orchestrator-produced partial states.

## Compile-only execution limitation

The orchestration and its creation/rollback calls were compiled but never
executed; no WDF object was created or deleted during this checkpoint.

The compile-check source takes the orchestration function address only. No host
test fabricates a WDF runtime or fake handles. `ChatpadFilter` does not include,
link, or invoke the isolated module.

## Semantic guard and compile-check results

`tools\Test-ChatpadKmdfRequestOwnerContext.ps1` passed in Debug and Release.
The semantic guard result was:

`Semantic guard: PASS (authorized direct calls: WdfSpinLockCreate=1, WdfRequestCreate=1, WdfMemoryCreatePreallocated=2, WdfObjectDelete=2; orchestrator helper calls=4, centralized rollback calls=1; all-or-nothing ready publication, no execution/runtime-driver linkage).`

Compile-check logs:

- `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T115118Z.log`
- `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T115206Z.log`

Final compile-check library hashes from full-solution validation:

- Debug context library:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`,
  SHA-256 `60AE6D7EC60B336E50D75AB9F3D75CE004886F68A86D811BE8C91759F8D4490B`.
- Debug compile-check library:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadKmdfRequestOwnerContextCompileCheck\ChatpadKmdfRequestOwnerContextCompileCheck.lib`,
  SHA-256 `0078CC1AADA7BE980B1E1B122DBF017F7958C46A475F4496FA8E0ADDED003795`.
- Release context library:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadKmdfRequestOwnerContext\ChatpadKmdfRequestOwnerContext.lib`,
  SHA-256 `ACF9F72EBFDB90C313B3A364AA8FA746781B80C1C275E664B14E3347F40A0621`.
- Release compile-check library:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadKmdfRequestOwnerContextCompileCheck\ChatpadKmdfRequestOwnerContextCompileCheck.lib`,
  SHA-256 `9746F112ED68C83FA2780D0B4516033E635A19E40515AFA3ED970E4EC86C3714`.

## Regression and build results

All required offline validation passed serially after a minimal PowerShell
wrapper syntax unblocker in `tools\Test-ChatpadRequestOwnerModel.ps1`.

- Request-owner model: Debug `5002/5002`, Release `5002/5002`.
- Protocol: Debug `610/610`, Release `610/610`.
- Transport: Debug `186/186`, Release `186/186`.
- Lifecycle: Debug `109/109`, Release `109/109`.
- Control setup: Debug `141/141`, Release `141/141`.
- Protocol kernel compatibility: Debug and Release passed.
- WDF control setup: Debug and Release passed.
- `Build-Driver.ps1`: Debug and Release passed.
- Full solution: Debug and Release passed with zero warning/error text in:
  - `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-orchestration-Debug-20260630T120133Z.log`
  - `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-orchestration-Release-20260630T120133Z.log`

The first attempted request-owner model wrapper run failed before compilation
because PowerShell cannot parse C-style unsigned integer suffixes such as
`14u`. The wrapper was corrected narrowly by replacing those comparison
literals with ordinary PowerShell integers, and the exact failed Debug model
wrapper then passed.

## Driver artifact evidence

Debug driver:

- Path:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys`
- Size: `15872` bytes.
- SHA-256:
  `2D42065CAF76B003FAB6C59A69775FD089F2390C7E0BBB26EB61A97B227EF0A3`.
- Authenticode: `NotSigned`.

Release driver:

- Path:
  `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys`
- Size: `12288` bytes.
- SHA-256:
  `CB677048F1F601C4A150E1EE3749CA802DE2D5D81AAED0894EAB38EEFE00F478`.
- Authenticode: `NotSigned`.

`dumpbin /imports` found zero orchestration, helper, or WDF object
creation/deletion imports in either driver image.

## ChatpadFilter dormancy proof

No `ChatpadFilter` source or project input changed. No active driver source
includes the isolated context header. No current device context embeds the
request owner. No callback calls initialization, creation, rollback, or
orchestration helpers. The isolated context library is not linked into
`ChatpadFilter`, and no `/INCLUDE` directive retains it.

No INF, CAT, certificate, package, staging, installation, driver load, Driver
Store mutation, registry/service mutation, device query, USB/controller/Chatpad
interaction, elevation, or hardware access occurred during this checkpoint.

## Next gate

The next task is an independent read-only audit of this orchestration
checkpoint. Production linkage, `EvtDeviceAdd` integration, target discovery,
request formatting, submission, completion, cancellation, signing, staging,
installation, loading, and hardware testing remain unauthorized.
