# Offline KMDF Partial-Creation Rollback Checkpoint

## Purpose and scope

This checkpoint compiles one isolated dormant helper that can reverse any
valid pre-ready partial activation request-owner creation state. It does not
execute rollback, orchestrate creation, implement normal teardown, or link to
`ChatpadFilter`.

- Starting branch: `feature/offline-kmdf-memory-creation`.
- Starting commit: `142f8e11bebac78cf2e10367c96d3b409d9c8db7`.
- Working branch: `feature/offline-kmdf-creation-rollback`.
- Installed contract: KMDF 1.15 from Windows Kits 10.0.26100.0.

KMDF 1.15 declares `WdfObjectDelete(WDFOBJECT)` as a `VOID` operation valid
through `DISPATCH_LEVEL`. Deletion is initiated; this checkpoint does not
claim synchronous object destruction.

## APIs

```c
ChatpadKmdfRequestOwnerRollbackResult
ChatpadKmdfRequestOwnerClassifyRollbackState(
    const ChatpadKmdfActivationRequestOwner *owner,
    ChatpadKmdfRequestOwnerRollbackState *state);

ChatpadKmdfRequestOwnerRollbackResult
ChatpadKmdfRequestOwnerRollbackPartialCreation(
    ChatpadKmdfActivationRequestOwner *owner,
    ChatpadKmdfRequestOwnerRollbackEffects *effects);
```

The effects report contains no handles or allocation. It records prior and
resulting masks, whether request-hierarchy and spinlock deletion were
initiated, whether each memory child was represented, and an already-clean
disposition. It is zeroed before every call that receives a non-null output
and remains empty on rejected owner states.

## Source-state classification

Accepted pre-ready states are:

1. `MODEL_READY` (already clean);
2. `MODEL_READY | LOCK_CREATED`;
3. the above plus `REQUEST_CREATED`;
4. the above plus `OUTBOUND_MEMORY_CREATED`;
5. the above plus `INBOUND_MEMORY_CREATED`;
6. `MODEL_READY | FAULTED` with no handles (previously rolled back).

The classifier rejects null/invalid identity, unknown or unsupported masks,
`OWNER_READY`, `DRAINING`, invalid pure-model invariants/baseline, active
operation or lifecycle state, nonzero dormant snapshots, and every mismatch
between a created bit and its handle. It also rejects request without lock,
memory without request, and inbound without outbound. Classification does not
dereference a framework handle.

## Reverse-order deletion and parent ownership

For an accepted created state, rollback snapshots the request and spinlock
handles locally. If a request exists it calls:

```c
WdfObjectDelete(request);
```

exactly once. The request owns both preallocated memory children, so neither
memory handle is deleted individually. After initiating request deletion, the
helper clears request/outbound/inbound owner handles and their three creation
bits. It never accesses the request or its context again.

If a spinlock exists, rollback then calls:

```c
WdfObjectDelete(spinlock);
```

exactly once and clears the lock handle/bit. The lock is never acquired.

The publication order is deletion initiation followed immediately by clearing
the corresponding handle(s) and bit(s). This never leaves a creation bit set
with a cleared handle. No concurrent observer exists because rollback is
restricted to dormant pre-ready state.

## Post-rollback and idempotence

Successful rollback leaves:

- all framework handles null;
- all four creation bits absent;
- `OWNER_READY` absent;
- exact mask `MODEL_READY | FAULTED`;
- the pure model unchanged in its unavailable/non-admitting baseline;
- fixed arrays and completion storage unchanged and inactive;
- no operation, lifecycle obligation, submission, completion, cancellation,
  pin, or sequence state.

The diagnostic `FAULTED` state is preserved rather than silently erased.
Rollback of clean `MODEL_READY` or valid `MODEL_READY | FAULTED` returns
`ALREADY_CLEAN`, initiates no deletion, and reports no deletion effects.
Repeated rollback is therefore harmless.

Rejected inconsistent states are not repaired or deleted best-effort. The
owner remains unchanged and effects remain empty.

## Explicit non-scope

This helper is initialization-failure rollback only. It is not normal device
removal, cleanup, D0 rundown, active-operation cancellation/retirement, a full
creation orchestrator, or a readiness publisher. It does not free or clear
backing arrays, add callbacks, discover a target, or operate a request.

## Compile-only boundary

Both projects remain static libraries. The compile-check takes typed function
addresses and never calls rollback or a creation helper. No fake WDF runtime
or fabricated handle is used.

**Rollback deletion calls were compiled but never executed; no WDF object was
deleted during this checkpoint.**

## Validation

- Semantic guard: `WdfSpinLockCreate=1`, `WdfRequestCreate=1`,
  `WdfMemoryCreatePreallocated=2`, `WdfObjectDelete=2`.
- Context compile-check: x64 Debug and Release PASS.
- Request-owner model: `5002/5002` Debug and Release.
- Protocol: `610/610` Debug and Release.
- Transport: `186/186` Debug and Release.
- Lifecycle: `109/109` Debug and Release.
- Control setup: `141/141` Debug and Release.
- Protocol kernel compatibility and WDF control setup: Debug/Release PASS.
- Driver and full solution: Debug/Release PASS, zero warnings/errors.
- Repository safety and output containment: PASS.

Context evidence:

| Configuration | Log | Context library SHA-256 | Compile-check library SHA-256 |
| --- | --- | --- | --- |
| Debug | `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Debug-20260630T100041Z.log` | `F4471A0130677D9537F2CA21AC7D16BC2A8ADA3C6C22B91DDD7D9DDC9E90D55E` | `0A3756E170C8959D38ABC38E7AE88C3CB13C215DE2214D7F35A1079057027CB8` |
| Release | `C:\Dev\chatpad-super-driver\artifacts\logs\chatpad-kmdf-request-owner-context-Release-20260630T100050Z.log` | `3ACBAAF95B32A33B4E853696216D2CC1B9A947D4A55799B5D2CD31DC435918BF` | `E6AAFA8714A58E729A664CDC95C054A747B0E403917DA3B5729EBAEC60A2DC46` |

The hashes are from the final full-solution build of the same source. Logs:

- `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-creation-rollback-Debug-20260630T100146Z.log`;
- `C:\Dev\chatpad-super-driver\artifacts\logs\full-solution-creation-rollback-Release-20260630T100150Z.log`.

Final drivers:

| Configuration | Path | Size | SHA-256 | Authenticode |
| --- | --- | ---: | --- | --- |
| Debug | `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Debug\ChatpadFilter\ChatpadFilter.sys` | 15,872 | `88C7C43120D5C36BDE379CC1B463A9BDDEFD46A5BC1992456B6F9CF7CAC2452A` | `NotSigned` |
| Release | `C:\Dev\chatpad-super-driver\artifacts\bin\x64\Release\ChatpadFilter\ChatpadFilter.sys` | 12,288 | `A75A7CEAB6536E422019B4020B3CF5D47419FECC429321B25445F98F4C45650A` | `NotSigned` |

Import inspection found no `WdfObjectDelete` or rollback-helper reference in
either driver image. The symbols exist only in the isolated static library.

## Proof boundary and next gate

This milestone proves compilation of reverse-order partial-creation rollback,
request-parent ownership of both memory children, independent spinlock
deletion, deterministic publication clearing, idempotent clean behavior, and
continued production dormancy.

It does not prove rollback execution, actual or child deletion ordering, full
creation orchestration, owner-ready publication, normal removal, active
operation rundown, production linkage, target/request operations, D0 rundown,
USB visibility, controller preservation, activation, Chatpad input, signing,
staging, installation, loading, lower-filter placement, or a usable driver.

The next independently gated slice is full dormant creation orchestration with
rollback and final non-runtime `OWNER_READY` publication. This checkpoint does
not authorize it.
