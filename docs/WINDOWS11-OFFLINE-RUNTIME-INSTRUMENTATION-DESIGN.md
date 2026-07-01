# Windows 11 Offline Runtime Instrumentation Design

## 1. Status and non-scope

This is a diagnostic-instrumentation design for a future first controlled
runtime observation of the Windows 11 Chatpad driver. It does not authorize
implementation, signing, packaging, staging, installation, loading, live device
query, target discovery, request execution, or hardware interaction.

The production object graph remains dormant. Target discovery and request
operations remain prohibited. Microsoft `xusb22`, device binding, package
identity, signing trust, and hardware identity are out of scope. Hardware
identity remains unknown and unqueried.

Accepted baseline:

- first-runtime observation and recovery plan:
  `fbca8852e47300d4f483968b23e42ee82e88b972`;
- accepted offline production orchestration source;
- frozen production build inputs;
- binary and A/B provenance;
- final 102-entry evidence manifest;
- observability verdict that the current binary is insufficiently observable.

None of the following has occurred: driver signing, package creation, package
staging, installation, loading, device binding, target discovery, request
execution, or hardware validation.

## 2. Existing observability inventory

Read-only source inspection located the following current observations.

| Source | Function | Location | Mechanism | Severity | Emitted data | Debug/Release availability | Proof value | Safety/privacy | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `src/driver/ChatpadFilter/driver.c` | `DriverEntry` | first statement after locals | `KdPrintEx` | `DPFLTR_INFO_LEVEL` | static string `ChatpadFilter: compile-only skeleton DriverEntry` | compiled in current source for both configurations unless compiler/filters suppress output | proves entry only if debug-print collection is armed | no sensitive data | retain as low-level fallback, supplement |
| `src/driver/ChatpadFilter/driver.c` | `DriverEntry` | `WdfDriverCreate` failure branch | `KdPrintEx` | `DPFLTR_ERROR_LEVEL` | failing `NTSTATUS` | same | proves WDF driver creation failure only if captured | status only, safe | retain, supplement with deterministic event |
| `src/driver/ChatpadFilter/device.c` | `ChatpadEvtDeviceAdd` | first executable statement after `Driver` is unreferenced | `KdPrintEx` | `DPFLTR_INFO_LEVEL` | static string `ChatpadFilter: lifecycle scaffold EvtDeviceAdd` | same | proves `EvtDeviceAdd` entry only if captured | no sensitive data | retain as fallback, supplement |
| `src/driver/ChatpadFilter/device.c` | `ChatpadEvtDeviceAdd` | `WdfDeviceCreate` failure branch | `KdPrintEx` | `DPFLTR_ERROR_LEVEL` | failing `NTSTATUS` | same | proves WDF device creation failure only if captured | status only, safe | retain, supplement |
| `src/driver/ChatpadFilter/device.c` | `ChatpadLogLifecycle` | lifecycle callback logger | `KdPrintEx` | `DPFLTR_INFO_LEVEL` | sequence, callback name, phase, generation, next generation, outstanding count, admission flag, result | same | proves lifecycle callback logging after the caller invokes `ChatpadLogLifecycle`; for `EvtDeviceAdd`, it only occurs after lifecycle init/mark-device-created path | bounded scalar fields; no pointers | retain as fallback, supplement and avoid relying on it as the only terminal event |
| `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c` | rollback helper | `WdfObjectDelete(request)` and `WdfObjectDelete(spinlock)` | no diagnostic statement | none | none | none | cleanup is not directly observable | no emitted data | supplement |
| `src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c` | dormant object creation helpers | spinlock, request, outbound memory, inbound memory creation sites | no diagnostic statement | none | none | none | object stages are only inferable from return/report fields | no emitted data | supplement |
| `src/driver/ChatpadFilter/device.c` | owner initialization, pre-object validation, orchestration, structural-ready validation | sequential `EvtDeviceAdd` code | no diagnostic statement | none | none | none | not currently observable | no emitted data | supplement |
| `src/driver` tracked modern source | target/request operation families | source grep | absence of call sites | none | none | source only | proves absence of current source paths, not runtime counter evidence | no emitted data | add zero counters and final snapshots |

No current WPP, ETW, TraceLogging, Windows event-log, cleanup callback, target
operation counter, request operation counter, or runtime manifest exists in
tracked modern production source.

## 3. Instrumentation mechanism decision

Evaluated mechanisms:

| Mechanism | Assessment |
| --- | --- |
| Existing `KdPrintEx` | Lowest implementation cost and already present, but debug-print capture is filter-dependent, not a durable event catalogue, lacks stable event IDs, and cannot reliably prove loss, ordering, or structured fields. Retain as fallback only. |
| WPP software tracing | Native kernel-driver tracing pattern, works with KMDF drivers, supports Debug and Release builds, bounded macros, levels/flags, trace sessions started before load, and raw ETL preservation. It requires source/project additions and generated trace headers in a later implementation gate. |
| ETW manifest or TraceLogging | Good structured collection, but a manifest/provider pipeline is a larger change for this repository. Kernel TraceLogging support and provider registration would add more design and build surface than required for the first dormant load. |
| Windows event log reporting | Useful for coarse system evidence, but direct driver event-log writes are more invasive, less suitable for high-frequency path events, and unnecessary before package/load design. |
| Debugger-only state inspection | Can help emergency diagnosis but is not reproducible enough for first-load acceptance and can miss failure paths after device removal. |
| Combination | WPP as the primary source, existing `KdPrintEx` and Windows logs as corroborating sources. |

Decision: use **WPP software tracing as the primary mechanism** for the first
controlled load, with existing `KdPrintEx` retained as fallback. WPP provides
deterministic event names and fields in source, Release-capable collection, ETL
preservation, low per-event overhead when disabled, and pre-load session
capture. The later implementation must define stable event IDs explicitly in
the event fields and tests; event IDs must not rely on tool-generated ordinal
behavior.

Collection requirements: a trace session must be started before any future
installation or load, with the selected provider, level, flags, ETL output,
loss counters, and SHA-256 manifesting. Absence of a collector must not change
driver behavior.

The later implementation would require source and project changes, likely a
diagnostic header/source, WPP control GUID/flags, generated trace headers, and
guards. This design does not implement any of those changes.

## 4. Release-build policy

Instrumentation must exist in both Debug and Release for the intended
first-load binary. A first controlled load must not rely on Debug-only events if
the selected test binary is Release.

Compilation policy:

- default production source can include diagnostic instrumentation in Debug and
  Release when the later implementation gate enables the diagnostic feature;
- a compile-time constant must make the intended diagnostic build statically
  auditable;
- instrumentation-disabled builds must preserve the same statuses and control
  flow.

Runtime enablement policy:

- events are off unless a WPP trace session enables the provider/flags;
- disabled tracing must not bypass validation, skip failure handling, or change
  return statuses;
- event levels: error for terminal failures and invariant violations, warning
  for unexpected-but-handled states, information for normal milestones, verbose
  only for bounded snapshots;
- event keywords: driver entry, device add, owner, orchestration, readiness,
  lifecycle, cleanup, prohibited counters, invariant, terminal.

After first-load qualification, instrumentation may be retained dormant,
compiled out by an explicit audited configuration, or narrowed by a separate
decision. It must not silently disappear from the intended first-load binary.

## 5. Event naming and numbering contract

Event IDs are stable source-level semantics. They must never be reused for a
different meaning. Total designed event count: **73**.

| Range | Purpose | Events |
| --- | --- | --- |
| 1000-1099 | Driver entry and unload | 4 |
| 1100-1199 | Device add and device creation | 6 |
| 1200-1299 | Owner initialization and prevalidation | 6 |
| 1300-1399 | Orchestration | 13 |
| 1400-1499 | Structural-ready validation | 5 |
| 1500-1599 | Lifecycle initialization | 6 |
| 1600-1699 | Cleanup and rollback | 9 |
| 1700-1799 | Prohibited-operation counters and final snapshots | 14 |
| 1800-1899 | Invariant violations | 6 |
| 1900-1999 | Terminal device-add outcome | 4 |

Every later event site must define numeric ID, symbolic name, level, keyword,
emitting function, exact emission point, required fields, optional fields,
success/failure semantics, expected IRQL, frequency bound, corresponding
first-load criterion, and failure or rollback action.

## 6. Device-attempt correlation

Use a monotonically increasing 64-bit diagnostic attempt sequence for
`EvtDeviceAdd` attempts. Do not log raw `WDFDEVICE`, `WDFREQUEST`, kernel
addresses, object pointers, or private handles.

Contract:

- `DriverEntry` events use `DriverAttemptId=0`.
- `EvtDeviceAdd` allocates the next attempt ID before `WdfDeviceCreate`.
- The attempt ID is stored in the device context after `WdfDeviceCreate`
  succeeds.
- Events before `WDFDEVICE` exists carry the local attempt ID.
- If `WdfDeviceCreate` fails, the attempt ID exists only in the event stream.
- Thread safety requires an interlocked increment on a nonpaged global counter.
- Wraparound is terminally detected and logged as an invariant event; no
  wraparound is expected during first-load testing.
- A future safe device-instance hash may be added only after a separate
  read-only identity-capture gate. It is not part of this design's required
  fields.

## 7. Required event catalogue

Required fields common to all events: `EventId`, `EventName`, `AttemptId`,
`Level`, `Keyword`, `NtStatusClass` where applicable, source component version,
and monotonically increasing per-attempt event sequence when a device context
exists.

| ID | Name | Level | Keyword | Emitting function | Exact emission point | Required fields | Semantics |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1000 | DRIVER_ENTRY_STARTED | Info | DriverEntry | `DriverEntry` | first statement | none beyond common | driver entry reached |
| 1001 | WDF_DRIVER_CREATE_ATTEMPTED | Info | DriverEntry | `DriverEntry` | immediately before `WdfDriverCreate` | none | framework driver creation attempted |
| 1002 | WDF_DRIVER_CREATE_FAILED | Error | DriverEntry | `DriverEntry` | failure branch | returned `NTSTATUS` | terminal driver-entry failure |
| 1003 | DRIVER_ENTRY_COMPLETED | Info | DriverEntry | `DriverEntry` | before return | returned `NTSTATUS` | driver entry completed |
| 1100 | DEVICE_ADD_ENTERED | Info | DeviceAdd | `ChatpadEvtDeviceAdd` | first executable statement | attempt ID | device-add reached |
| 1101 | DEVICE_CREATE_ATTEMPTED | Info | DeviceAdd | `ChatpadEvtDeviceAdd` | before `WdfDeviceCreate` | attempt ID | device/context creation attempted |
| 1102 | DEVICE_CREATE_FAILED | Error | DeviceAdd | `ChatpadEvtDeviceAdd` | failure branch | `NTSTATUS` | no device context created |
| 1103 | DEVICE_CONTEXT_INITIALIZING | Info | DeviceAdd | `ChatpadEvtDeviceAdd` | after `WdfDeviceCreate`, before scalar context setup | context version constants only | context initialization began |
| 1104 | DEVICE_CONTEXT_READY | Info | DeviceAdd | `ChatpadEvtDeviceAdd` | after scalar context setup | signature/version status | context initialized |
| 1105 | DEVICE_CREATE_COMPLETED | Info | DeviceAdd | `ChatpadEvtDeviceAdd` | after context stored | `NTSTATUS=STATUS_SUCCESS` | device/context creation succeeded |
| 1200 | OWNER_STORAGE_INIT_STARTED | Info | Owner | `ChatpadEvtDeviceAdd` | before initializer call | object-presence snapshot | owner init started |
| 1201 | OWNER_STORAGE_INIT_COMPLETED | Info | Owner | `ChatpadEvtDeviceAdd` | after initializer success | storage result | owner init completed |
| 1202 | OWNER_STORAGE_INIT_FAILED | Error | Owner | `ChatpadEvtDeviceAdd` | after initializer failure | storage result, mapped status | terminal owner init failure |
| 1203 | PRE_OBJECT_VALIDATION_STARTED | Info | Owner | `ChatpadEvtDeviceAdd` | before prevalidation | snapshot | validation started |
| 1204 | PRE_OBJECT_VALIDATION_FAILED | Error | Owner | `ChatpadEvtDeviceAdd` | failure branch | validation result, invariant mask class | terminal prevalidation failure |
| 1205 | PRE_OBJECT_VALIDATION_COMPLETED | Info | Owner | `ChatpadEvtDeviceAdd` | after success | validation result | prevalidation passed |
| 1300 | ORCHESTRATION_STARTED | Info | Orchestration | `ChatpadEvtDeviceAdd` | before orchestrator call | pre-orchestration snapshot | production orchestration began |
| 1301 | ORCHESTRATION_STAGE_ENTERED | Verbose | Orchestration | orchestrator | each stage boundary | stage enum | bounded stage progress |
| 1302 | ORCHESTRATION_STAGE_COMPLETED | Verbose | Orchestration | orchestrator | each stage success | stage enum, snapshot | bounded stage success |
| 1303 | ORCHESTRATION_RETURNED | Info | Orchestration | `ChatpadEvtDeviceAdd` | immediately after call | function result, report result | orchestrator returned |
| 1304 | ORCHESTRATION_FUNCTION_RESULT | Info/Error | Orchestration | `ChatpadEvtDeviceAdd` | after return | function result enum | function result captured |
| 1305 | ORCHESTRATION_REPORT_RESULT | Info/Error | Orchestration | `ChatpadEvtDeviceAdd` | after report validation | report result enum | report result captured |
| 1306 | ORCHESTRATION_FUNCTION_REPORT_MATCHED | Info | Orchestration | `ChatpadEvtDeviceAdd` | equality branch | result enum | equality confirmed |
| 1307 | ORCHESTRATION_FUNCTION_REPORT_MISMATCH | Error | Orchestration | `ChatpadEvtDeviceAdd` | mismatch branch | both result enums | terminal mismatch |
| 1308 | ORCHESTRATION_REPORT_SUMMARY | Info/Error | Orchestration | `ChatpadEvtDeviceAdd` | before status mapping | bounded report schema | terminal orchestration summary |
| 1309 | ORCHESTRATION_STATUS_MAPPED | Info/Error | Orchestration | `ChatpadEvtDeviceAdd` | after mapping | result enum, status class | mapped `NTSTATUS` |
| 1310 | ORCHESTRATION_UNEXPECTED_ENUM | Error | Orchestration | mapping/report helpers | default/unrecognized path | enum family, value class | taxonomy defect |
| 1311 | ORCHESTRATION_READY_PUBLISHED | Info | Orchestration | orchestrator | after ready publish | ready flags | owner-ready attempted |
| 1312 | ORCHESTRATION_TERMINAL_CATEGORY | Info/Error | Orchestration | `ChatpadEvtDeviceAdd` | after report summary | terminal category | audit-friendly classification |
| 1400 | READY_VALIDATION_STARTED | Info | Readiness | `ChatpadEvtDeviceAdd` | before structural-ready validation | snapshot | structural check started |
| 1401 | READY_VALIDATION_PASSED | Info | Readiness | `ChatpadEvtDeviceAdd` | after success | snapshot | structural ready passed |
| 1402 | READY_VALIDATION_FAILED | Error | Readiness | `ChatpadEvtDeviceAdd` | failure branch | missing-object class, status | terminal structural failure |
| 1403 | READY_VALIDATION_MISSING_OBJECT | Error | Readiness | validation helper | specific missing flag | object flags | object graph incomplete |
| 1404 | READY_VALIDATION_INVARIANT_FAILED | Error | Readiness | validation helper | invariant failure | validation result class | structural invariant failure |
| 1500 | LIFECYCLE_INIT_STARTED | Info | Lifecycle | `ChatpadEvtDeviceAdd` | before lifecycle init | none | lifecycle reached |
| 1501 | LIFECYCLE_INIT_PASSED | Info | Lifecycle | `ChatpadEvtDeviceAdd` | after success | lifecycle result | lifecycle initialized |
| 1502 | LIFECYCLE_INIT_FAILED | Error | Lifecycle | `ChatpadEvtDeviceAdd` | after failure | lifecycle result, status | terminal lifecycle failure |
| 1503 | MARK_DEVICE_CREATED_STARTED | Info | Lifecycle | `ChatpadEvtDeviceAdd` | before mark call | lifecycle snapshot | mark started |
| 1504 | MARK_DEVICE_CREATED_PASSED | Info | Lifecycle | `ChatpadEvtDeviceAdd` | after success | lifecycle snapshot | device-created mark passed |
| 1505 | MARK_DEVICE_CREATED_FAILED | Error | Lifecycle | `ChatpadEvtDeviceAdd` | after failure | lifecycle result, snapshot | terminal mark failure |
| 1600 | ROLLBACK_STARTED | Warning | Cleanup | orchestrator | before rollback helper | reason, object snapshot | partial rollback began |
| 1601 | ROLLBACK_REASON | Warning | Cleanup | orchestrator | rollback start | terminal category | rollback reason |
| 1602 | ROLLBACK_OBJECT_SNAPSHOT_BEFORE | Info | Cleanup | rollback helper | before deletions | object flags | pre-delete snapshot |
| 1603 | ROLLBACK_COMPLETED | Info/Error | Cleanup | rollback helper | after rollback helper | rollback result, effects | rollback result |
| 1604 | ROLLBACK_OBJECT_SNAPSHOT_AFTER | Info | Cleanup | rollback helper | after state update | object flags | post-delete state |
| 1605 | DEVICE_CONTEXT_CLEANUP_ENTERED | Info | Cleanup | future cleanup callback | callback entry | attempt ID, object flags | device cleanup reached |
| 1606 | DEVICE_CONTEXT_CLEANUP_SNAPSHOT | Info | Cleanup | future cleanup callback | after snapshot | object flags, counters | cleanup state |
| 1607 | DEVICE_CONTEXT_CLEANUP_COMPLETED | Info | Cleanup | future cleanup callback | callback exit | final object flags | cleanup completed |
| 1608 | CLEANUP_INVARIANT_VIOLATION | Error | Cleanup | rollback/cleanup | invariant failure | violation class | cleanup defect |
| 1700 | PROHIBITED_COUNTERS_INITIALIZED | Info | Counters | `ChatpadEvtDeviceAdd` | before owner init | all counters | counters start zero |
| 1701 | TARGET_DISCOVERY_COUNTER_NONZERO | Error | Counters | future target boundary | increment site | counter value | prohibited operation |
| 1702 | TARGET_OPEN_COUNTER_NONZERO | Error | Counters | future target boundary | increment site | counter value | prohibited operation |
| 1703 | TARGET_ASSIGNMENT_COUNTER_NONZERO | Error | Counters | future target boundary | increment site | counter value | prohibited operation |
| 1704 | REQUEST_FORMAT_COUNTER_NONZERO | Error | Counters | future request boundary | increment site | counter value | prohibited operation |
| 1705 | REQUEST_REUSE_COUNTER_NONZERO | Error | Counters | future request boundary | increment site | counter value | prohibited operation |
| 1706 | REQUEST_SEND_COUNTER_NONZERO | Error | Counters | future request boundary | increment site | counter value | prohibited operation |
| 1707 | COMPLETION_COUNTER_NONZERO | Error | Counters | future completion boundary | increment site | counter value | prohibited operation |
| 1708 | CANCELLATION_COUNTER_NONZERO | Error | Counters | future cancellation boundary | increment site | counter value | prohibited operation |
| 1709 | PROTOCOL_TRAFFIC_COUNTER_NONZERO | Error | Counters | future protocol boundary | increment site | counter value | prohibited operation |
| 1710 | KEYBOARD_INJECTION_COUNTER_NONZERO | Error | Counters | future presentation boundary | increment site | counter value | prohibited operation |
| 1711 | D0_OWNER_OBSERVER_COUNTER_NONZERO | Error | Counters | future D0 owner boundary | increment site | counter value | prohibited operation |
| 1712 | REMOVAL_RUNDOWN_COUNTER_NONZERO | Error | Counters | future removal boundary | increment site | counter value | prohibited operation |
| 1713 | PROHIBITED_COUNTERS_FINAL_SNAPSHOT | Info/Error | Counters | terminal and cleanup paths | final/callback | all counters | zero proof or stop |
| 1800 | ATTEMPT_ID_WRAPAROUND | Error | Invariant | attempt allocator | wrap detected | previous value | instrumentation invariant |
| 1801 | EVENT_SEQUENCE_GAP_DETECTED | Error | Invariant | final validation | sequence mismatch | expected/actual class | trace/control defect |
| 1802 | UNEXPECTED_STATUS_MAPPING | Error | Invariant | mapping helper | default or contradiction | result/status class | taxonomy defect |
| 1803 | OBJECT_SNAPSHOT_INCONSISTENT | Error | Invariant | snapshot helper | impossible flags | object flags | state defect |
| 1804 | COUNTER_OVERFLOW | Error | Invariant | counter increment helper | overflow | counter ID | counter defect |
| 1805 | TRACE_SCHEMA_VERSION_MISMATCH | Error | Invariant | init/final | schema version | collection/parser defect |
| 1900 | DEVICE_ADD_SUCCESS | Info | Terminal | `ChatpadEvtDeviceAdd` | final success return | final status, summary | load criterion success |
| 1901 | DEVICE_ADD_FAILURE | Error | Terminal | every failure return | final status, reason | terminal failure |
| 1902 | DEVICE_ADD_FINAL_SUMMARY | Info/Error | Terminal | before every return and cleanup | report, snapshot, counters | audit summary |
| 1903 | DEVICE_ADD_RETURNED_STATUS | Info/Error | Terminal | immediately before return | returned `NTSTATUS` | exact return proof |

## 8. Prohibited-operation counters

Counters are required for target discovery, target open, target assignment,
request formatting, request reuse, request send, completion, cancellation,
protocol traffic, keyboard injection, D0 owner observation, and removal-rundown
observation.

Design:

- storage location: future per-device diagnostic state embedded in the device
  context; a local zero snapshot is used before `WdfDeviceCreate` succeeds;
- initialization: all counters set to zero before owner initialization;
- atomicity: interlocked increments if future operation sites can occur
  outside the serialized device-add path;
- update sites: only real future operation boundaries may increment counters;
- overflow: saturate at max value, emit `COUNTER_OVERFLOW`, and treat as a
  terminal instrumentation defect;
- invariant behavior: any nonzero value during first-load observation emits the
  corresponding `*_COUNTER_NONZERO` event and forces stop/rollback;
- final snapshot: emitted on every terminal `EvtDeviceAdd` path and again at
  cleanup.

For operation families that do not yet exist in production source, runtime
counter proof means: zero-initialized counters plus final zero snapshot plus
static source/binary guard proving no increment-capable operation boundary was
introduced. It does not falsely claim interception of nonexistent code.

## 9. Object-presence snapshot

Object snapshots use only Boolean/enumerated fields:

- `BookkeepingLockPresent`;
- `ReusableRequestPresent`;
- `OutboundMemoryPresent`;
- `InboundMemoryPresent`;
- `OwnerInitializationMaskClass`;
- `OwnerReadyFlag`;
- `FaultedFlag`;
- `ObjectGraphCompleteFlag`;
- `StructuralReadyResultClass`.

No handles, pointers, buffer contents, protocol payloads, or memory addresses
may be logged.

Snapshot points: before orchestration, after orchestration success, after
orchestration failure, before rollback, after rollback, before structural-ready
validation, after structural-ready validation, terminal outcome, and device
cleanup.

## 10. Orchestration-report event schema

Safe report schema:

- function result enum;
- report result enum;
- terminal stage enum;
- failed stage enum;
- object-presence flags;
- rollback attempted flag;
- rollback completed flag;
- first failure class;
- mapped `NTSTATUS` class;
- mismatch flag;
- ready attempted/published flags;
- object graph complete flag;
- final initialization-mask class.

The later implementation must initialize an emission structure explicitly before
use. It must not log raw structures, uninitialized padding, pointers, WDF
handles, source/destination buffers, USB payloads, or Chatpad payloads.

## 11. Failure-path coverage

| Failure | Entry event | Failure event | Cleanup event | Final event | Snapshot | Expected status | Rollback consequence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Device creation failure | 1100/1101 | 1102 | none; no device context | 1901/1903 | no WDF device | framework status | stop before bind/load retry |
| Owner prevalidation failure | 1203 | 1204 | 1605-1607 if WDF cleanup occurs | 1901/1903 | no child objects | `STATUS_INVALID_DEVICE_STATE` | device-level rollback if bound |
| Spinlock creation failure | 1300/1301 | 1308/1309 | 1605-1607 if WDF cleanup occurs | 1901/1903 | no child object or faulted owner | framework status or invalid state | rollback level 2/4 |
| Request creation failure | 1301/1302 | 1308/1309 | 1600-1604, then cleanup | 1901/1903 | lock before, none after rollback | framework status or invalid state | rollback level 2/4 |
| Outbound memory failure | 1301/1302 | 1308/1309 | 1600-1604, then cleanup | 1901/1903 | lock/request before, none after | framework status or invalid state | rollback level 2/4 |
| Inbound memory failure | 1301/1302 | 1308/1309 | 1600-1604, then cleanup | 1901/1903 | lock/request/outbound before, none after | framework status or invalid state | rollback level 2/4 |
| Rollback failure or inconsistency | 1600/1602 | 1603/1608 | 1605-1607 if available | 1901/1903 | partial or inconsistent | `STATUS_INVALID_DEVICE_STATE` | escalate rollback hierarchy |
| Function/report mismatch | 1303 | 1307 | 1605-1607 if WDF cleanup occurs | 1901/1903 | final report snapshot | `STATUS_INVALID_DEVICE_STATE` | no second load attempt |
| Structural-ready failure | 1400 | 1402/1403/1404 | 1605-1607 if WDF cleanup occurs | 1901/1903 | graph state | `STATUS_INVALID_DEVICE_STATE` | no second load attempt |
| Lifecycle initialization failure | 1500 | 1502 | 1605-1607 | 1901/1903 | full graph parented | mapped lifecycle status | rollback/restoration required |
| Mark-device-created failure | 1503 | 1505 | 1605-1607 | 1901/1903 | lifecycle snapshot | mapped lifecycle status | rollback/restoration required |
| Unexpected status mapping | mapping entry | 1802 | terminal summary | 1901/1903 | relevant state | `STATUS_INVALID_DEVICE_STATE` | stop |
| Unexpected enum value | report/mapping entry | 1310 | terminal summary | 1901/1903 | report class | `STATUS_INVALID_DEVICE_STATE` | stop |
| Cleanup invariant violation | cleanup entry | 1608 | 1607 if possible | 1901/1902 | cleanup snapshot | unchanged return or failure if in active path | escalate |

## 12. Success-path event sequence

Strict order for one successful dormant first load:

1. `DRIVER_ENTRY_STARTED`
2. `WDF_DRIVER_CREATE_ATTEMPTED`
3. `DRIVER_ENTRY_COMPLETED`
4. `DEVICE_ADD_ENTERED`
5. `DEVICE_CREATE_ATTEMPTED`
6. `DEVICE_CREATE_COMPLETED`
7. `OWNER_STORAGE_INIT_COMPLETED`
8. `PRE_OBJECT_VALIDATION_COMPLETED`
9. `ORCHESTRATION_STARTED`
10. `ORCHESTRATION_RETURNED`
11. `ORCHESTRATION_FUNCTION_REPORT_MATCHED`
12. `READY_VALIDATION_PASSED`
13. `LIFECYCLE_INIT_PASSED`
14. `MARK_DEVICE_CREATED_PASSED`
15. `PROHIBITED_COUNTERS_FINAL_SNAPSHOT` with all counters zero
16. `DEVICE_ADD_SUCCESS`
17. `DEVICE_ADD_RETURNED_STATUS`

Verbose stage events may occur between orchestration start and return. Windows,
framework, and existing debug-print events may interleave externally, but
per-attempt event sequence values must remain monotonic.

## 13. Failure-path event sequences

- First WDF-object creation failure: device-add entry, device create completed,
  owner/prevalidation completed, orchestration started, spinlock stage entered,
  orchestration returned failure, report summary, final prohibited counters,
  device-add failure, returned status.
- Failure after one object exists: stage success for spinlock, next stage
  failure, rollback started, before/after snapshot, rollback completed, final
  failure.
- Failure after multiple objects exist: stage success events through the last
  successful object, failure event, rollback with represented request/memory
  flags, final failure.
- Report/function mismatch: orchestration returned, function result, report
  result, mismatch event, final failure.
- Structural-ready failure: orchestration success, ready validation started,
  ready failure classification, final failure.
- Lifecycle failure: ready validation passed, lifecycle start, lifecycle
  failure or mark-device-created failure, final failure.
- Cleanup invariant violation: cleanup entered, snapshot, invariant violation,
  cleanup completed if possible, final trace classified inconclusive unless the
  terminal summary was already preserved.

These sequences distinguish failure before object creation, partial
construction followed by rollback, full construction followed by validation
failure, lifecycle failure after structural readiness, and unexpected missing
cleanup.

## 14. Cleanup observability

Future instrumentation should add a device-context cleanup callback only for
diagnostic snapshots; it must not change WDF ownership. Child-object cleanup
callbacks are optional and higher risk because they widen object definitions.
The minimum design uses:

- rollback helper events for explicit partial deletion;
- post-delete object-state updates already present in the rollback helper;
- a device-context cleanup callback to snapshot final owner flags and counters;
- WDF parent-child cleanup as the authoritative success-path cleanup model.

Required proof:

- partial objects deleted during rollback: `ROLLBACK_OBJECT_SNAPSHOT_BEFORE`,
  `ROLLBACK_COMPLETED`, and `ROLLBACK_OBJECT_SNAPSHOT_AFTER`;
- full graph remained parented on success: success object snapshot plus no
  rollback event before terminal success;
- device destruction cleaned child objects after failure: cleanup entered,
  cleanup snapshot, cleanup completed;
- no double-delete: rollback effect flags plus final object flags;
- no object remained marked present after deletion: after-rollback snapshot.

Do not introduce new manual deletion where WDF parent cleanup is already
authoritative unless a separate implementation design justifies it.

## 15. Assertions versus telemetry

Telemetry records what happened; it does not replace failure handling.

- Debug assertions: allowed only as local developer diagnostics and never the
  only proof in the first-load binary.
- Checked-build assertions: allowed for impossible-by-design conditions, but
  paired telemetry is still required.
- Runtime telemetry: required for first-load evidence in Debug and Release.
- Terminal failure logic: existing return-status behavior remains
  authoritative.

Invariant violations that affect correctness emit an error event and return
failure. Nonterminal collection issues emit warning/error telemetry and mark
the trace inconclusive. Purely impossible-by-design states may assert in Debug
but must still have a guard or event path for Release.

## 16. IRQL and concurrency contract

Expected emission sites are `DriverEntry`, `EvtDeviceAdd`, WDF object creation
helpers, rollback helper, lifecycle initialization path, PnP/power callbacks,
and future cleanup callback. These paths are expected at `PASSIVE_LEVEL` unless
later source inspection proves otherwise; the implementation must assert or
guard the IRQL assumption.

Rules:

- no blocking while holding the owner spinlock;
- no new locks solely for logging;
- no waitable operations in non-waitable paths;
- no allocation dependency on critical failure paths where avoidable;
- bounded formatting only;
- WPP macro usage must be valid at the expected IRQL;
- ordering is strict only within one attempt sequence, not across CPUs or
  separate devices.

Current dormant object creation does not hold the created spinlock during
logging sites. Future operation-boundary counters must not alter request
ownership.

## 17. Performance and volume bounds

Maximum normal volume:

- `DriverEntry`: 4 events.
- Successful `EvtDeviceAdd`: no more than 45 events including stage events and
  snapshots.
- Representative partial failure: no more than 55 events.
- Cleanup callback: no more than 3 events.
- Snapshot size: fixed scalar fields only, target under 128 bytes.
- String length: event names from catalogue only; no variable device path
  strings in first-load instrumentation.

No loops may emit unbounded events. Per-byte, per-packet, USB report, Chatpad
report, or protocol payload logging is prohibited.

## 18. Data minimization

Prohibited fields:

- raw hardware serial numbers unless explicitly authorized later;
- account or user identity;
- raw device paths when a bounded hash is sufficient;
- kernel addresses;
- WDF handles;
- pointers;
- memory contents;
- USB reports;
- Chatpad reports;
- keystrokes;
- keys, certificates, passwords, or tokens;
- environment secrets.

Allowed fields are bounded enums, Boolean flags, `NTSTATUS` values or classes,
small counters, attempt IDs, sequence numbers, schema version, and later
device-identity hashes only after a separate identity gate. Redaction policy:
prefer omission; if identity is required later, hash with a documented stable
method and record the hash input class separately.

## 19. Debug and Release equivalence

Later offline tests must prove instrumentation does not change core behavior in
Debug or Release:

- status mapping;
- orchestration call count;
- object creation order;
- rollback order;
- lifecycle reachability;
- target/request absence;
- binary imports;
- WDF references;
- event-catalogue consistency;
- counter initialization;
- counter final snapshots.

Instrumentation-specific binary differences are expected. Behavioral control
flow must remain equivalent when tracing is disabled and when a collector is
absent.

## 20. Compile-time and runtime controls

Future controls:

- compile-time diagnostic feature constant;
- WPP provider flags/keywords;
- WPP level;
- runtime tracing session;
- optional diagnostic-build property.

Requirements:

- tracing disabled must not bypass validation;
- tracing disabled must not change statuses;
- tracing failure must not change driver behavior;
- absence of a collector must not fail device creation;
- instrumentation must not silently disappear from the intended first-load
  binary;
- binary/static evidence must prove the intended instrumentation is present.

This task does not implement project properties.

## 21. Static verification requirements

Future guards must verify:

- complete event-ID set;
- no duplicate event IDs;
- required event sites;
- no raw pointer formatting;
- no payload logging;
- no target/request operation introduction;
- no status-path changes;
- no logging while prohibited locks are held;
- bounded field lengths;
- prohibited-operation counter initialization;
- final zero snapshot;
- Debug/Release event-catalogue equality;
- expected WPP provider imports or metadata;
- absence of unauthorized providers or event channels.

## 22. Offline test plan

Future tests, without implementation in this task:

| Test | Surface |
| --- | --- |
| Event catalogue parser | documentation and diagnostic header |
| Unique-ID test | diagnostic header/source |
| Required-site source guard | production source |
| Event-field schema guard | diagnostic schema |
| Raw-pointer format rejection | diagnostic source |
| Prohibited-data-field rejection | diagnostic source |
| Orchestration-success synthetic test | compile-only KMDF context or source-level harness |
| Each orchestration-failure synthetic test | compile-only KMDF context or source-level harness |
| Rollback sequence test | compile-only KMDF context |
| Report/function mismatch test | source-level or unit harness |
| Structural-ready failure test | source-level or unit harness |
| Lifecycle failure test | pure lifecycle model plus call-site guard |
| Counter nonzero invariant test | pure diagnostic helper |
| Cleanup sequence test | source-level cleanup helper guard |
| Event-order test | generated catalogue and synthetic traces |
| Debug/Release catalogue comparison | build artifacts |
| Instrumentation-disabled behavior comparison | build/test matrix |
| Target/request-absence regression | source and binary guard |

Pure-model tests can cover counter helpers, event catalogue parsing, lifecycle
classification, and ordering rules. Compile-only KMDF context is needed for WDF
object-stage and rollback call-site evidence.

## 23. Runtime trace collection design

Future collection, not executed here:

- start trace session before installation or load;
- provider identity: project WPP provider selected by future implementation;
- level: information plus error/warning; verbose stage events enabled for the
  first controlled load;
- keywords: driver entry, device add, owner, orchestration, readiness,
  lifecycle, cleanup, counters, invariant, terminal;
- output: raw ETL under ignored `artifacts/` with timestamped directory;
- rotation/maximum size: bounded session size selected before load;
- timestamps: ETW timestamps plus external command timestamps;
- event-loss detection: trace controller loss counters and sequence checks;
- stop session after rollback/restoration evidence is captured;
- preserve raw ETL and converted text/CSV if conversion is used;
- SHA-256 manifest raw and converted artifacts;
- correlate with SetupAPI, System, Kernel-PnP, SCM, WDF, and crash evidence.

Failed load evidence is expected from pre-started ETW/WPP session, Windows logs,
SetupAPI, crash dump if any, and the last terminal or missing-terminal trace
classification.

## 24. First-load evidence interpretation

Proof combinations:

- device-add entry: `DEVICE_ADD_ENTERED` with valid attempt ID.
- successful object graph: orchestration success events, ready-published event,
  object snapshot with all four object flags present.
- orchestration failure and rollback: orchestration failure summary plus
  rollback start/completion and after snapshot.
- structural-ready success: `READY_VALIDATION_PASSED`.
- lifecycle reachability: lifecycle start plus pass/fail event.
- no target/request operation: all prohibited counters initialized and final
  snapshot zero, plus static guard for no operation sites.
- complete cleanup: cleanup entered, snapshot, completed, and no invariant
  violation.
- final success: terminal success, returned `STATUS_SUCCESS`, zero prohibited
  counters.
- final failure: terminal failure and returned status with failure class.

Invalid or inconclusive traces:

- missing terminal event;
- event loss reported by the trace session;
- duplicate attempt IDs;
- impossible event order;
- missing cleanup event after failure that should destroy a device context;
- nonzero prohibited counter;
- trace session beginning too late;
- provider unavailable;
- event schema mismatch;
- final summary absent.

## 25. Runtime go/no-go effect

Instrumentation implementation and its independent offline audit must pass
before device identity capture may be considered, signing design may proceed,
package construction may proceed, or staging/loading may be authorized. This
design itself does not advance any of those gates.

## 26. Future instrumentation implementation scope

Potential later paths may include:

- production driver source containing `DriverEntry`;
- `src/driver/ChatpadFilter/device.c`;
- request-owner context implementation;
- lifecycle implementation;
- new diagnostic header/source;
- project tracing configuration;
- generated tracing files;
- source guards;
- pure-model tests;
- documentation and evidence manifest.

This design does not decide that every path must change. The later
implementation task must justify each changed path.

## 27. Future instrumentation acceptance criteria

A later implementation may pass offline review only when:

- all designed events exist;
- all event IDs are unique;
- all required fields are present;
- no prohibited data is logged;
- instrumentation compiles in intended configurations;
- existing regressions pass;
- no target/request operation is introduced;
- source control flow remains equivalent;
- failure and rollback sequences are testable;
- static binary evidence confirms instrumentation presence;
- event volume is bounded;
- tracing failure is behavior-neutral;
- source and binary evidence is independently audited.

## 28. Design risks

| Risk | Mitigation |
| --- | --- |
| Instrumentation changes timing | Keep events bounded, disabled by default, and behavior-neutral; compare control flow offline |
| Logging from failure paths allocates memory | Use WPP macros with bounded scalar fields; avoid dynamic strings |
| Lost events | Pre-start trace session, capture loss counters, use per-attempt sequence |
| Trace session starts too late | Require session start before install/load |
| Logging while locks are held | Guard source sites and prohibit logging under owner spinlock |
| Event schema drift | Static catalogue parser and schema-version event |
| Release instrumentation accidentally disabled | Static binary identity and Debug/Release catalogue comparison |
| Excessive logging | Fixed maximum event counts and no per-byte/per-packet logs |
| Sensitive device data exposed | Data minimization and no raw IDs before identity gate |
| Missing events mistaken for proof of absence | Treat missing terminal/final snapshot as inconclusive |
| Cleanup events lost during destruction | Emit rollback events before deletion and cleanup summary at callback entry |
| Counters give false assurance for nonexistent operation sites | Pair zero counters with source/binary absence guards |

## 29. Explicit design verdict

**INSTRUMENTATION DESIGN READY FOR OFFLINE IMPLEMENTATION.**

Exact next task:

`Implement the accepted diagnostic instrumentation offline, with no signing,
installation, loading, device query, target discovery, request execution, or
hardware interaction.`
