# Controlled Windows 11 Runtime Bring-Up Readiness

This document is the authoritative preparation plan for the first controlled
Windows 11 runtime bring-up of the rewritten Chatpad driver. This commit is
preparation only: it does not sign, package, stage, install, load, trace, query
devices, send requests, access a controller or Chatpad, mutate Windows, reboot,
or touch hardware.

## Enforcement remediation status

The second independent audit found unsupported PASS paths in the readiness
framework. The enforcement remediation fixes those paths while deliberately
keeping the live gate closed.

## Validator-totality remediation status

The third independent audit found remaining uncontrolled exception paths and
unsupported lifecycle-transition acceptances. The validator-totality
remediation is offline-only and keeps the live gate closed.

- Current branch:
  `feature/runtime-bringup-readiness-validator-totality-remediation`.
- Current implementation commit:
  `7689d2cca57c485d8c0569bdcbec58e400621b20`.
- Framework validation is `PASS`; live installation readiness is `BLOCKED`;
  blocker is `BLOCKED_NOT_IMPLEMENTED`.
- Executable exact-instance binding operations: `0`; executable
  exact-instance restoration operations: `0`; broad approved install
  operations: `0`; broad approved rollback operations: `0`.
- Exported readiness validators now reject malformed JSON-compatible values
  through controlled result records. The malformed-input matrix covers
  repository identity, target selection, driver state, rollback readiness,
  package validation, signing readiness, host preflight, evidence directory,
  install planning, WPP planning, event-log planning, post-test
  reconciliation, runtime evidence, runtime observation, and stop-condition
  linkage.
- Target-selection rejects missing, null, numeric, empty, whitespace-only, and
  malformed `candidate_set_id`/candidate structures through
  `TARGET_SELECTION_INVALID` with target stop conditions.
- Rollback readiness validates `rollback_operations` before operation
  inspection and rejects absent, null, scalar, object, empty, malformed,
  blocked, incomplete, cross-session, and wrong-target rollback structures
  through `ROLLBACK_CONTRACT_INVALID`.
- Operation lifecycle validation rejects executed/failed operations without
  result or timestamps, malformed result objects, rolled-back operations
  without rollback references/results, and restored operations without final
  reconciliation evidence.
- Runtime evidence semantic validation rejects invalid rollback references,
  rollback operations in another session or host, duplicate artifact or
  operation IDs, unresolved dependencies, synthetic artifacts in live sessions,
  restored top-level state with planned work, and restored state without final
  reconciliation.
- Public validator entry scripts contain a last-resort
  `VALIDATOR_INTERNAL_ERROR` boundary with sanitized exception diagnostics.
  Normal malformed input is rejected by explicit contract logic, not by the
  boundary.
- The final offline suite contains 75 fixtures and 467 assertions. The
  malformed-input matrix contains 90 cases. Uncontrolled exceptions:
  `0`; `PropertyNotFoundException` count: `0`; StrictMode exception count:
  `0`; invalid transition acceptance count: `0`.
- PSScriptAnalyzer remains `SKIPPED_UNAVAILABLE`; no network installation was
  attempted and unavailable static analysis is not counted as PASS.

- Authoritative machine status is split: framework validation is `PASS`, live
  installation readiness is `BLOCKED`, and the blocker is
  `BLOCKED_NOT_IMPLEMENTED`. Documentation may describe this as pass with a
  blocker, but machine-readable evidence must not use top-level PASS as runtime
  authorization.
- Repository identity is dual for both generations. Validators distinguish the
  frozen accepted baseline, prior readiness implementation commit
  `0d7f5677c214ebd2081ba40a169e0fc6d1efc0ea`, prior readiness finalization
  commit `2bb08fee77125f6b5bed2774c085ce57fe192752`, current remediation
  implementation commit
  `f0f9bf7e196a6f7cfe9b391cc4001b593016d310`, and the finalization commit
  supplied as an exact external audit input after commit creation. The tracked
  manifest avoids self-reference.
- Negative fixtures now pass only when the documented contract returns or
  throws the expected machine-readable result, result code, stop-condition IDs,
  and exception type. Harness self-tests prove unrelated StrictMode exceptions,
  wrong exception types, wrong reasons, missing stop IDs, parser crashes,
  missing expected results, duplicate IDs, skipped fixtures, and zero-assertion
  cases cannot be counted as PASS.
- Structured operations now use a v3 lifecycle contract covering `planned`,
  `blocked`, `skipped_authorization`, `executed`, `failed`, `rolled_back`,
  `restored`, session and host IDs, source classification, target scope,
  explicit target-specific approval, result/timestamp requirements, rollback
  references, restoration evidence, and blocked stop-condition IDs.
- Install readiness cannot pass for empty operations, a caller-supplied Boolean
  binding flag, staging-only plans, blocked binding, wrong instance, synthetic
  live prerequisites, missing rollback, missing verification, mixed sessions,
  or operations missing `approved_as_target_specific`. Exact-instance binding
  remains unimplemented, so executable exact-instance binding operations,
  executable restoration operations, broad approved install operations, and
  broad approved rollback operations are all zero.
- Package validation now resolves effective INF relationships instead of token
  presence: Version, provider, catalog declarations, manufacturer and
  architecture-decorated model selection, hardware IDs, install sections,
  AddService/service-install sections, ServiceBinary, CopyFiles,
  DestinationDirs, KMDF relationships, SYS/CAT identities, and selected
  architecture must form a consistent chain.
- Target, current-driver, rollback, signing, host, evidence-directory, WPP,
  event-log, and post-test reconciliation validators reject the direct
  unsupported-PASS probes reproduced by the audit. Freshness and source
  classification are derived from evidence fields and closed enums rather than
  caller-provided PASS booleans.
- `runtime-bringup-evidence-schema-v1.json` remains Draft 2020-12 and now uses
  repository-specific ID
  `https://github.com/Zaknin/chatpad-super-driver/schemas/runtime-bringup-evidence-v3.json`.
  Structural schema validation is paired with semantic cross-record validation
  for duplicate artifact and operation IDs, dependency existence,
  rollback-to-executed-operation references, session/host consistency,
  synthetic/live consistency, and the allowed transition graph.
- All 20 stop conditions are classified exactly once as executable,
  runtime-observer, or operator-only. The five audit findings that were falsely
  claimed as executable are now linked to the future runtime observation
  contract `tools/Test-ChatpadRuntimeObservation.ps1`; without runtime evidence
  the observer blocks with the stable stop-condition ID.
- PSScriptAnalyzer is reported truthfully. On this machine
  `Invoke-ScriptAnalyzer` was unavailable, no network install was attempted,
  the manifest records `SKIPPED_UNAVAILABLE`, and static analysis is not
  counted as PASS.
- The prior enforcement-remediation offline suite contained 31 fixtures and
  158 assertions across
  accepted-baseline-identity, authorization, binary-identity, current-driver,
  event-log, evidence, host, install, nested-quoting, operation,
  package-semantic, reconciliation, rollback, runtime-observer,
  schema-semantic, schema-structural, signing, target, and WPP categories.

The readiness manifest uses a non-self-referential candidate-tree model. It
binds the final tracked file content, accepted baseline identities, branch,
fixture totals, category totals, PSScriptAnalyzer status, and ignored suite
evidence, but excludes its own hash and requires the final approved commit to
be supplied externally to the repository identity validator.

## Accepted offline baseline

- Accepted commit:
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`.
- Direct parent:
  `38d434e8f7c815f609834f79315600aa73969639`.
- Accepted runtime instrumentation manifest:
  `docs/evidence/runtime-instrumentation-implementation-manifest.json`,
  schema `1.2.0`.
- Provider GUID: `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`.
- Trace schema: `1`.
- Semantic events: 73.
- Semantic-to-emission mappings: 95.
- Direct WPP invocations: 34.
- Helper-mediated mappings: 79.
- Unique physical emission sites: 93.
- Shared physical sites: 2.
- Pure model: 19 scenarios, 932/932 assertions.
- Regression matrix: 13 entries per configuration, six assertion-bearing
  suites, seven validations, 6,980/6,980 assertions per configuration.
- Runtime, owner Full, and orchestration Full guards pass for Debug and
  Release.
- Debug binary: `artifacts/bin/x64/Debug/ChatpadFilter/ChatpadFilter.sys`,
  68,096 bytes,
  SHA-256
  `E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097`.
- Release binary: `artifacts/bin/x64/Release/ChatpadFilter/ChatpadFilter.sys`,
  40,960 bytes,
  SHA-256
  `A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404`.

The offline baseline is frozen. If a later session finds a contradiction in
these identities or accepted evidence, it must stop before any runtime step.

## Gate 0 - Offline identity verification

Purpose: prove the repository, tools, scripts, binaries, and host inspection
surface match the accepted baseline before any live operation is considered.

Required proof:

- branch and HEAD match the approved runtime-session starting point;
- Git status is clean;
- accepted manifest hash and size match;
- Debug/Release SYS sizes and SHA-256 match the accepted identities;
- PE architecture is x64, subsystem is Native, and Authenticode state is
  expected for the selected signing plan;
- runtime-readiness scripts and schema files are hash-recorded;
- host OS version, admin state, PowerShell version, WDK/debugging tools, Secure
  Boot state, test-signing state, Code Integrity, HVCI, and Device Guard state
  are captured by read-only commands.

The scaffold script `tools/Test-ChatpadRuntimeRepositoryIdentity.ps1` performs
repository and binary identity checks. `tools/Test-ChatpadRuntimeHostPreflight.ps1`
captures host facts without mutating state.

## Gate 1 - Pre-mutation host snapshot

Future supervised commands must capture, before mutation:

- `bcdedit /enum all` output for boot configuration and test-signing state;
- `Confirm-SecureBootUEFI` where supported;
- Code Integrity and Device Guard state through read-only CIM/registry queries;
- Memory Integrity/HVCI state;
- installed driver packages and relevant services;
- present and non-present devices;
- controller/Chatpad hardware IDs, compatible IDs, class GUIDs, instance IDs,
  current INF/provider/version/service, parent/container/topology identities;
- System, Code Integrity, Kernel-PnP, SetupAPI, and driver-framework baseline
  event logs;
- current rollback source and recovery path.

The current device and driver identity must be captured before package staging
or installation is permitted.

## Gate 2 - Target-selection proof

Target selection is fail-closed and never based on friendly name alone. The
future live session must prove exactly one target with all of:

- hardware ID;
- compatible ID;
- class GUID/class;
- exact device instance path;
- parent relationship;
- container ID;
- current INF;
- current service;
- expected USB/bus topology;
- vendor ID and product ID.

The procedure stops if zero candidates are found, more than one unresolved
candidate is found, current driver state cannot be captured, the selected
identity differs from the approved contract, or the device is absent or
duplicated. The preparation task does not enumerate live devices; synthetic
fixtures exercise this logic.

## Gate 3 - Rollback readiness

Installation is forbidden until rollback readiness is explicitly PASS.
Required:

- exact current driver package identity;
- current INF/provider/version/service;
- recovery/export source where available;
- exact device instance ID;
- service state;
- target-specific rollback commands;
- uninstall and rescan commands;
- recovery paths for disappearing device, input instability, driver start
  failure, unplanned reboot request, boot loop, Safe Mode, and Windows Recovery
  Environment;
- immediate rollback conditions.

No rollback command may use wildcard target selection.

## Gate 4 - Signing readiness

Supported future signing approaches:

1. Local test certificate with Windows test-signing mode.
2. Trusted internal certificate already approved by the operator.
3. Attestation or production signing where applicable.

The intended first controlled local test is the local test-certificate workflow
because it is attributable, revocable, and appropriate for a supervised
non-distributable machine-local driver test. This preparation commit creates no
certificate, key, signed SYS, CAT, or package. A later audit must approve the
exact certificate storage, private-key handling, timestamping, Secure Boot,
HVCI, and Code Integrity implications before use.

## Gate 5 - Package validation

Before staging, validate:

- INF syntax, architecture, provider, version, DriverVer, and catalogue
  declaration;
- service section, copy destinations, KMDF version, coinstaller/framework
  assumptions;
- hardware-ID match set;
- package completeness and signature;
- INF/CAT/SYS identities and SHA-256 values.

Reject unsigned packages when signing is required, unexpected hardware-ID
matches, unauthorized files, unapproved SYS hashes, mismatched INF/CAT/SYS
sets, unexpected architecture, or packages that bind more broadly than the
approved target.

## Gate 6 - Controlled staging and installation

Future mutating commands are rendered only by this commit. The supervised
session must execute them only after an independent audit and explicit runtime
authorization. Order:

1. inspect package;
2. optionally stage package;
3. update only the exact selected device;
4. confirm selected device and service state;
5. capture event logs;
6. immediately render and verify rollback commands.

The scripts require exact target instance identity and explicit
`-ExecuteAuthorizedRuntimeStep`; the preparation task does not execute that
switch.

## Gate 7 - First load without functional interaction

The first-load checkpoint verifies only:

- package acceptance;
- intended device binding;
- service existence;
- loaded or failed status;
- no unrelated device changed;
- no unexpected reboot requirement;
- System, Kernel-PnP, SetupAPI, and Code Integrity evidence.

No controller/Chatpad request traffic is allowed beyond unavoidable Plug and
Play behavior.

## Gate 8 - Runtime instrumentation capture

The WPP plan uses provider `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}` and the
accepted schema `1` definitions. The future session must:

- create a fresh evidence directory and unique session ID;
- start the trace before the load step;
- record command, provider, flags, level, timestamps, and output path;
- prevent stale ETL/log reuse;
- correlate trace boundaries with Windows events and device state;
- stop tracing safely;
- hash every ETL, converted text, event log, and command transcript.

This preparation commit does not start WPP, ETW, TraceView, WPR, or any live
trace session.

## Gate 9 - Controlled functional observation

Functional observation is a separate later gate. Progression:

1. device arrival;
2. driver initialization;
3. readiness events;
4. controller-side traffic observation;
5. Chatpad attachment/discovery;
6. minimal non-destructive request;
7. expected response;
8. input-report observation;
9. keyboard-output observation only after explicit authorization.

Each step has a stop condition and rollback decision before continuing.

## Gate 10 - Rollback and post-test reconciliation

Rollback is mandatory if target identity, signature, package, service, device,
Code Integrity, SetupAPI, trace, input stability, or evidence safety deviates
from the approved plan. The final session must:

- restore the previous driver;
- verify target-specific restoration;
- remove test package if authorized;
- restore boot/signing configuration if changed;
- confirm no residual test service/package remains;
- capture final system and device state;
- compare pre-test and post-test snapshots.

## Stop-condition authority

`docs/evidence/runtime-bringup-stop-conditions.json` is the stop-condition
register. Continuation after a stop requires explicit operator authorization
and, for safety-critical deviations, an independent audit before mutation
continues.

## Operator checklist

Before any future mutation:

- independent audit of this readiness commit passes;
- exact target contract is filled in and approved;
- exact rollback source is filled in and approved;
- signing method and security-state expectations are approved;
- evidence root is fresh and writable;
- all rendered commands are reviewed;
- emergency recovery path is available on a separate device or printed copy;
- the operator confirms no unrelated input device dependency is at risk.

## Prohibited during this preparation commit

No certificate/key creation, signing, CAT generation, package creation,
Driver Store staging, installation, loading, trace session, device query,
request operation, controller/Chatpad access, protocol traffic, keyboard
injection, Windows mutation, reboot, production source edit, INF/project/
solution/protocol/transport edit, or `legacy/` edit was authorized.

## Exact next task

Independent read-only audit of both enforcement-remediation commits. The audit
must rerun all direct unsupported-PASS probes, verify expected-failure reasons
rather than exceptions, verify the finalization commit changed no executable
files, confirm the authoritative live-readiness status remains `BLOCKED`, and
confirm no signing, packaging, staging, installation, loading, tracing,
event-log export, live device enumeration, target operation, Windows mutation,
hardware interaction, or reboot occurred.
