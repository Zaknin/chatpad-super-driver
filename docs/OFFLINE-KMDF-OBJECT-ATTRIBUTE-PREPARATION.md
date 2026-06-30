# Offline KMDF Object-Attribute Preparation Checkpoint

Follow-up checkpoint: [Offline KMDF Creation Orchestration](OFFLINE-KMDF-CREATION-ORCHESTRATION.md)
now compiles the full dormant object-graph composition that relies on these
parentage helpers. No production driver path invokes the composition.

This checkpoint implements compile-only `WDF_OBJECT_ATTRIBUTES` preparation
for the future dormant activation request-owner objects. It initializes
caller-owned attribute structures and creates no framework object.

## Implemented helpers

`ChatpadKmdfRequestOwnerContext` now exposes four exact helpers:

- `ChatpadKmdfRequestOwnerPrepareBookkeepingLockAttributes`;
- `ChatpadKmdfRequestOwnerPrepareActivationRequestAttributes`;
- `ChatpadKmdfRequestOwnerPrepareOutboundMemoryAttributes`;
- `ChatpadKmdfRequestOwnerPrepareInboundMemoryAttributes`.

The lock and activation-request helpers require a non-null `WDFDEVICE` and set
it as `ParentObject`. The outbound and inbound memory helpers require a
non-null `WDFREQUEST` and set it as `ParentObject`. The request helper uses
`WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE` with
`ChatpadKmdfActivationRequestContext`; the other helpers use ordinary
`WDF_OBJECT_ATTRIBUTES_INIT`.

All four helpers:

- reject a null attribute output;
- reject a null required parent through a typed result;
- leave execution level inherited from the parent;
- explicitly select `WdfSynchronizationScopeNone`;
- register no cleanup or destroy callback;
- initialize only caller-owned attributes.

The two memory helpers intentionally share the same internal plain-memory
preparation path while remaining separate public APIs so outbound and inbound
intent is explicit at future call sites.

## Validation

The WDK compile-check calls all four exact signatures with typed `WDFDEVICE`
and `WDFREQUEST` arguments. The semantic wrapper proves:

- exactly two device-parent assignments exist;
- one shared request-parent assignment serves both memory builders;
- only the activation request receives the typed request context;
- no helper overrides inherited execution level;
- no helper registers cleanup or destroy callbacks;
- no WDF object-creation, deletion, reference, target, formatting, send,
  cancellation, completion, installation, signing, or hardware surface exists;
- the ordinary storage baseline remains model-ready only;
- `ChatpadFilter` remains unlinked from the context module.

## Explicit non-scope

This checkpoint does not create a lock, request, memory object, device, target,
queue, timer, work item, callback, thread, or event. It does not call any WDF
object-creation API, publish `OWNER_READY`, change `DriverEntry`,
`EvtDeviceAdd`, the live device context, INF/package/signing/install paths, or
access any device or hardware.

[Offline KMDF Lock and Request Creation Checkpoint](OFFLINE-KMDF-LOCK-REQUEST-CREATION.md)
now compiles the two independent dormant creation helpers using these exact
attributes. The creation calls are never executed, and memory creation,
rollback, production linkage, request execution, installation, and hardware
access remain absent.

[Offline KMDF Preallocated-Memory Creation Checkpoint](OFFLINE-KMDF-PREALLOCATED-MEMORY-CREATION.md)
now uses both request-parented memory attribute helpers with the exact reusable
request. No memory context or cleanup/destroy callback was introduced.

[Offline KMDF Partial-Creation Rollback Checkpoint](OFFLINE-KMDF-PARTIAL-CREATION-ROLLBACK.md)
relies on that parentage: deleting the request initiates deletion of both
memory children without individual memory deletion or new callbacks.
