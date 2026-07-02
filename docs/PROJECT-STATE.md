# Project State

*Last updated: 2026-07-02 (dynamic-emission remediation)*

## Current state

- **Branch:** `feature/offline-runtime-instrumentation-dynamic-emission-remediation`.
- **Parent:** `38d434e8f7c815f609834f79315600aa73969639`, `test: repair
  runtime instrumentation evidence contracts`.
- **Expected containing commit:** the commit containing this file, subject
  `test: close dynamic instrumentation emission coverage`.
- **Accepted design:** `526f6bb055b485fdb459a9d303fc3f814da15e48`.
- **Provider/schema:** `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`, trace schema
  `1`, 73 semantic events.
- **Evidence manifest:** schema `1.2.0`; independent audit pending.

## Verified remediation state

- Pure model: 19 scenarios, 932/932 real assertions, five negative self-tests,
  no unknown IDs or wrong families. Expected semantic-name sequences resolve
  through the authoritative design and do not import emitted numeric constants.
- Regression matrices: Debug and Release each 13/13 entries, six
  assertion-bearing suites, seven non-assertion validations, 6,980/6,980 real
  assertions, zero synthetic assertions, parse failures, empty results, entry
  failures, or failed assertions.
- Emission evidence: schema 2, 73 events, 95 semantic mappings, 34 direct WPP
  invocations, 79 helper mappings, 93 unique physical sites, two shared sites,
  nine entered and nine completed stage locations, and zero missing, extra,
  phantom, stale, collapsed, duplicate, or unexplained mappings.
- Five dynamic helpers and 78 callers are source-bound. Event 1901 is mapped
  to the pre-context terminal WPP sink; ten dynamic rejection fixtures pass
  with zero unresolved selectors, unreachable rows, sink failures, stale
  locators, wrong families, or allow-list suppression.
- Cleanup owner observation is exactly one diagnostic read-only object snapshot;
  five lifecycle callbacks are inspected and seven negative fixtures reject
  excluded, mutating, completion/cancellation, transfer, operational, and
  unclassified use.
- Runtime, production-owner Full, and production-orchestration Full guards pass
  for Debug and Release. Production inputs and retained binaries are unchanged;
  no new driver or full-solution build was required.
- Debug binary: 68,096 bytes, SHA-256
  `E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097`,
  unsigned x64 Native.
- Release binary: 40,960 bytes, SHA-256
  `A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404`,
  unsigned x64 Native.

## Safety and blocker

- No production `.c`/`.h`, project, solution, INF, protocol, transport,
  signing, packaging, installation, deployment, hardware, or `legacy/` path
  changed.
- No signing, certificate/key creation, packaging, staging, installation,
  loading, live tracing, Windows mutation, device query, target/request
  operation, controller/Chatpad access, or hardware action occurred.
- **Blocker:** independent read-only audit of the final dynamic-emission
  remediation commit and schema-`1.2.0` manifest is required before any later
  gate.
