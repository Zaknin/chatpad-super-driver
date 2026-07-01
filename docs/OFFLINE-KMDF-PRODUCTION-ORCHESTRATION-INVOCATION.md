# Offline KMDF Production Orchestration Invocation

## Summary

This checkpoint implements the first offline production invocation of the
existing dormant KMDF request-owner object-graph orchestrator. The production
driver now calls `ChatpadKmdfRequestOwnerCreateDormantObjectGraph` exactly once
from `ChatpadEvtDeviceAdd` after ordinary owner initialization and explicit
pre-object validation succeed, and before lifecycle initialization.

This is an offline build and inspection checkpoint only. No driver was signed,
packaged, staged, installed, loaded, or executed. No Windows state, USB state,
controller, or Chatpad hardware was queried or modified.

## Starting State

- Starting branch:
  `feature/offline-kmdf-orchestration-defensive-taxonomy-fix`
- Starting commit:
  `4ba0de15420e0b66287a501918de694c8b6fd720`
- Parent:
  `8b06ff5c2a7679b3057992ac99302fa550ddf098`
- Subject:
  `docs: close orchestration defensive taxonomy`
- Implementation branch:
  `feature/offline-kmdf-production-orchestration-invocation`

## Production Source Change

The source change is intentionally narrow:

- `src/driver/ChatpadFilter/device.c` adds a private
  `ChatpadOrchestrationResultToStatus` mapper.
- `device.c` adds a private `ChatpadValidateOrchestrationReadyState`
  structural-ready validator.
- `ChatpadEvtDeviceAdd` creates one local
  `ChatpadKmdfRequestOwnerOrchestrationReport orchestrationReport = { 0 };`.
- `ChatpadEvtDeviceAdd` calls
  `ChatpadKmdfRequestOwnerCreateDormantObjectGraph(device,
  &context->ActivationRequestOwner, &orchestrationReport)` exactly once.
- The function return is cross-checked against `orchestrationReport.Result`.
  Any mismatch returns `STATUS_INVALID_DEVICE_STATE` before lifecycle
  initialization.
- Any non-OK orchestration result is mapped to `NTSTATUS` and returned before
  lifecycle initialization.
- Only after OK does production verify structural readiness and then continue
  to the existing lifecycle path.

`device.c` still does not directly call the individual creation helpers,
rollback helper, attribute-preparation helpers, `WdfSpinLockCreate`,
`WdfRequestCreate`, `WdfMemoryCreatePreallocated`, `WdfObjectDelete`, target
discovery, request formatting, request send, completion registration, or
request cancellation.

## Report Lifetime

The orchestration report is a stack-local synchronous diagnostic object. It is
zero-initialized by the caller, passed to the orchestrator, read only after the
orchestrator returns, and is not stored in the device context. No report
pointer escapes `EvtDeviceAdd`.

The orchestrator remains authoritative for clearing and populating report
fields. Caller zero-initialization is the production convention and makes the
call shape deterministic.

## Status Mapping

Production status selection is:

- `OK`: helper returns `STATUS_SUCCESS`, but the `EvtDeviceAdd` path continues
  to structural-ready validation and lifecycle initialization before final
  success.
- `NULL_OWNER`, `NULL_PARENT_DEVICE`, `NULL_REPORT`:
  `STATUS_INVALID_PARAMETER`.
- `SPINLOCK_FAILED`, `REQUEST_FAILED`, `OUTBOUND_MEMORY_FAILED`,
  `INBOUND_MEMORY_FAILED`: return failing `report.FrameworkStatus` when it is
  failing; otherwise return `STATUS_INVALID_DEVICE_STATE`.
- `INVALID_SIGNATURE`, `UNSUPPORTED_VERSION`, `INVALID_BASELINE`,
  `ALREADY_READY`, `ALREADY_FAULTED`, `PARTIAL_STATE_PRESENT`,
  `PRE_READY_VALIDATION_FAILED`, `READY_VALIDATION_FAILED`,
  `ROLLBACK_FAILED`, `INVARIANT_FAILED`, and default:
  `STATUS_INVALID_DEVICE_STATE`.
- Function-return/report-result mismatch:
  `STATUS_INVALID_DEVICE_STATE`.

Production does not perform caller-owned rollback. The orchestrator owns
pre-ready partial rollback.

## Structural Ready

Before lifecycle initialization, production requires:

- `orchestrationReport.ReadyPublicationAttempted != 0`;
- `orchestrationReport.ReadyPublished != 0`;
- `orchestrationReport.ObjectGraphComplete != 0`;
- `context->ActivationRequestOwner.Request != NULL`;
- `ChatpadKmdfRequestOwnerValidateCreationState(...,
  CHATPAD_KMDF_REQUEST_OWNER_CREATION_STATE_FULLY_READY)` returns
  `CHATPAD_KMDF_REQUEST_OWNER_CREATION_OK`.

Failure of any structural-ready check returns `STATUS_INVALID_DEVICE_STATE`
before lifecycle initialization.

## Binary Effect

The driver hash and size legitimately changed because production now contains
the first real call into the dormant object-graph orchestrator.

| Configuration | Path | Size | SHA-256 | Authenticode |
| --- | --- | ---: | --- | --- |
| Debug | `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys` | 32256 | `826700E0556840D79D5A18A6C7CFA739FAF8ADEC6A9A3CF37F544187FBEAA821` | `NotSigned` |
| Release | `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys` | 20480 | `D0983260B9CAD00CD72EE3F2AE4697110AA5C13DF01F7BC2B39C0FEF891F4CB3` | `NotSigned` |

Debug object inspection shows the retained dormant orchestration, rollback, and
WDF object-management evidence. Release uses LTCG, so ordinary named helper and
WDF symbols are not expected to remain visible in the same way; validation
combines source, link inputs, context-object evidence, final-image forbidden
operation absence, and no forced `/INCLUDE` or `/WHOLEARCHIVE`.

## Validation

Retained evidence is recorded in
`docs/evidence/production-orchestration-invocation-manifest.json`.

Passed offline validation included:

- Debug and Release driver wrapper builds.
- Debug and Release full-solution builds through the Visual Studio Community
  toolchain.
- Request-owner model tests: 5002/5002 assertions in Debug and Release.
- Protocol tests: 610/610 assertions in Debug and Release.
- Transport tests: 186/186 assertions in Debug and Release.
- Lifecycle tests: 109/109 assertions in Debug and Release.
- Control-setup tests: 141/141 assertions in Debug and Release.
- KMDF request-owner context compile checks in Debug and Release.
- Protocol kernel compatibility checks in Debug and Release.
- WDF control-setup compile checks in Debug and Release.
- Production linkage semantic guard in Debug and Release.
- Production owner-initialization SourceOnly guard in Debug and Release.
- Production orchestration SourceOnly and Full guards in Debug and Release.
- Binary inspection for driver size, SHA-256, signature status, retained helper
  evidence, no final target/request-operation evidence, and no forced
  request-owner retention.

One full-solution attempt through the Build Tools MSBuild instance was blocked
with `MSB8020` because that Visual Studio instance lacks the
`WindowsKernelModeDriver10.0` platform toolset. The Community toolchain has the
WDK integration and passed Debug and Release.

## Non-Scope

This checkpoint does not implement target discovery, USB target opening,
request formatting, request submission, request completion, request
cancellation, D0/removal owner observation, active-operation rundown, cleanup
callbacks, destroy callbacks, signing, package creation, staging,
installation, driver loading, Windows mutation, hardware observation, or
Chatpad/controller interaction.

If this driver is later loaded under a separately authorized gate, the
`EvtDeviceAdd` path would create the dormant internal WDF object graph before
lifecycle initialization. That runtime behavior has not been observed or
qualified here.

## Next Gate

The next recommended task is an independent offline implementation and
evidence audit of this committed production orchestration invocation. The audit
should stay read-only, verify `device.c`, the semantic guard, the manifest,
the binary evidence, and continuity docs, and confirm no target/request/runtime
surface was introduced.
