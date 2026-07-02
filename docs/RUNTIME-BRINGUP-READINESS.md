# Controlled Windows 11 Runtime Bring-Up Readiness

This document is the authoritative preparation plan for the first controlled
Windows 11 runtime bring-up of the rewritten Chatpad driver. This commit is
preparation only: it does not sign, package, stage, install, load, trace, query
devices, send requests, access a controller or Chatpad, mutate Windows, reboot,
or touch hardware.

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

Independent read-only audit of the runtime-bring-up readiness commit. The audit
must verify fail-closed target-selection, signing, package, rollback, evidence,
stop-condition, and authorization contracts before any live Windows mutation is
authorized.
