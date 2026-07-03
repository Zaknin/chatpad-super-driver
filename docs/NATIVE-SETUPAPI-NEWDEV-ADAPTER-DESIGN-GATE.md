# Native SetupAPI/Newdev Adapter Design Gate

## Status

This document is a non-executing design and authorization gate for a future
native SetupAPI/Newdev exact-instance adapter. The current repository does not
implement, declare, load, or invoke any native device-installation API.

Authoritative current state:

- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_REAUDIT`.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live binding/restoration/restart authorization: `false`.
- Live device queries and Windows mutations performed: `0`.

The executable design contract is
`tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`. The offline G1-G67
fixtures in `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
validate this document's current gate behavior.

## Capability Boundary

Public strings, public mode fields, synthetic flags, elevation state, mutation
switches, caller-created objects, serialized records, fake adapters, and fake
wrappers are not authority. PowerShell module state is introspectable by
callers in the same process, including through `Get-Module`, session state,
module-context invocation, and function discovery. A module script-scope
object is therefore not a security boundary.

The current branch deliberately exposes no successful mutation-capability
creation path. No public or exported native adapter gate function accepts a
caller-supplied mutation capability, token, sentinel, secret, object, or
equivalent authorization value. Possession of a PowerShell object can never
activate the native mutation path. A read-only design probe is non-authorizing
metadata and cannot satisfy mutation authorization.

The current composition root is a deterministic non-executing scaffold. It
selects the production adapter identity
`chatpad-windows-exact-instance-adapter-v1` or the explicitly requested
synthetic identity `chatpad-fake-exact-instance-adapter-v1`; it does not infer
synthetic fallback. `Apply`, `Restore`, and `Restart` requests fail closed at
the native-execution gate with
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## Interface Separation

Future read-only exact-device operations are limited to:

- open one exact instance;
- retrieve the canonical identity returned by Windows;
- query device and driver state;
- enumerate candidate driver nodes for the already opened device;
- verify active driver identity;
- close owned resources.

Future mutating exact-device operations are separate:

- select one authorized driver node;
- bind the selected node to the retained exact device;
- restore the selected prior node from the authenticated snapshot;
- restart the exact device only when separately authorized.

Read-only probe metadata never implies mutation capability. Mutation
capability is not obtained by casting, changing a public mode, wrapping a fake
adapter, extracting module state, invoking in module scope, adding members,
changing `PSTypeNames`, serializing/deserializing, or passing unexpected legacy
parameters.

## Exact Device Opening

The future adapter must accept one lexically validated complete Plug and Play
instance ID. It must create one device-information set, open exactly that
instance into the set, retrieve the canonical instance ID from Windows, and
compare it with the request using the accepted case-insensitive instance-ID
rule before any driver-list or mutation work.

The same `HDEVINFO` and corresponding `SP_DEVINFO_DATA` must be retained for
the transaction. The implementation must reject zero matches, ambiguity,
replacement devices, sibling interfaces, identity drift, and any attempt to
select by hardware ID, compatible ID, class, container, friendly name, or first
enumerated result.

## Required Read-Only State

Before mutation, the future adapter must query and preserve:

- canonical instance ID;
- class GUID;
- container ID;
- parent instance;
- location paths;
- hardware IDs;
- compatible IDs;
- current device status and problem code;
- current driver service and driver key;
- published INF and original INF where resolvable;
- provider, version, and date;
- catalog or signer identity;
- current matching ID;
- current driver-node identity;
- restart or reboot state.

Unavailable properties are recorded distinctly from empty values. Property
query failure must preserve native return and Win32 error details.

## Driver-Node Enumeration

The future adapter must build the compatible driver list for the already
opened exact device element. It must enumerate every driver node, collect the
immutable driver identity, compare it to the authorized target identity, and
reject no matches or multiple matches. Provider/version-only matching,
filename-only matching, first-match fallback, and best-ranked fallback are
prohibited.

The driver list has one deterministic owner and must be destroyed exactly once.

## Exact Binding

The intended mutation sequence is:

1. Associate the exact authorized driver node with the retained exact device
   element.
2. Invoke the exact-device install function with that same device element and
   selected driver node.
3. Preserve the API result, Win32 error, and restart/reboot indication.
4. Re-query the same canonical instance.
5. Verify the complete expected driver identity.

API success alone is never success. A possible-mutation failure or failed
postcondition enters restoration-required or manual-recovery state according
to the versioned error taxonomy.

## Exact Restoration

Restoration identity is derived from the authenticated snapshot, not from a
caller-editable plan copy. Restoration must use the same canonical instance,
enumerate driver nodes for that exact device, resolve exactly the prior driver
identity, reject absence or ambiguity, avoid best-driver selection, avoid
package-wide removal, avoid remove-and-rescan behavior, and prove the
post-restoration identity.

If restoration cannot be proven, the evidence remains uncertain and manual
recovery is required.

## Native Call Specification

The executable design contract lists each intended call with DLL, Unicode
entry point, purpose, ownership, cleanup, and read-only/mutating
classification. The covered calls are:

- `SetupDiCreateDeviceInfoList`;
- `SetupDiOpenDeviceInfoW`;
- `SetupDiGetDeviceInstanceIdW`;
- SetupAPI/CfgMgr32 property/status queries;
- `SetupDiBuildDriverInfoList`;
- `SetupDiEnumDriverInfoW`;
- `SetupDiGetDriverInfoDetailW`;
- `SetupDiGetDriverInstallParamsW`;
- `SetupDiSetSelectedDriverW`;
- `DiInstallDevice`;
- postcondition property and driver identity queries;
- `SetupDiDestroyDriverInfoList`;
- `SetupDiDestroyDeviceInfoList`;
- a future exact-device restart sequence, if separately authorized.

This branch contains no executable interop declarations for those APIs.

## Native Structure Specification

The future implementation must not guess structure sizes. It must initialize
`cbSize` from the runtime marshaled structure size for `SP_DEVINFO_DATA`,
`SP_DEVINSTALL_PARAMS_W`, `SP_DRVINFO_DATA_W`, and any detail structures.
Variable-length Unicode buffers and property arrays use the documented
insufficient-buffer pattern. Win32 last-error is captured immediately before
cleanup can overwrite it.

Ownership must be explicit for device information sets, device information
elements, driver lists, allocated buffers, unmanaged strings, native
structures, last-error values, partial initialization, and cleanup exceptions.
Cleanup must be deterministic, must not leak handles, and must not destroy a
driver list twice.

## Error Taxonomy

The versioned taxonomy includes exact instance not found, canonical mismatch,
identity drift, access denied, elevation required, unsupported OS,
unsupported architecture, property unavailable, driver-list build failure,
driver-node enumeration failure, target/prior driver absence or ambiguity,
selected-driver association failure, bind failure before possible mutation,
bind failure after possible mutation, post-bind verification failure, restore
API failure, post-restore verification failure, restart required, reboot
required, cleanup failure, unexpected native exception, and uncertain device
state.

Each error maps to controlled failure, restoration required, manual recovery
required, retry prohibited, restart pending, and reboot pending fields. Native
error codes must be preserved in future evidence and never collapsed into
generic text.

## Evidence Design

Future live evidence must bind trusted producer identity, implementation
binary identity, adapter version, code or assembly hash, operation-plan hash,
canonical instance ID, target and restoration driver identities, ordered
native call log, native return codes, Win32 errors, before/after state,
restart/reboot indication, cleanup results, internal authorization provenance,
and synthetic/live classification.

For the current branch, all evidence remains synthetic. Any live-source claim
or adapter-name spoof remains invalid.

## Future Operation Gates

Before a future mutation can be considered, all of the following must pass:

1. Supported operating system and architecture.
2. No public caller-supplied mutation capability.
3. Exact canonical instance ID.
4. Valid unexpired plan.
5. Valid plan hash.
6. Valid authenticated snapshot.
7. Exact restoration identity bound to snapshot.
8. Exact target package identity.
9. Unambiguous target driver node.
10. Current state matches precondition.
11. Explicit operation authorization.
12. Elevation.
13. Mutation switch.
14. No conflicting transaction.
15. No replay.
16. No pending uncertainty requiring recovery.
17. Live evidence producer available.
18. Audit-approved implementation version.

The present implementation always remains blocked because the production
native adapter is a non-executing scaffold and no executable SetupAPI/Newdev
implementation exists.

## Offline Gate Coverage

G1-G25 prove:

- no current live capability for Apply, Restore, or Restart;
- adapter-name, mode, Boolean, elevation, mutation-switch, fake-wrapper,
  caller-object, and serialization spoofing cannot grant authority;
- read-only probe metadata is separate from mutation capability;
- no reachable current production path constructs the live capability;
- the former `Get-Module ... SessionState.PSVariable.Get(...)` sentinel
  extraction exploit cannot authorize the gate;
- module-state enumeration, module-scope `Get-Variable`, `& $module { ... }`,
  session-state invocation, and non-exported function discovery do not expose
  a mutation authorization path;
- extracted references, wrapped references, `PSCustomObject`, `PSTypeNames`,
  `Add-Member`, serialization/deserialization, strings, numbers, Booleans,
  GUID-like values, arbitrary objects, and unexpected legacy capability
  parameters are rejected or non-authorizing;
- exported mutation APIs accept no caller-supplied capability-like parameter;
- executable native declaration and invocation guards pass;
- exact API sequence, restoration linkage, uncertainty, restart/reboot, and
  evidence-origin contracts are accounted for.

G26-G67 additionally prove:

- production and synthetic adapter identities resolve only through explicit,
  deterministic selection;
- missing, unknown, or mismatched adapter selections fail closed with no
  fallback;
- recognized operations return
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED` and unsupported
  operations return `UNSUPPORTED_NATIVE_ADAPTER_OPERATION`;
- operation evidence carries the selected adapter identity, schema tag,
  current gate, and zero counters;
- production metadata states native interop, device queries, live execution,
  and Windows mutation are unavailable;
- caller objects, extracted module variables, module-context invocation,
  splatted capability-like names, positional extras, pipeline input, wrapped
  references, serialized objects, `PSCustomObject`, `PSTypeNames`,
  `Add-Member`, scalar values, and generic object parameters cannot authorize
  execution;
- exported functions expose no capability-like authorization parameter or
  exported variable authority;
- no callable internal function performs native execution, and the executable
  native guard still reports zero declarations or invocations;
- the initial scaffold task ended at
  `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_AUDIT` before the
  follow-up integrity remediation.

G68-G77 additionally prove the remediated scaffold integrity boundary:

- public native adapter operations require explicit primitive string adapter
  and operation selections;
- no implicit production adapter default exists on the public operation gate;
- caller objects, wrapper objects, spoofed methods, mutable module state,
  `PSCustomObject`, `PSTypeNames`, `Add-Member`, serialization, positional
  extras, splatted capability-like names, pipeline input, and non-string values
  do not authorize execution;
- scaffold constants are rebuilt from literals per call rather than trusted
  from mutable module state;
- `Apply`, `Restore`, and `Restart` remain deterministic
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED` results with zero native
  operation, device-query, and Windows-mutation counters;
- custom manifest corruption regressions forward the requested manifest path
  to child runtime processes; and
- the remediated gate remains
  `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_REAUDIT`.

## Independent Re-Audit Result

The independent read-only re-audit of this remediated non-executing production
scaffold and composition-root wiring passed from starting commit
`77a3c3c4e29ddb2cfb0f7281b0db40b9f0622ab6`. It confirmed:

- production metadata is stable, non-synthetic, non-executing, and blocked by
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`;
- public native adapter operations require explicit primitive string adapter
  and operation selections;
- caller objects, mutable module state, serialization, positional extras,
  splatted capability-like names, pipeline input, and non-string values do not
  authorize execution;
- `Apply`, `Restore`, and `Restart` keep native operation, device-query, and
  Windows-mutation counters at zero; and
- custom manifest corruption regressions forward the requested manifest path to
  child runtime processes.

The executable gate string remains
`BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_REAUDIT`, and the live
capability blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`,
until a later separately authorized transition changes the gate.

## Next Boundary

Only a later explicitly authorized task may start native SetupAPI/Newdev
implementation work. That task must preserve the exact-instance, fail-closed,
zero-live-mutation boundary until it has its own implementation, audit, and
explicit live authorization.
