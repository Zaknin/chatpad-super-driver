# Offline KMDF Production Owner Initialization

## Purpose and boundary

This checkpoint embeds and ordinarily initializes one authoritative KMDF
request owner per production `ChatpadFilter` device context. It remains an
offline build checkpoint. It does not invoke dormant orchestration, create or
delete a WDF object, discover a target, perform a request operation, alter D0
or removal behavior, sign, package, stage, install, load, enumerate hardware,
or interact with a controller or Chatpad.

- Starting branch: `feature/offline-production-linkage-evidence-fix`
- Starting commit: `41172d7f2877509a16f3b58abf0f81d231cbabaf`
- Implementation branch: `feature/offline-kmdf-owner-embedding-init`
- Evidence manifest:
  [production-owner-initialization-manifest.json](evidence/production-owner-initialization-manifest.json)

## Retention preflight

Debug and Release `ChatpadKmdfRequestOwnerContext.lib` each contain one COFF
member, `ChatpadKmdfRequestOwnerContext.obj`. That member defines ordinary
initialization and validation together with dormant creation, rollback, and
orchestration code. Both configurations compile with `/Gy`; `dumpbin /HEADERS`
shows separate COMDAT sections for the relevant functions. Both driver links
use `/OPT:REF`, `/OPT:ICF`, and `/INCREMENTAL:NO`, with no request-owner
`/INCLUDE` or `/WHOLEARCHIVE`. The existing
`/INCLUDE:ChatpadPrepareActivationStep` is unrelated.

That function-level separation permits the linker to retain the referenced
WDF-free initializer and validator without retaining dormant creation,
rollback, orchestration, or their WDF object-management thunks. The retained
conclusion combines source checks, production-object references, context
object COMDATs, compiler/linker tracking, final PE sections, and observable
symbols/imports. Ordinary PE import-table absence alone is not proof of no
KMDF call because KMDF APIs dispatch through the WDF function table.

## Production integration

`src/driver/ChatpadFilter/driver.h` is the authoritative header boundary. It
includes `ChatpadKmdfRequestOwnerContext.h` once and embeds exactly:

```c
ChatpadKmdfActivationRequestOwner ActivationRequestOwner;
```

`ChatpadFilter.vcxproj` retains its existing context-library
`ProjectReference`, adds only the three narrowly required include roots, and
compiles the portable `ChatpadRequestOwnerModel.c` directly as a WDK object.
It does not compile the isolated context source or link the user-mode model
library.

In `ChatpadEvtDeviceAdd`, the immediately preceding scalar statement is:

```c
context->DiagnosticSequence = 0u;
```

The code then calls
`ChatpadKmdfRequestOwnerInitializeStorage(&context->ActivationRequestOwner)`
exactly once. That authoritative initializer performs internal baseline
validation. `EvtDeviceAdd` immediately calls
`ChatpadKmdfRequestOwnerValidatePreObjectState` exactly once more with
caller-owned validation storage as a separate production integration-boundary
invariant check. Only after both return
`CHATPAD_KMDF_REQUEST_OWNER_STORAGE_OK` does execution reach:

```c
ChatpadFilterLifecycleInitialize(&context->Lifecycle)
```

The narrow status mapping is:

- success maps to `STATUS_SUCCESS`;
- impossible null owner or validation inputs map to
  `STATUS_INVALID_PARAMETER`;
- repeated initialization and every invariant failure map to
  `STATUS_INVALID_DEVICE_STATE`;
- any pre-object validation failure returns
  `STATUS_INVALID_DEVICE_STATE`.

No rollback is needed or called because no framework object exists.

## Resulting baseline

The authoritative signature and version are set. The initialization mask is
exactly `MODEL_READY` (`0x00000001`). The pure model is initialized; fixed
two-byte outbound and inbound arrays are zero; completion snapshots are
inactive; operation identity, generation, and activation step are invalid;
all WDF handles are null; `FAULTED`, `OWNER_READY`, and all
lock/request/memory-created bits are absent. There is no lifecycle obligation,
active operation, external-call pin, cancellation/completion state, or
sequence-advance eligibility.

The request-owner model and the existing driver lifecycle model remain
separate authoritative components. No D0, hardware, cleanup, or removal
callback reads the owner.

## Binary evidence

| Configuration | Driver | Size | SHA-256 | Signature |
|---|---|---:|---|---|
| Debug | `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys` | 20,992 | `FB9E9DD550BEF64B99BFAA74810A953A5B0DC12BB455869D7787FB657B565B8F` | `NotSigned` |
| Release | `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys` | 14,336 | `9EA24A8B6BEB2796B9A1FF55A04486C8E3EB59B94A191AEA6F50B322531CBCE3` | `NotSigned` |

The Debug `device.obj` contains undefined references only to the two allowed
request-owner entry points. Release uses anonymous `/GL` inputs, so allowed
calls are proven through source, compiler input, context-object, and linker
evidence and may be inlined. Final PE symbol tables expose no request-owner
names, which is expected and is not treated as stand-alone proof. Combined
evidence finds no forbidden production reference or forced retention and no
forbidden retained code or observable import/table-reference evidence. KMDF
function-table dispatch limits what ordinary import inspection can prove.

## Validation

Debug and Release context checks, driver builds, full-solution builds,
production owner-initialization guards, and production-linkage guards passed.
The successful Community solution builds contain zero warning/error
diagnostics. Regressions passed in both configurations:

- request-owner model: `5002/5002`;
- protocol: `610/610`;
- transport: `186/186`;
- lifecycle: `109/109`;
- control setup: `141/141`;
- protocol kernel compatibility: PASS;
- WDF control setup: PASS.

An initial full-solution attempt selected the Visual Studio Build Tools
MSBuild installation, which lacks WDK integration, and failed with `MSB8020`.
The retained failed log is not accepted build evidence. The exact verified
Visual Studio Community MSBuild rerun passed in both configurations.

## Proof limit

This checkpoint proves only that one ordinary owner exists per production
device context, storage is initialized once with initializer-internal
validation, one additional explicit pre-object integration-boundary check
succeeds before lifecycle initialization, no dormant framework object graph is
created, and production remains targetless and request-inactive.

The audit corrections and guard limitations are recorded in
[Owner Initialization Audit Corrections](OFFLINE-KMDF-OWNER-INITIALIZATION-AUDIT-CORRECTIONS.md).

It does not prove orchestration execution, spinlock/request/memory creation,
runtime object parentage, rollback execution, target discovery, request
formatting/submission/completion/cancellation, D0 rundown, signing, staging,
installation, loading, hardware behavior, or a usable driver.
