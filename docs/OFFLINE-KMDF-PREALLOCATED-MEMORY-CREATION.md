# Offline KMDF Preallocated-Memory Creation Checkpoint

Follow-up checkpoint: [Offline KMDF Creation Orchestration](OFFLINE-KMDF-CREATION-ORCHESTRATION.md)
now calls the outbound helper before the inbound helper as part of the
compile-only all-or-nothing composition. These helpers remain independent and
were not executed during validation.

## Purpose and scope

This checkpoint compiles isolated dormant creation code for the future
request-parented outbound and inbound preallocated memory descriptors used by
the Chatpad activation request owner.

- Starting branch: `feature/offline-kmdf-lock-request-creation`.
- Starting commit: `9bd3a8e0ce6a94a5d6c7f6d45d2ca651d50ea497`.
- Working branch: `feature/offline-kmdf-memory-creation`.
- Installed contract: KMDF 1.15 from Windows Kits 10.0.26100.0.

The installed declaration accepts optional object attributes, a caller-owned
nonzero buffer and size, and a `WDFMEMORY` output at up to `DISPATCH_LEVEL`.
`WdfMemoryCreatePreallocated` describes the supplied storage; it does not own
or free the backing array.

## APIs and authorized framework calls

```c
ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateOutboundMemory(
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus);

ChatpadKmdfRequestOwnerCreationResult
ChatpadKmdfRequestOwnerCreateInboundMemory(
    ChatpadKmdfActivationRequestOwner *owner,
    NTSTATUS *frameworkStatus);
```

The isolated source contains exactly two newly authorized calls:

```c
WdfMemoryCreatePreallocated(
    &attributes,
    owner->TransferStorage.OutboundBytes,
    sizeof(owner->TransferStorage.OutboundBytes),
    &memory);

WdfMemoryCreatePreallocated(
    &attributes,
    owner->TransferStorage.InboundBytes,
    sizeof(owner->TransferStorage.InboundBytes),
    &memory);
```

The existing single `WdfSpinLockCreate` and targetless `WdfRequestCreate`
calls remain unchanged. Each helper calls at most one creation API and no
creation helper calls another.

## Parentage, storage, and handle authority

Both memory-attribute helpers set `ParentObject` to the exact reusable
`owner->Request`. Outbound memory describes
`owner->TransferStorage.OutboundBytes[2]`; inbound memory describes
`owner->TransferStorage.InboundBytes[2]`. The ordinary arrays live in the
future per-device owner storage and therefore outlive the request-parented
memory descriptors.

The owner fields `OutboundMemory` and `InboundMemory` are the authoritative
mutable handles. The existing typed request context has no duplicate handle
fields and remains in its exact inactive baseline throughout creation.
Creation does not clear, populate, copy, or replace either array.

No memory context, cleanup callback, or destroy callback is selected.

## Preconditions and transitions

Outbound creation requires the exact lock/request-created state:

- valid owner signature, version, and initialization mask;
- initialized ordinary storage and valid unavailable/non-admitting pure model;
- non-null lock and request with both created bits;
- null outbound/inbound memory handles and absent memory-created bits;
- inactive typed request context;
- exact two-byte outbound capacity;
- no ready, draining, faulted, active-operation, or lifecycle state.

On success it publishes the outbound handle and ORs only
`OUTBOUND_MEMORY_CREATED`.

Inbound creation additionally requires the outbound handle and bit, null
inbound handle, absent inbound bit, and exact two-byte inbound capacity. On
success it publishes the inbound handle and ORs only
`INBOUND_MEMORY_CREATED`.

The exact accepted masks are:

| State | Initialization mask |
| --- | --- |
| Model ready | `MODEL_READY` |
| Lock created | `MODEL_READY | LOCK_CREATED` |
| Lock/request created | `MODEL_READY | LOCK_CREATED | REQUEST_CREATED` |
| Outbound memory created | previous bits plus `OUTBOUND_MEMORY_CREATED` |
| Both memory objects created | previous bits plus `INBOUND_MEMORY_CREATED` |

`OWNER_READY` remains unset and is rejected by the partial-state validator.

## Failure and repeat behavior

The helpers initialize a non-null framework-status output to
`STATUS_INVALID_DEVICE_STATE`. After a framework call they preserve its exact
`NTSTATUS`; successful creation returns the framework success status.

- Outbound-before-request, inbound-before-outbound, repeated outbound, and
  repeated inbound calls are rejected before a framework creation call.
- A framework failure publishes no new handle or bit.
- Outbound failure leaves no memory state.
- Inbound failure retains the valid outbound partial state.
- Neither path changes buffer contents, model state, request-context state, or
  owner readiness.
- No path retries, deletes, dereferences, or rolls back an object.

A future separately authorized orchestrator must own reverse-order rollback
when a later creation step fails.

## Compile-only execution boundary

Both projects remain static libraries. The compile-check takes typed addresses
of all four creation helpers and the validator but invokes none of them. It
does not fabricate framework handles or a WDF runtime.

**Memory-creation calls were compiled but never executed; no WDF memory object
was created during this checkpoint.**

Symbol inspection found both helper symbols and
`WdfMemoryCreatePreallocated` only in the isolated Debug library. Import
inspection found zero memory-helper or preallocated-memory-creation matches in
both final `ChatpadFilter.sys` images.

## Validation

- Semantic guard: `WdfSpinLockCreate=1`, `WdfRequestCreate=1`,
  `WdfMemoryCreatePreallocated=2`.
- Context compile-check: x64 Debug and Release PASS.
- Request-owner model: `5002/5002` Debug and Release.
- Protocol: `610/610` Debug and Release.
- Transport: `186/186` Debug and Release.
- Lifecycle: `109/109` Debug and Release.
- Control setup: `141/141` Debug and Release.
- Protocol kernel compatibility: Debug and Release PASS.
- WDF control setup: Debug and Release PASS.
- Driver and full solution: Debug and Release PASS; final solution logs contain
  zero warnings and zero errors.
- Repository safety and output containment: PASS.

Context compile-check evidence:

| Configuration | Log | Context library SHA-256 | Compile-check library SHA-256 |
| --- | --- | --- | --- |
| Debug | `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T094922Z.log` | `F8496928976EDCFB0D1E7E3363BCEA60332337B766E0392BE128F55ECBB267C0` | `CBD2256E7C2F4194CD1ED7172F42D48C7798F1674DFADCD21D2A941DFDD78F53` |
| Release | `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T094924Z.log` | `3D2BB19C0A3D832BE2A602D53D6CD5EFFF7A3D908857E8959649EFC86C7E83B6` | `9C11FA5E3F3B00E106681C49B30FA0E1DE46F9DF7AED2C4C686FE24C6B911319` |

The library hashes above are from the final full-solution build of the same
source. Full-solution logs:

- `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-preallocated-memory-final-Debug-20260630T094933Z.log`;
- `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-preallocated-memory-final-Release-20260630T094935Z.log`.

Final drivers:

| Configuration | Path | Size | SHA-256 | Authenticode |
| --- | --- | ---: | --- | --- |
| Debug | `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys` | 15,872 | `AC5EB131736F97DE573F297EB450C9D449665E13A6BF3A622401FD433C521DF3` | `NotSigned` |
| Release | `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys` | 12,288 | `871B616DD761B7C678391249A54DC908A153651B91A9011ABA47E70D37B45613` | `NotSigned` |

## Proof boundary

This milestone proves compilation of request-parented outbound and inbound
preallocated-memory creation over the exact fixed arrays, deterministic
partial-mask transitions, and continued production-driver dormancy.

It does not prove helper execution, actual object creation or live parentage,
request use of either buffer, rollback/deletion, owner-ready publication,
production linkage, target discovery, formatting, submission, completion,
cancellation, D0 rundown, USB visibility, controller preservation, activation,
Chatpad input, signing, staging, installation, loading, lower-filter
placement, or a usable driver.

The next independently gated slice is rollback orchestration for partial
creation failure. This checkpoint does not authorize it.

[Offline KMDF Partial-Creation Rollback Checkpoint](OFFLINE-KMDF-PARTIAL-CREATION-ROLLBACK.md)
now compiles that reverse-order helper. It initiates request-tree deletion
before spinlock deletion, clears publication, retains `MODEL_READY | FAULTED`,
and never executes during validation.
