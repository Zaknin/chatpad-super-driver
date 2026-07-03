# Native SetupAPI/Newdev Adapter Design Gate

## Status

This document is a non-executing design and authorization gate for a future
native SetupAPI/Newdev exact-instance adapter. The current repository does not
implement, declare, load, or invoke any native device-installation API.

Authoritative current state:

- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_REAUDIT`.
- Live adapter status: `NOT_IMPLEMENTED`.
- Capability blocker: `BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`.
- Live binding/restoration/restart authorization: `false`.
- Live device queries and Windows mutations performed: `0`.

The executable design contract is
`tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`. The offline G1-G25
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

The current composition root remains absent. `Apply`, `Restore`, and `Restart`
requests therefore fail at the live-adapter gate with
`LIVE_ADAPTER_NOT_IMPLEMENTED`.

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

The present implementation always remains blocked because no live native
adapter or internally controlled mutation authorization exists.

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

## Next Audit Boundary

The next task must be an independent read-only re-audit of this remediated
design-and-gate implementation. That audit must not implement or invoke the
native adapter and must confirm the blocker remains
`BLOCKED_PENDING_INDEPENDENT_REAUDIT` with
`BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`.
