# Offline KMDF Production Orchestration Evidence Remediation

## Purpose

This checkpoint remediates evidence and semantic-guard defects found by the
independent audit of implementation commit
`efb729502a0527ac70e2d20fa31a323c3beb2920`,
`driver: invoke production request owner orchestration`.

Production source is frozen. This checkpoint changes no C/C++ source, header,
project, solution, INF, signing, packaging, deployment, target, D0, removal,
USB, controller, or hardware behavior.

## Second Audit Outcome

A second evidence audit later rejected this checkpoint for five
evidence-fidelity reasons: no top-level mandatory-ID declaration, abbreviated
retention commands, missing KMDF semantic totals, incomplete repository-safety
action counters, and an unretained historical binary pair. Production source
still passed inspection.

Those findings are addressed by the separate
[Offline KMDF Production Orchestration Evidence Finalization](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-EVIDENCE-FINALIZATION.md)
checkpoint. The schema-`1.1.0` and 42-entry statements below describe this
historical first-remediation checkpoint; they are not the final acceptance
state.

## Starting State

- Implementation commit:
  `efb729502a0527ac70e2d20fa31a323c3beb2920`.
- Implementation parent:
  `4ba0de15420e0b66287a501918de694c8b6fd720`.
- Implementation branch:
  `feature/offline-kmdf-production-orchestration-invocation`.
- Remediation branch:
  `feature/offline-kmdf-production-orchestration-evidence-remediation`.

Git proves that the implementation commit changes 14 paths. The audit request
described a 15-path set with an omitted final path, but both
`git diff --name-only` and `git diff --name-status` prove there is no fifteenth
path. The guard and evidence use the authoritative 14-path set.

## Audit Findings Remediated

The production source passed independent inspection. Acceptance remained
blocked because:

- the guard inspected an empty current-worktree diff instead of the immutable
  implementation parent-to-commit diff;
- the status guard named only part of the 18-result mapping;
- the manifest did not require a closed evidence ID set;
- evidence entries lacked exact commands, configurations, and count/metric
  applicability;
- KMDF context entries pointed only to compile logs rather than captured
  semantic-guard output;
- repository-safety, implementation-scope, whitespace, unstaged, staged, and
  candidate-containment evidence was absent; and
- the containing-commit and pre-final evidence relationship was underspecified.

## Guard Corrections

`tools/Test-ChatpadProductionOrchestrationInvocation.ps1` now binds the
immutable implementation parent and commit, derives their committed
name-status, requires the exact authoritative path set, requires that
`device.c` is the only changed production source, rejects prohibited paths,
and runs the parent-to-current whitespace check.

The guard parses the authoritative orchestration-result enum and production
mapping. It requires exactly 18 enum values and exactly one mapped case for
each value. It separately proves:

- `OK` returns `STATUS_SUCCESS`;
- three null-argument results return `STATUS_INVALID_PARAMETER`;
- four creation failures return `FrameworkStatus` only when it is failing and
  otherwise return `STATUS_INVALID_DEVICE_STATE`;
- ten state, validation, rollback, and invariant failures return
  `STATUS_INVALID_DEVICE_STATE`; and
- the default path fails closed.

The existing orchestration call count, placement, local-report lifetime,
result/report mismatch, structural-ready, lifecycle ordering, direct-helper,
rollback/deletion, target/request, D0/removal, unsafe-logging, and
forced-retention checks remain.

## Manifest Schema and Mandatory Evidence

The manifest schema is `1.1.0`. Every evidence entry records:

- ID and category;
- repository-relative ignored path and SHA-256;
- exact result, command, and configuration;
- explicit assertion counts or null assertion fields;
- metric name, value, and unit;
- count applicability;
- immutable commit/state binding;
- UTC generation time; and
- notes and limitations.

The guard requires a closed 42-ID evidence set covering orchestration and
compatibility guards, regression suites, compile checks, driver and solution
builds, binaries and Authenticode, retention and WDF function-table evidence,
target/request absence, repository safety, immutable implementation scope,
whitespace, unstaged and staged candidate state, and final candidate
containment.

## Evidence-State and Containing-Commit Binding

Evidence is generated against one of these explicitly named states:

- immutable implementation commit;
- remediation worktree based on that commit;
- staged remediation candidate;
- binary produced from unchanged implementation source; or
- post-build binary-inspection state.

The manifest is committed in the Git commit that contains it. It intentionally
does not embed that containing commit hash because doing so would be
self-referential. An independent audit must obtain the containing commit from
Git and verify its parent, branch, scope, manifest content, referenced hashes,
and final clean synchronized state.

Pre-final logs do not claim to have been produced from the not-yet-existing
remediation commit.

## Self-Referential Evidence Limits

A Full guard transcript changes while the guard is reading the manifest, so it
cannot validate its own final SHA-256. The guard requires the entry and all its
metadata, validates every non-self entry, and explicitly reports the one
self-hash it skipped. The final independent audit must verify both Full guard
log hashes from the committed manifest.

Similarly, staged-diff evidence describes the staged candidate at its capture
point. Adding that log's SHA-256 to the staged manifest changes the manifest
after capture. The log and manifest describe this ordering; neither claims
perfect self-validation.

## Validation Matrix

Fresh offline evidence covers:

- production orchestration SourceOnly Debug and Release;
- production orchestration Full Debug and Release;
- KMDF request-owner context semantic/build guards Debug and Release;
- production linkage Debug and Release;
- production owner initialization SourceOnly Debug and Release;
- request-owner model, protocol, transport, lifecycle, and control-setup
  regressions in Debug and Release;
- protocol kernel and WDF control-setup checks in Debug and Release;
- ChatpadFilter wrapper builds in Debug and Release;
- Community full-solution builds in Debug and Release;
- the expected Build Tools Debug `MSB8020` limitation;
- Debug and Release binary, signature, retention, WDF dispatch, and forbidden
  target/request-operation inspection; and
- repository/Git safety and containment.

Regression baselines remain:

- request-owner model: `5002/5002`;
- protocol: `610/610`;
- transport: `186/186`;
- lifecycle: `109/109`; and
- control setup: `141/141`.

Final candidate manifest statistics:

- schema version: `1.1.0`;
- total and mandatory entries: `42/42`;
- unique IDs and paths: `42/42`;
- duplicate IDs and paths: `0/0`;
- missing mandatory IDs: `0`;
- missing metadata fields: `0`;
- missing evidence paths: `0`;
- non-ignored and tracked evidence paths: `0/0`;
- non-self SHA-256 mismatches: `0`; and
- malformed entries: `0`.

## Binary Results

This checkpoint observed the following rebuilt binaries:

| Configuration | Size | SHA-256 | Authenticode |
| --- | ---: | --- | --- |
| Debug | 32,256 | `DD33388A3905A4C5AFCFD3FF4E3443308CC9A280BCDD094FB7ACED7478880F83` | `NotSigned` |
| Release | 20,480 | `72B30B0523B07F91A21FE8711ED846F4B355652F0E2B0FEA691F894A4304CAC5` | `NotSigned` |

Both remain x64 Native-subsystem PE images. Combined source, object, link,
disassembly, symbol, and WDF function-table evidence proves orchestration,
creation-helper, rollback, validator, and attribute-preparation retention while
bounding COMDAT/LTCG visibility. No target discovery or request formatting,
reuse, send, completion, or cancellation evidence is present.

The earlier implementation-checkpoint binaries and raw inspection outputs were
not retained. Therefore, their exact equivalence to the pair above cannot be
retroactively proven; the hashes are historical observations only. The later
finalization checkpoint replaces that unsupported comparison with a retained
source-identical A/B experiment.

## Remaining Limitations

- No driver was loaded, so `EvtDeviceAdd` and dormant WDF graph creation were
  not executed.
- Ignored evidence remains mutable until independently rehashed against the
  committed manifest.
- COMDAT, function-level linking, LTCG, and KMDF WDF-function-table dispatch
  limit name-only proof.
- The containing remediation commit and upstream equality must be obtained
  from Git by the independent audit.

## Safety and Next Gate

No signing, certificate/key creation, packaging, staging, installation,
loading, Windows mutation, device query, hardware interaction, controller
interaction, or Chatpad interaction occurred.

The next task is an independent read-only audit of the production
implementation together with the later evidence-finalization checkpoint.
Runtime observation, target discovery, request execution, signing,
installation, loading, and hardware testing remain unauthorized.
