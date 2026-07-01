# Windows 11 First Runtime Observation and Recovery Plan

## 1. Purpose and status

Offline production WDF-object integration is accepted at commit
`4c84891ca24ef969664f53fd5e9ec2a697f2edb9` after the independent audit result
`AUDIT PASS WITH LIMITATIONS`.

The driver has never been loaded. Runtime behavior remains unqualified. This
document defines future safety, observation, rollback, and evidence gates only.
Creating this document does not authorize signing, packaging, staging,
installation, loading, hardware observation, device mutation, target discovery,
or request execution.

Accepted frozen checkpoint:

| Item | Accepted state |
| --- | --- |
| Commit | `4c84891ca24ef969664f53fd5e9ec2a697f2edb9` |
| Production orchestration source | Accepted |
| Offline builds | Accepted |
| Regressions | Accepted |
| Evidence manifest | Accepted, schema `1.6.0`, 102 entries |
| Production runtime execution | Not performed |
| Signing | Not performed |
| Installation | Not performed |
| Hardware validation | Not performed |

## 2. Runtime scope of the current implementation

Source inspection of `src/driver/ChatpadFilter/device.c`,
`src/driver/ChatpadFilter/driver.c`,
`src/driver/ChatpadFilter/ChatpadFilterLifecycle.c`, and
`src/driver/ChatpadKmdfRequestOwnerContext/ChatpadKmdfRequestOwnerContext.c`
shows that a future load would attempt the following only if Windows binds the
driver and calls `EvtDeviceAdd`:

- `DriverEntry` would call `WdfDriverCreate`.
- `ChatpadEvtDeviceAdd` would execute.
- The driver would mark the device as a filter with `WdfFdoInitSetFilter`.
- PnP/power callbacks would be registered.
- `WdfDeviceCreate` would create the WDF device object and device context.
- The embedded request owner would be initialized.
- Explicit pre-object validation would run.
- The dormant WDF object graph would be created through
  `ChatpadKmdfRequestOwnerCreateDormantObjectGraph`.
- One spinlock would be created with `WdfSpinLockCreate`.
- One reusable, targetless request would be created with `WdfRequestCreate`.
- Outbound and inbound preallocated memory objects would be created with
  `WdfMemoryCreatePreallocated`.
- Structural-ready validation would run.
- Lifecycle initialization and mark-device-created would follow only after
  successful orchestration and structural-ready validation.

The current production source would not perform:

- target discovery;
- target open;
- request target assignment;
- request formatting;
- request reuse;
- request send;
- completion routine registration or completion processing;
- cancellation;
- Chatpad protocol traffic;
- keyboard input injection;
- D0 owner observer activity;
- removal rundown observer activity.

These are source-proven negatives, not runtime-proven negatives.

## 3. Current observability assessment

The current source has `KdPrintEx` at `DriverEntry`, `EvtDeviceAdd`,
`WdfDeviceCreate` failure, and lifecycle callback logging. It does not expose a
durable runtime event for every orchestration report field or every cleanup
decision. Existing Windows mechanisms may also record service, PnP, framework,
device status, and crash evidence when a future authorized load occurs.

| Runtime item | Current observability | Current evidence source |
| --- | --- | --- |
| Driver service load result | Directly observable using existing Windows evidence | Service Control Manager events, System log, loader/signing status, and service state after a future authorized load |
| PnP binding result | Directly observable using existing Windows evidence | SetupAPI device installation logs, Kernel-PnP events, device status, problem code, and driver stack inventory |
| `EvtDeviceAdd` entry | Directly observable if kernel debugger/debug-print capture is armed | Current `KdPrintEx` string in `ChatpadEvtDeviceAdd` |
| `WdfDeviceCreate` result | Failure directly observable by current debug print; success indirectly inferable | Current error `KdPrintEx` on failure; later code path only implies success |
| Ordinary owner initialization | Not currently observable | No current runtime log or event records the result |
| Explicit pre-object validation | Not currently observable | No current runtime log or event records the result |
| Orchestration result | Not currently observable | Report remains stack-local and is not emitted |
| Report/function mismatch | Not currently observable | Mismatch returns `STATUS_INVALID_DEVICE_STATE` without a distinct event |
| Structural-ready validation | Not currently observable | Failure returns status without a distinct event |
| Lifecycle initialization | Indirectly inferable | Lifecycle `KdPrintEx` after initialization/mark-device-created reports one result value, but not the preceding orchestration report |
| Mark-device-created result | Indirectly inferable | Same lifecycle print reports the combined lifecycle result |
| Failed-device destruction | Indirectly inferable | WDF framework cleanup may be inferred from failed `EvtDeviceAdd`; no project-specific event proves it |
| WDF hierarchy cleanup | Indirectly inferable | Request-parented memory and device/request parentage imply framework cleanup, but no emitted cleanup event proves it |
| Absence of target/request activity | Source-proven only; not currently runtime-observable | Current modern source has no tracked WdfIoTarget, WdfRequestFormat, WdfRequestReuse, WdfRequestSend, completion, or cancellation call sites under `src/` |

Do not claim that WDF framework event detail is available until the future
runtime plan selects and arms a concrete WDF logging mechanism. Do not treat
legacy source diagnostics as current production observability.

## 4. Observability-gap decision

**CURRENT BUILD IS NOT SUFFICIENTLY OBSERVABLE FOR FIRST CONTROLLED LOAD.**

Minimum evidence required for a first controlled load:

| Required proof | Current state |
| --- | --- |
| `EvtDeviceAdd` was reached | Possible only if debug-print capture is armed |
| Orchestration succeeded or failed | Not currently provable |
| Structural ready was reached or not reached | Not currently provable |
| Lifecycle initialization was reached or not reached | Only partially inferable |
| No target/request operation occurred | Source-proven, not runtime-proven |
| Cleanup occurred after failure | Only inferable from framework behavior |
| No unintended device stack was affected | Requires future device-identity and post-state evidence |

A separately authorized offline instrumentation phase is required before any
signing, package construction, staging, installation, or loading. Loading must
not be used as the method to discover whether observability is adequate.

## 5. Gate model

No gate may be combined with a later gate for convenience.

| Gate | Name | Authorization state | Scope |
| --- | --- | --- | --- |
| R0 | Accepted offline baseline | Closed and accepted | Requires commit `4c84891ca24ef969664f53fd5e9ec2a697f2edb9` |
| R1 | Documentation and observability design | This task only | Documentation-only first-runtime plan |
| R2 | Read-only environment and device-identity capture | Future separate authorization required | Identify exact controller, VID/PID, hardware IDs, compatible IDs, instance ID, topology, current service, Microsoft package, `xusb22` relationship, filters, and status; no mutation |
| R3 | Offline instrumentation, when required | Future separate source task required | Add dormant diagnostic evidence only; no target/request execution; requires build, regression, binary, provenance, and audit checkpoint |
| R4 | Signing and package design | Future separate authorization required | Documentation and offline package preparation only |
| R5 | Recovery rehearsal without installing the new driver | Future separate authorization required | Prove recovery resources and access before installation |
| R6 | Package staging | Future separate authorization required | Staging must not imply binding or loading |
| R7 | First controlled bind/load | Future explicit user authorization required | First binding/loading attempt only after prior gates pass |
| R8 | Runtime observation | Future explicit user authorization required | Limited to dormant object-graph creation |
| R9 | Rollback and recovery verification | Future explicit user authorization required | Required whether observation passes or fails |

## 6. Machine-selection requirements

A future test machine must be selected before runtime work. These requirements
are not currently satisfied by this task and must not be assumed:

- not the only available administrative machine;
- stable local console access;
- known BitLocker recovery access when applicable;
- recovery environment access;
- ability to boot Safe Mode or Windows Recovery Environment;
- tested keyboard and mouse not dependent on the target controller;
- network-independent recovery method;
- current system backup or restore strategy;
- available second computer or mobile device for instructions;
- power stability;
- no unrelated driver maintenance during the test window.

## 7. Device-identity binding requirements

Before any package is allowed to bind, future read-only evidence must record:

- hardware ID;
- compatible ID;
- device instance ID;
- container ID where applicable;
- parent instance;
- current service;
- current INF;
- current provider;
- current driver version;
- current filters;
- class;
- class GUID;
- bus;
- location path;
- Microsoft `xusb22` status.

The package must use a device-specific match. The following are prohibited:
class-wide UpperFilters, class-wide LowerFilters, broad Xbox controller
matching, broad USB class matching, replacement of all XUSB devices,
modification of Microsoft `xusb22`, and binding to an unidentified device.

## 8. INF and binding safety contract

Future package constraints:

- hardware-specific or precisely scoped extension binding;
- Microsoft driver remains the function driver where intended;
- no class-wide filter;
- no unrelated device match;
- no wildcard compatible-ID expansion without review;
- no change to unrelated controller interfaces;
- no package action before exact identity audit;
- no use of the prototype INF as production-ready without a separate audit.

The existing prototype INF is not authorized for installation merely because
offline validation passed.

## 9. Signing strategy decision points

Future signing design must decide among test signing, attestation or production
signing, and a development certificate. It must also document Secure Boot
implications, test-mode implications, timestamping, catalog identity,
certificate storage and private-key protection, and package reproducibility.

The following are prohibited without later explicit authorization: embedding
private keys in the repository; committing PFX, PVK, CER when inappropriate,
passwords, tokens, or secrets; disabling Secure Boot; enabling test signing.

## 10. Pre-install evidence bundle

Immediately before any install, a future evidence bundle must contain:

- accepted source commit;
- exact binary hashes;
- exact INF and catalog hashes;
- signing status;
- signer identity;
- package file inventory;
- target device identity;
- current Microsoft driver package identity;
- current device stack;
- current filters;
- current service status;
- current device problem code;
- recovery commands;
- rollback package identity;
- package removal command;
- emergency recovery instructions;
- timestamps;
- operator and machine identity;
- explicit go/no-go approval.

## 11. Recovery bundle

Before installation, a future recovery bundle must be created and reviewed. It
must contain only non-secret material:

- current Microsoft driver package details;
- current device identity;
- intended custom package identity;
- exact rollback sequence;
- exact package-removal sequence;
- Safe Mode procedure;
- Windows Recovery Environment procedure;
- service-disable procedure;
- offline registry recovery procedure when necessary;
- SetupAPI log collection path;
- event-log export instructions;
- dump collection instructions;
- decision tree;
- emergency stop criteria.

This task does not create or execute the recovery bundle.

## 12. Rollback hierarchy

| Level | Trigger | Prerequisites | Intended command class | Expected evidence | Success criteria | Escalation condition |
| --- | --- | --- | --- | --- | --- | --- |
| 0 - Stop before mutation | Identity, signing, package, or recovery evidence is incomplete | No mutation has occurred | No-op, documentation hold | Missing evidence recorded | No driver/package/device state changed | Any attempted mutation |
| 1 - Cancel before device bind | Package staged but no device has used it | Exact package identity and no binding evidence | Driver Store package removal class | Package inventory before/after | Custom package absent and device unchanged | Removal fails or device used package |
| 2 - Device-level rollback | Intended device bound to custom package | Prior Microsoft package and exact device identity known | Device-driver rollback/update class | Device stack, service, problem code, SetupAPI log | Intended device returns to prior Microsoft package | Device remains on custom package or problem code persists |
| 3 - Package removal | Device restored but package remains staged | Level 2 success | Driver Store removal class | Package inventory before/after | Custom package absent | Removal fails |
| 4 - Service-disable recovery | Custom service may load again | Service name and offline/online control path known | Service disable/startup-control class | Service configuration export | Custom service cannot load at next boot | Normal boot is unstable or service cannot be disabled |
| 5 - Safe Mode recovery | Normal boot available but device recovery blocked | Safe Mode access confirmed | Safe Mode device/package/service recovery class | Safe Mode logs and device/package state | Normal boot restored with Microsoft package | Safe Mode unavailable or ineffective |
| 6 - Windows Recovery Environment | Normal and Safe Mode boot not usable | Recovery key/access and offline OS volume known | WinRE offline service/registry/file recovery class | Offline registry/service/package evidence | System boots and target stack is restored or disabled | Recovery media/access failure |

Do not run or validate rollback commands in this task.

## 13. Immediate stop conditions

Future runtime work must stop immediately on:

- unexpected device match;
- unrelated controller stack change;
- Microsoft `xusb22` displacement outside the intended scope;
- class-wide filter appearance;
- Code 10, 19, 31, 32, 37, 39, 43, or another unexplained problem code;
- driver service failing to load;
- `EvtDeviceAdd` failure;
- object-graph creation failure;
- structural-ready validation failure;
- unexpected target creation or open;
- request formatting or send;
- completion or cancellation activity;
- input loss outside the intended device;
- keyboard or mouse degradation;
- system instability;
- bugcheck;
- boot degradation;
- repeated PnP restart;
- rollback command failure;
- incomplete evidence capture.

## 14. First-load success criteria

A future first controlled load may be considered successful only when evidence
proves:

- only the intended device bound;
- driver service loaded;
- `EvtDeviceAdd` completed successfully;
- dormant object graph was created;
- structural-ready validation passed;
- lifecycle initialization completed;
- no target was discovered or opened;
- no request was formatted or sent;
- no completion or cancellation occurred;
- no unrelated device changed;
- no class-wide filters appeared;
- Microsoft `xusb22` remained correctly associated;
- system remained stable;
- rollback remained available;
- post-observation rollback or restoration completed as planned.

The current build cannot prove several of these criteria at runtime. The gap is
diagnostic: the orchestration report, structural-ready reachability, cleanup
path, and target/request absence are not currently emitted as runtime evidence.

## 15. Failure evidence matrix

| Failure | Evidence source | Expected artifact | Immediate action | Rollback level | Escalation | Another runtime attempt allowed |
| --- | --- | --- | --- | --- | --- | --- |
| Package rejected | SetupAPI, package log | Rejection status and package hash | Stop | 0 or 1 | Fix offline package only | No |
| Signature rejected | SetupAPI, Code Integrity, System log | Signature/code-integrity event | Stop | 0 or 1 | Rework signing design | No |
| Staging failure | Package manager/SetupAPI | Staging transcript | Stop | 0 | Correct offline package evidence | No |
| Bind failure | SetupAPI, Kernel-PnP, device status | Bind status, device stack | Stop | 1 or 2 | Restore prior package | No |
| Service load failure | SCM/System log | Service status and error | Stop | 2 or 4 | Disable custom service | No |
| `EvtDeviceAdd` failure | Debug print, framework/PnP status | Entry marker plus failure status | Stop | 2 or 4 | Instrument offline | No |
| Object-creation failure | Instrumentation required | Stage/result/framework status | Stop | 2 or 4 | Analyze offline, then rollback | No |
| Report/result mismatch | Instrumentation required | Report result and return mismatch | Stop | 2 or 4 | Fix source offline | No |
| Structural-ready failure | Instrumentation required | Validation result | Stop | 2 or 4 | Fix source offline | No |
| Lifecycle failure | Debug print plus instrumentation | Lifecycle result and prior report | Stop | 2 or 4 | Fix source offline | No |
| Device problem code | Device Manager/PNP status | Problem code and stack | Stop | 2 | Restore Microsoft package | No |
| Bugcheck | Dump and event log | Crash dump, bugcheck code | Stop | 5 or 6 | Offline crash analysis | No |
| Boot failure | Boot/recovery evidence | Recovery transcript | Stop | 6 | WinRE recovery | No |
| Unintended device binding | Device inventory | Affected stack details | Stop | 2, 3, 5, or 6 | Remove package and restore devices | No |
| Unexpected target/request activity | Instrumentation required | Target/request event | Stop | 2 or 4 | Fix source offline | No |
| Rollback failure | Rollback transcript | Failed command/result | Stop | Next higher level | Escalate hierarchy | No |

## 16. Runtime evidence manifest design

The future runtime evidence manifest must be separate from the offline
build-evidence manifest. Suggested schema fields:

- source commit;
- package identity;
- binary hashes;
- signer;
- catalog hash;
- target device identity;
- baseline device stack;
- post-bind device stack;
- service state;
- SetupAPI evidence;
- event logs;
- framework logs;
- debugger or tracing evidence;
- orchestration outcome;
- structural-ready proof;
- lifecycle proof;
- target/request-absence proof;
- rollback result;
- final restored state;
- timestamps;
- operator declarations;
- machine identity;
- limitations.

This task creates no runtime evidence.

## 17. Instrumentation design constraints

Any later instrumentation must be:

- diagnostic-only;
- free of target discovery;
- free of request formatting or send;
- free of completion or cancellation behavior;
- behavior-preserving for success and failure paths;
- free of raw pointer, handle, private buffer, or protocol-payload logging;
- deterministic in event IDs;
- bounded in event volume;
- free of secrets;
- limited in personally identifying device data to required stable identifiers;
- explicit about Debug and Release behavior;
- separately removable or disableable;
- independently tested and audited offline before load.

## 18. First-runtime authorization template

Absence of an explicit `yes` means no authorization.

| Gate | Yes/No |
| --- | --- |
| Target machine accepted |  |
| Recovery access confirmed |  |
| Target device identity confirmed |  |
| Package scope confirmed |  |
| `xusb22` preservation confirmed |  |
| No class-wide filters confirmed |  |
| Binary hashes confirmed |  |
| Package hashes confirmed |  |
| Signer confirmed |  |
| Recovery bundle reviewed |  |
| Rollback commands reviewed |  |
| Observability sufficient |  |
| Instrumentation accepted when required |  |
| Evidence capture armed |  |
| Explicit installation approval |  |
| Explicit loading approval |  |
| Explicit hardware-interaction approval |  |

## 19. Next-task decision

Selected next task: **Option A - Offline runtime instrumentation design**.

Reason: current source cannot prove orchestration outcome, structural-ready
reachability, lifecycle reachability, cleanup, and target/request absence during
a future load. Do not select signing, package creation, staging, installation,
loading, or hardware testing as the immediate next task.
