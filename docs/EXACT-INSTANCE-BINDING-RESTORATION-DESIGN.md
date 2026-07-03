# Exact-instance binding and restoration design

## 1. Scope and status

This document defines the offline exact-instance binding and exact restoration
framework implemented in commit
`0060cd91be7d460f1a4141f6bf893bd56b32bf35`.
Corrective readiness integration commit
`fdcd9448a3dc172213c07928af45d2e68fd0197a` verifies PSScriptAnalyzer
error-severity results and the updated tracked PowerShell inventory.
Independent audit then found nine fail-open contract and evidence defects.
Remediation commits `a969745f589a55243ca9f9e964a45d7104f9a5e8` and
`c3c0930db1326d56808879f12a9e8951f0051e80` close those defects without
adding or invoking a native adapter. Commit
`fd70e9779056b336b43d09be97e686fa61ed5514` isolates each analyzed file in a
clean Windows PowerShell process and sorts findings for deterministic evidence.

The implementation contains:

- pure request, identifier, path, plan, snapshot, evidence, authorization, and
  state-transition contracts;
- a narrow exact-device query and driver-node/package adapter boundary;
- a deterministic fake adapter with multiple same-ID-property devices;
- exact synthetic bind, verification, restoration, replay, and uncertainty
  orchestration;
- versioned operation-plan and evidence schemas;
- a public entry point whose default is `Plan` and which cannot invoke a live
  adapter in this phase;
- T1-T39 offline regression coverage under Windows PowerShell and PowerShell 7.

It does not contain or invoke a live SetupAPI/Newdev adapter. No driver or
driver-store operation is authorized. Live readiness is `BLOCKED`; the current
gate is `BLOCKED_PENDING_INDEPENDENT_REAUDIT`, and the independent downstream
capability blocker is `BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`.

### Remediated trust and serialization contracts

- The snapshot is authenticated before use. Restoration resolves, invokes,
  and verifies the exact prior-driver identity derived from
  `restoration_snapshot.driver_identity`. The plan copy is comparison-only;
  deep inequality fails with `RESTORATION_IDENTITY_SNAPSHOT_MISMATCH`.
- Evidence schema v1 has one trusted validation context:
  `OfflineSyntheticFramework`. Its permitted origin is synthetic/offline.
  Serialized adapter, mode, synthetic, source, producer, and evidence-mode
  fields are descriptive outputs and cannot establish live trust.
- Real Apply/Restore authorization is unavailable by construction.
  `LIVE_ADAPTER_NOT_IMPLEMENTED` is returned regardless of caller adapter
  names, Booleans, elevation, switches, preflight claims, or deterministic
  authorization values.
- `chatpad-canonical-json-v1` parses raw JSON without timestamp conversion,
  rejects case-insensitive duplicate names at every depth, preserves JSON
  scalar/array/object types, sorts property names by ordinal comparison,
  preserves array order, uses invariant finite numeric forms, applies explicit
  JSON escaping, and hashes UTF-8 without BOM.
- Runtime validation mirrors every required plan, snapshot, authorization, and
  driver-identity field in the checked-in schema, rejects additional
  properties, and enforces cross-field identity, action, provenance, time, and
  hash relationships.
- Complete instance IDs use the ASCII allowlist
  `[A-Za-z0-9_&\\#{}().,+:;=@%!-]` after length checks. Hidden Unicode,
  controls, format/separator/combining characters, whitespace, wildcards, and
  non-ASCII confusables are rejected rather than normalized.
- Evidence records `mutation_may_have_occurred` and an explicit
  `uncertainty_status` of `none`, `active`, or `recovered`. Active uncertainty
  cannot reach `COMPLETED` or PASS.

## 2. Exact-instance definition

The framework treats an instance ID as exact only when it is a nonempty,
complete three-or-more-segment Plug and Play instance ID. It rejects whitespace
changes, wildcards, prefixes, suffixes, friendly names, descriptions, hardware
IDs, compatible IDs, class GUIDs, container IDs, location paths, parent IDs,
and service names as substitutes.

Normalization is invariant uppercase followed by ordinal comparison. Evidence
preserves the canonical value returned by the adapter. The fake adapter opens
only by that canonical full ID, requires exactly one synthetic record, and
never searches by hardware ID, compatible ID, container, parent, location, or
prefix. A missing instance is terminal; no replacement target is selected.

Every bind, verification, restart, and restoration call carries the same
canonical instance ID. T1 proves that another device with identical hardware
IDs remains byte-for-byte unchanged. T4 proves that a same-container sibling
interface cannot replace the target.

## 3. Layering

### Pure contracts

`tools/ExactInstance/ChatpadExactInstance.Contracts.psm1` implements:

- exact instance-ID normalization and comparison;
- absolute path and traversal, alternate-data-stream, wildcard, control
  character, and existing reparse-point rejection;
- immutable driver identity validation;
- snapshot and plan hashing with a runtime-independent canonical JSON encoder;
- plan expiration, operation-ID, expected-hash, authorized-action, and
  execution-gate validation;
- explicit state-transition validation;
- synthetic/live evidence provenance validation.

### Device and package adapters

`tools/ExactInstance/ChatpadExactInstance.FakeAdapter.psm1` exposes separate
exact-device open, exact driver-node resolution, bind, restore, restart, and
broad-operation rejection functions. The fake retains a complete ordered call
log. Package resolution returns absent, exact, or ambiguous states and never
chooses the first or highest-ranked candidate.

### Transaction orchestrator

`tools/ExactInstance/ChatpadExactInstance.Orchestrator.psm1` controls plan
validation, preflight, exact target open, canonical identity verification,
precondition fingerprint validation, exact driver-node resolution, bind,
post-bind verification, restoration, post-restoration verification, replay
protection, restart/reboot reporting, and evidence construction.

API success is not success by itself. Bind and restore outcomes require a query
of the same canonical instance and an exact immutable driver-identity match.
Failure after a possible mutation enters `RESTORE_REQUIRED`; an unresolved
restore enters a manual-recovery blocker.

### Public entry point

`tools/Invoke-ChatpadExactInstanceBindingRestoration.ps1` defaults to `Plan`.
`Apply` and `Restore` validate a plan path, full expected SHA-256, operation ID,
authorization value, explicit mutation switch, elevation, clean preflight,
expiry, and adapter identity. The current public path always reports
`LIVE_ADAPTER_UNAVAILABLE_PENDING_INDEPENDENT_AUDIT`; it contains no live
mutation adapter.

The test-only synthetic gate is internal to the fake-adapter suite and is not
exposed by the public wrapper.

## 4. Operation plan and restoration snapshot

The plan schema is
`docs/evidence/exact-instance-operation-plan-schema-v1.json`. It binds:

- schema/version, operation type and unique operation ID;
- generation and expiration timestamps;
- branch and exact implementation commit;
- host, session, and authorization context;
- requested and canonical instance IDs;
- class, container, parent, location, hardware, and compatible identities;
- status, problem code, and complete current driver identity;
- canonical target INF path, size, INF/catalog hashes, provider, class/model,
  version, date, architecture, install section, matching ID, published INF,
  service, driver key, and driver-node ID;
- expected post-bind identity;
- exact prior driver identity and signed snapshot fingerprint;
- precondition fingerprint, authorized actions, restart policy, stop
  conditions, and plan SHA-256.

The snapshot distinguishes unavailable properties through an explicit list. It
does not fabricate missing data. Its SHA-256 excludes only its own hash field.
The plan SHA-256 excludes only its own hash field.

Paths must be absolute and canonical. Traversal segments, alternate data
streams, wildcards, controls, and existing reparse points are rejected.
Package byte size and SHA-256 identities remain mandatory. A filename alone is
never sufficient.

## 5. Driver identity and restoration

The target and restoration contracts require exact driver-node identity,
published and original INF identity, provider, description, version, date,
service, driver key, signer/catalog identity, matching ID, rank metadata,
architecture, model/install section, INF SHA-256, and catalog SHA-256.

Zero candidates yields a dedicated unavailable result. Multiple exact
candidates yields an ambiguity blocker. There is no best-rank, newest-driver,
generic Microsoft-driver, or first-record fallback.

Restoration requires:

- the same canonical instance ID;
- an authentic snapshot and plan lineage;
- unchanged precondition identity;
- the exact prior driver-node identity;
- one unambiguous prior package;
- verified post-restoration identity.

`RESTORE_DRIVER_NOT_AVAILABLE` is terminal and does not select an alternative.
Global package removal, device removal, all-device rescan, and package-wide
rollback are prohibited.

## 6. State machine

The contract defines and validates these states:

`PLAN_CREATED`, `PLAN_VALIDATED`, `PREFLIGHT_STARTED`, `TARGET_OPENED`,
`TARGET_IDENTITY_VERIFIED`, `SNAPSHOT_CAPTURED`,
`PACKAGE_IDENTITY_VERIFIED`, `READY_TO_BIND`, `BIND_STARTED`,
`BIND_API_SUCCEEDED`, `POST_BIND_VERIFY_STARTED`, `BIND_VERIFIED`,
`RESTART_REQUIRED`, `REBOOT_REQUIRED`, `COMPLETED`,
`BIND_FAILED_BEFORE_MUTATION`, `BIND_FAILED_AFTER_MUTATION`,
`RESTORE_REQUIRED`, `RESTORE_STARTED`, `RESTORE_API_SUCCEEDED`,
`POST_RESTORE_VERIFY_STARTED`, `RESTORED`, `RESTORE_FAILED`, and `BLOCKED`.

The suite validates all 50 allowed directed transitions and rejects probes for
skipped prerequisites, mutation after completion, bind after restoration,
completion after a pre-mutation failure, and mutation after blocking.
Operation IDs are retained as in-progress, completed, uncertain, or
manual-recovery lineage states. Apply and restore replay is rejected.

## 7. Future Windows adapter design

The dedicated non-executing native adapter design gate is
`docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`. The executable contract
for the capability boundary, API sequence inventory, structure ownership
model, error taxonomy, evidence fields, operation gates, and static
native-code guards is
`tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`. G1-G25 in the
offline exact-instance suite prove that the current branch still has no live
capability and cannot invoke a native adapter. G16-G25 specifically prove that
module session-state extraction, module-context invocation, non-exported
function discovery, reference wrapping, `PSCustomObject`, `PSTypeNames`,
`Add-Member`, serialization, scalar/object spoofing, and unexpected legacy
capability parameters cannot authorize mutation.

The future user-mode adapter must use Unicode Windows APIs and keep a single
`HDEVINFO` plus `SP_DEVINFO_DATA` pair alive for the transaction:

1. `SetupDiCreateDeviceInfoList` creates an initially empty set.
2. `SetupDiOpenDeviceInfoW` opens the full supplied instance ID into that set.
   Open flags are `0`; no class/device enumeration selects a target.
3. `SetupDiGetDeviceInstanceIdW` uses a bounded two-call size query and then
   retrieves the canonical ID. The result is normalized and compared with the
   request before any driver-list work.
4. Read-only SetupAPI/CfgMgr32 property calls capture class, container, parent,
   location, hardware/compatible IDs, status/problem code, and current driver
   identity. Every buffer length and return code is checked.
5. `SetupDiGetDeviceInstallParamsW` and
   `SetupDiSetDeviceInstallParamsW` constrain the search to the authorized
   pre-staged package. `SP_DEVINSTALL_PARAMS_W.cbSize` is always initialized.
   `DI_ENUMSINGLEINF` is used only with the authorized canonical INF path.
   `DI_FLAGSEX_SEARCH_PUBLISHED_INFS` may be used when selection is restricted
   to the driver store. No recursive or broad source search is authorized.
6. `SetupDiBuildDriverInfoList` uses `SPDIT_COMPATDRIVER` and the exact
   `SP_DEVINFO_DATA`. `SetupDiEnumDriverInfoW`,
   `SetupDiGetDriverInfoDetailW`, and `SetupDiGetDriverInstallParamsW` inspect
   every candidate. `SP_DRVINFO_DATA_W.cbSize` and detail structure sizes are
   initialized and validated. Zero or multiple immutable identity matches
   fail.
7. `SetupDiSetSelectedDriverW` receives the exact device element and the exact
   enumerated driver node. The adapter must preserve the returned
   `SP_DRVINFO_DATA_W.Reserved` identity and must not request a description/
   provider search with `Reserved == NULL`.
8. `DiInstallDevice` receives that same `HDEVINFO`, `SP_DEVINFO_DATA`, and
   selected `SP_DRVINFO_DATA_W`. Flags are `0`; null-driver installation is
   prohibited. The `NeedReboot` output and `GetLastError` are retained.
9. The adapter re-queries the same device element and proves the complete
   expected driver identity. A successful API return without this postcondition
   enters restoration-required state.
10. `SetupDiGetDeviceInstallParamsW` captures `DI_NEEDRESTART`/
    `DI_NEEDREBOOT`. Neither flag authorizes automatic restart or reboot.
11. `SetupDiDestroyDriverInfoList` destroys the device-specific
    `SPDIT_COMPATDRIVER` list. `SetupDiDestroyDeviceInfoList` releases the
    `HDEVINFO` in a `finally`/RAII boundary. Any caller-owned file queue must be
    disassociated before set destruction.

Microsoft documents `SP_DEVINFO_DATA` as the structure identifying one device
element and requires `cbSize` to equal the structure size. Microsoft also
documents that `SetupDiSetSelectedDriverW` selects a driver for the supplied
device element, and that `DiInstallDevice` installs a pre-staged driver on the
specified present device. References:

- [Using device installation functions](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/using-device-installation-functions)
- [SP_DEVINFO_DATA](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/ns-setupapi-sp_devinfo_data)
- [SetupDiSetSelectedDriverW](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/nf-setupapi-setupdisetselecteddriverw)
- [SetupDiDestroyDriverInfoList](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/nf-setupapi-setupdidestroydriverinfolist)
- [SP_DEVINSTALL_PARAMS_W](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/ns-setupapi-sp_devinstall_params_w)
- [DiInstallDevice](https://learn.microsoft.com/en-us/windows/win32/api/newdev/nf-newdev-diinstalldevice)

The prohibited broad alternatives remain `DiInstallDriver`,
`UpdateDriverForPlugAndPlayDevices`, `pnputil /add-driver ... /install`,
hardware/compatible-ID-wide update, class-wide mutation, best-driver
reevaluation without an exact selected node, and global package deletion.

## 8. Restart and reboot

Restart is a separate authorized operation against the same canonical instance.
The framework never performs it automatically. A reboot indication produces a
blocked pending-reboot result; the framework never calls a reboot API.
Any future exact-device restart method must prove that its scope cannot affect
related devices or fail closed.

## 9. Evidence and accounting

The evidence schema is
`docs/evidence/exact-instance-operation-evidence-schema-v1.json`. Evidence
contains the operation/plan identity, adapter provenance, synthetic marker,
target, preconditions, transitions, ordered adapter calls, before/after
identities, Win32/result data, restart/reboot state, bind/restore/restart and
broad-operation accounting, verification result, stop condition, restoration
outcome, exception count/type, and final classification.

Fake-adapter evidence cannot satisfy live readiness. A fake adapter represented
as live, or a synthetic record carrying the Windows adapter identity, fails
evidence validation.

The post-implementation suite contains 25 first-class records and 99
assertions. It records 14 synthetic exact-bind attempts, four synthetic exact
restoration attempts, zero synthetic restart attempts, one rejected broad
attempt, one expected adapter-exception uncertainty case, zero unexpected
harness exceptions, and zero live or Windows mutation counters.

## 10. Remaining gates

An independent read-only audit must verify the implementation commit,
finalization commit, plan/evidence hashes, T1-T25 behavior, transition graph,
critical call traces, static broad-operation guard, manifest reconciliation,
and all zero live counters.

Only a later separately authorized task may implement and audit the native
Windows adapter. That task must not reuse synthetic authorization and must not
perform live mutation merely because the offline framework passed.
