# Offline KMDF Request-Owner Context Definition

This checkpoint defines the compile-only KMDF-facing context layouts for the
future Chatpad activation request owner. It proves WDK/KMDF compilation of the
intended storage and context declarations only.

## Purpose

- Starting branch: `feature/offline-request-owner-state-model`.
- Starting commit: `7f5ff4264d3171a1067a3eb0090f48b9979fe609`.
- New branch: `feature/offline-kmdf-request-owner-context`.
- New compile-only module:
  `src/driver/ChatpadKmdfRequestOwnerContext/`.
- New compile-check target:
  `tests/kernel/ChatpadKmdfRequestOwnerContextCompileCheck/`.
- New validation wrapper:
  `tools/Test-ChatpadKmdfRequestOwnerContext.ps1`.

The checkpoint bridges the pure request-owner model into WDK-visible type
declarations without linking those declarations into `ChatpadFilter`.

## Non-scope

This checkpoint does not create, initialize, attach, format, submit, complete,
cancel, reuse, delete, install, load, sign, stage, package, query, or access any
runtime object or device. In particular it does not:

- call `WdfRequestCreate`, `WdfMemoryCreate`,
  `WdfMemoryCreatePreallocated`, `WdfObjectAllocateContext`,
  `WdfSpinLockCreate`, `WdfWaitLockCreate`,
  `WdfUsbTargetDeviceCreate`,
  `WdfUsbTargetDeviceFormatRequestForControlTransfer`,
  `WdfIoTargetFormatRequestForInternalIoctlOthers`, `WdfRequestReuse`,
  `WdfRequestSend`, `WdfRequestCancelSentRequest`,
  `WdfRequestSetCompletionRoutine`, `WdfIoTargetStart`, `WdfIoTargetStop`, or
  `IoCallDriver`;
- register a completion or cancellation callback;
- modify `DriverEntry` or any active KMDF callback;
- embed the owner in the current live device context;
- link or invoke the new module from `ChatpadFilter`;
- run InfVerif or Inf2Cat;
- produce a CAT, certificate, package, signing output, installer, registry
  mutation, service mutation, Driver Store mutation, PnP query, USB query,
  controller action, or Chatpad action.

## Authoritative inputs

The context definitions conform to:

- [Windows 11 KMDF Request Owner and Buffer Lifetime](WINDOWS11-KMDF-REQUEST-OWNER-BUFFER-LIFETIME.md);
- [Offline Request-Owner State Model](OFFLINE-REQUEST-OWNER-STATE-MODEL.md);
- `src/transport/ChatpadRequestOwnerModel/`;
- `ChatpadPrepareActivationStep(size_t, ChatpadActivationPreparation*)`;
- the existing `ChatpadTransportOperationToken`;
- KMDF 1.15 context and object-attribute declarations.

The only pure-model portability change is a kernel-mode fallback definition for
`UINT32_MAX` in `ChatpadRequestOwnerModel.h`, because the WDK C include path
does not provide that macro through the existing portable header chain.

## Selected module and dependency graph

```text
ChatpadKmdfRequestOwnerContext
  includes WDK/KMDF declarations
  includes ChatpadActivationPreparation
  includes ChatpadRequestOwnerModel
  reuses ChatpadTransportOperationToken

ChatpadKmdfRequestOwnerContextCompileCheck
  compiles ChatpadKmdfRequestOwnerContext.c
  compiles ChatpadRequestOwnerModel.c under WDK
  references ChatpadKmdfRequestOwnerContext.vcxproj with LinkLibraryDependencies=false

ChatpadFilter
  no include
  no project reference
  no compile item
  no link input
  no /INCLUDE retention
```

The context module is a KMDF static library so that WDK type compatibility can
be proven. It remains separate from the production driver project.

## Exact owner type

`ChatpadKmdfActivationRequestOwner` is the future per-device activation
request-owner storage. It contains:

- `Signature` and `Version`;
- one explicit `InitializationMask`;
- embedded pure `ChatpadActivationRequestOwner Model`;
- future `WDFREQUEST Request` handle;
- future `WDFMEMORY OutboundMemory` handle;
- future `WDFMEMORY InboundMemory` handle;
- future `WDFSPINLOCK BookkeepingLock` handle;
- distinct fixed transfer storage;
- bounded completion snapshot.

The owner does not duplicate generation, operation token, activation step, or
primary state because those are already authoritatively represented by the pure
model. The future request context carries immutable operation snapshots for
completion-time access.

## Exact request-context type

`ChatpadKmdfActivationRequestContext` is declared with
`WDF_DECLARE_CONTEXT_TYPE_WITH_NAME` and accessor
`ChatpadKmdfGetActivationRequestContext`.

It contains:

- pointer to the owning `ChatpadKmdfActivationRequestOwner`;
- immutable `ChatpadTransportOperationToken`;
- immutable lifecycle-generation snapshot;
- immutable activation-step snapshot;
- data direction and transfer direction;
- transfer length and expected inbound length;
- active transfer-memory handle;
- copied `WDF_USB_CONTROL_SETUP_PACKET`;
- bounded completion snapshot.

The owner pointer is a future device/request lifetime relationship: the owner
is device-owned, and the future reusable request is explicitly device-parented.
This checkpoint only declares the relationship; it does not attach or validate
an actual WDF object.

## Transfer storage

`ChatpadKmdfActivationTransferStorage` contains two distinct fixed arrays:

- `OutboundBytes[CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY]`;
- `InboundBytes[CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY]`.

`CHATPAD_KMDF_ACTIVATION_OUTBOUND_CAPACITY` is the authoritative
`CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH`, currently exactly two bytes.
`CHATPAD_KMDF_ACTIVATION_INBOUND_CAPACITY` is exactly two bytes, matching the
maximum expected inbound length in the established six-step activation
sequence.

No arbitrary buffer, dynamic allocation, variable-length array, flexible array,
stack-surviving asynchronous storage, or `90 00` confirmed payload is
introduced.

## Memory context

No WDF memory context is selected. The future `WDFMEMORY` objects are
represented as request-parented handles over the fixed owner/request storage,
and no additional per-memory metadata is currently justified beyond the owner
and request context fields.

## Initialization-state representation

The owner uses a bounded initialization mask:

- `CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY`;
- `CHATPAD_KMDF_REQUEST_OWNER_INIT_REQUEST_CREATED`;
- `CHATPAD_KMDF_REQUEST_OWNER_INIT_OUTBOUND_MEMORY_CREATED`;
- `CHATPAD_KMDF_REQUEST_OWNER_INIT_INBOUND_MEMORY_CREATED`;
- `CHATPAD_KMDF_REQUEST_OWNER_INIT_LOCK_CREATED`;
- `CHATPAD_KMDF_REQUEST_OWNER_INIT_OWNER_READY`;
- `CHATPAD_KMDF_REQUEST_OWNER_INIT_DRAINING`;
- `CHATPAD_KMDF_REQUEST_OWNER_INIT_FAULTED`.

Zeroed storage is therefore not equivalent to a fully ready owner. This task
does not implement initialization, creation, cleanup, draining, or fault
reconstruction logic.

## Compile-time invariants

The module and compile-check assert:

- outbound capacity is exactly two bytes;
- inbound capacity is exactly two bytes;
- outbound capacity equals `CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH`;
- activation sequence step count remains six;
- activation step index can represent all known steps;
- pure model type is complete and embeddable;
- owner and request-context types are complete and nonzero;
- model field uses the authoritative pure model type;
- operation token field uses the authoritative transport token type;
- generation and transferred-length storage do not truncate the supported
  two-byte transfer length;
- request, memory, spinlock, and active-transfer fields use WDF handle types;
- outbound and inbound arrays are distinct fields;
- captured inbound snapshot is exactly two bytes.

No total structure size is asserted.

## Semantic guard

`tools/Test-ChatpadKmdfRequestOwnerContext.ps1` verifies:

- no WDF object-creation call exists;
- no request reuse, formatting, send, cancel, completion-registration, target
  start/stop, or `IoCallDriver` call exists;
- no dynamic allocation, wait, delay, installation, device-query, HID, IOCTL,
  or URB runtime surface exists in the new code;
- no global mutable request-owner instance exists;
- exact outbound and inbound capacities are present and asserted;
- the authoritative pure model and operation-token types are reused;
- no setup packet or activation sequence is duplicated;
- `90 00` is not introduced;
- typed request context and ordinary object-attribute declarations compile;
- `ChatpadFilter` does not include, reference, link, retain, or embed the new
  context module;
- generated outputs stay beneath ignored `artifacts/`.

The guard passes in Debug and Release wrapper runs.

## Validation

Final validation evidence is recorded in `docs/WORKLOG.md` for this
checkpoint. The new compile-check wrapper passes in x64 Debug and Release and
prints the static-library hashes and log paths. Existing request-owner,
protocol, transport, lifecycle, control-setup, kernel-compatibility, WDF
formatter, driver, full-solution, repository-safety, and whitespace checks
remain required.

## What this proves

This milestone proves only:

- WDK/KMDF compilation of the intended context layouts;
- compatibility with the portable request-owner model;
- exact fixed transfer-storage representation;
- typed request-context declaration;
- ordinary request/memory object-attribute declaration compatibility;
- future ownership and parentage representation.

It does not prove object creation, context attachment to an actual WDF object,
request reuse, memory creation, lock creation or correctness, control-transfer
formatting, request submission, completion behavior, cancellation behavior,
D0-exit rundown, target discovery, USB visibility, controller preservation,
activation effectiveness, Chatpad input, signing, staging, installation,
loading, actual lower-filter placement, or a usable driver.

## Follow-on object-lifecycle design

[Windows 11 KMDF Request Object Creation and Cleanup Design](WINDOWS11-KMDF-REQUEST-OBJECT-CREATION-CLEANUP.md)
is the follow-on design-only checkpoint for using these declarations in a
future dormant object-creation slice. It selects:

- creation immediately after successful `WdfDeviceCreate` in `EvtDeviceAdd`;
- ordinary owner storage in the future device context;
- a device-parented `WDFSPINLOCK`;
- a device-parented reusable `WDFREQUEST`;
- request-parented outbound and inbound preallocated `WDFMEMORY` descriptors
  over the existing fixed two-byte arrays;
- no initial request target;
- no cleanup or destroy callbacks for the dormant objects;
- explicit reverse-order rollback during initialization failure.

The context module remains compile-only and absent from `ChatpadFilter`
runtime behavior. No live WDF object, context attachment, target, formatting,
submission, completion registration, cancellation, device action, signing,
staging, installation, or hardware access exists because of either document.

## Follow-on owner storage initialization

[Offline KMDF Owner Storage Initialization Checkpoint](OFFLINE-KMDF-OWNER-STORAGE-INITIALIZATION.md)
implements the first source slice that uses these declarations. It adds
ordinary storage initialization and pre-object validation inside the same
isolated context module. The helper initializes the embedded pure model,
clears the fixed two-byte transfer storage and completion snapshot, explicitly
leaves all future WDF handle fields null, and sets only `MODEL_READY`.

The helper still does not create a WDF object, attach framework context to a
live object, publish `OWNER_READY`, link into `ChatpadFilter`, format or send
a request, register completion, cancel, install, load, package, sign, query a
device, or access hardware.
