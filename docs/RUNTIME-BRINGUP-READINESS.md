# Controlled Windows 11 Runtime Bring-Up Readiness

This document is the authoritative preparation plan for the first controlled
Windows 11 runtime bring-up of the rewritten Chatpad driver. This commit is
preparation only: it does not sign, package, stage, install, load, trace, query
devices, send requests, access a controller or Chatpad, mutate Windows, reboot,
or touch hardware.

## Current native adapter design-gate status

Independent audit of
`dddd4afab914c1929de5683d6822fde5cbf46c6a` failed because the fail-closed
native adapter operation path called the full compile-output evidence
validator, which opened and hashed the real DLL with `Get-FileHash`. The
remediation keeps the full validator for separately authorized compile-output
validation, but removes it from the operation/design-gate call chain. Blocked
operations now use only tracked evidence records in explicit mode
`EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`; they do not stat, scan, open, read,
hash, parse, write, load, reflect over, or execute compile outputs. The current
remediation passed independent audit at
`d71c6a46b0066eb8bc48e8de14795c223cdaa00c`. The design gate is accepted and
closed; the current blocker is native adapter execution not implemented.

Branch `feature/native-adapter-non-live-implementation-phase` adds the next
separately authorized non-live planning phase from accepted audit transition
`748ba24b3e795cd70b3325b6a54fb88569427ed6`. The non-live implementation commit
is `4522510a17354fe53d163546e16ff24af5fa0374`. It preserves all earlier
fail-closed scaffolding and adds only inert operation-plan, in-memory
precondition, always-deny authorization-decision, and typed zero-counter result
models. No target lookup, native execution, artifact I/O, device access,
Windows mutation, or driver behavior is added.

The earlier branch `feature/native-adapter-fail-closed-scaffolding` added the
non-executing scaffolding stage from accepted design-gate transition
`788ce8adfd0500741783ee1e359d5f805db710dd`. The fail-closed native adapter
scaffolding was added at
`7560fc242a39228d6a95f42ff908bb4be438d6ad`. The accepted compile-only
validation, declaration-only SetupAPI/Newdev source boundary, static metadata
review, exact-instance offline framework, and accepted no-artifact-I/O
design-gate audit remain underlying evidence; none authorizes execution. This
stage adds request shaping, evidence-state checking, authorization-state
checking, and deterministic fail-closed operation results only. It does not
implement native execution or add live lookup, artifact I/O, device query,
Windows mutation, or driver behavior. The future API sequence, structures,
driver-node identity evidence, exact-instance binding/restoration proof,
restart/reboot separation, error taxonomy, authorization prerequisites, safety
counters, source-boundary guard, compile-only evidence validator, and fail-closed
scaffolding status are documented in
`docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md` and implemented as
offline gate logic in `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`.
The declaration source and static boundary validator live under
`tools/ExactInstance/NativeInterop/`; the isolated compile-only harness lives
under `tools/ExactInstance/CompileOnlyValidation/`.

- Starting branch:
  `feature/runtime-bringup-native-interop-source-audit-acceptance`.
- Starting commit: `a5a1ddfe055481eec4ea4da57b664c0bd3189d22`.
- Source audit verdict: `AUDIT PASS` for audited commit
  `dbba70d74e99c211d47187697e19e528b381520a`.
- Compile-only validation evidence:
  `docs/evidence/native-interop-compile-only-validation.json`, schema
  `chatpad-native-interop-compile-only-validation-v2`, validation ID
  `native-interop-compile-only-20260703T194533Z`.
- Production adapter identity: `chatpad-windows-exact-instance-adapter-v1`.
- Synthetic adapter identity: `chatpad-fake-exact-instance-adapter-v1`,
  selectable only with explicit synthetic mode.
- PowerShell module state is introspectable by callers in the same process;
  caller possession of an object is not a trusted mutation boundary.
- No exported native adapter gate function accepts a caller-supplied mutation
  capability, token, sentinel, secret, object, or equivalent authorization
  value.
- Compile-only harness target: `net9.0-windows10.0.26100.0`, `Release`, `x64`,
  output type `Library`, nullable enabled, warnings as errors, analyzers
  disabled.
- Toolchain: .NET SDK `9.0.315`, MSBuild `17.14.43+2a0eb78b3`, Roslyn
  `4.14.0-3.26064.1 (450493a9)`.
- The prior independent audit returned `AUDIT FAIL`: five tracked input
  identities and 30 manifest entries were line-ending-sensitive in a clean
  CRLF checkout, while canonical LF identities matched exactly.
- The follow-up independent re-audit of
  `207d00feedb6e419d3f791fbcb757576dfb5dbba` failed narrowly because old v1
  compile-output preservation was still an unresolved acceptance criterion.
  The audit otherwise reproduced the source-input defect and validated the
  remediated exact, readiness, manifest, audit-root, invalid-root, safety,
  generated-file, and native-boundary behavior.
- The independent remediation re-audit returned `AUDIT PASS` for
  `3e922470f2e46d5eeb4b6fe7500c4f105c608b3b`; inventory
  `artifacts/logs/independent-compile-only-evidence-reaudit-3e92247/artifact-inventory.json`,
  size `49650` bytes, SHA-256
  `09E4CB50663849B7E2ADB6D91817A35E97DC12831CA5384128ABE2A72BFCFA5C`.
- Remediated compile-only validation: accepted `PASS`; compiler exit
  code `0`; warnings `0`; errors `0`; produced file count `18`.
- Exact-instance suite: `PASS`, 209 tests and 839 assertions under Windows
  PowerShell 5.1 and PowerShell 7.
- Full readiness suite: `PASS`, 513 fixtures and 2,563 assertions under
  Windows PowerShell 5.1 and PowerShell 7.
- Readiness manifest generation uses schema
  `chatpad-runtime-bringup-readiness-manifest-v4`, framework status `PASS`,
  live installation readiness `BLOCKED`.
- Live binding/restoration/restart, live observations, device queries,
  hardware access, and Windows mutations: all `0`.
- Live readiness: `BLOCKED`.
- Current gate:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Native execution status: `NOT_IMPLEMENTED`.
- Execution design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Fail-closed scaffolding status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- Fail-closed scaffolding commit:
  `7560fc242a39228d6a95f42ff908bb4be438d6ad`.
- Scaffolding-audit remediation commit:
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e`.
- Fail-closed scaffolding audit acceptance:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Scaffolding-audit acceptance commit:
  `748ba24b3e795cd70b3325b6a54fb88569427ed6`.
- Non-live implementation status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO`.
- Non-live implementation commit:
  `4522510a17354fe53d163546e16ff24af5fa0374`.
- Non-live implementation audit acceptance:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Non-live planning audit-acceptance commit:
  `bb6cc27c2281e04dee2166c5a67e124092055f9f`.
- Execution-scope boundary status:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_DEFINED_NO_NATIVE_IO`.
- Execution-scope boundary commit:
  `4cdde55e392e78db8a7a38858fb2f436557fbe2e`.
- Execution-scope boundary audit acceptance:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Accepted execution-scope boundary audit target:
  `f0b10d862d23d0ede28b1139c2ccb726bfcddc48`.
- Execution-scope boundary lane closeout:
  `AUDIT_PASS_LANE_CLOSED_NO_NATIVE_IO`.
- Accepted lane-closeout audit target:
  `d1372ba8f7812d24a09b87238793e78435ac4492`.
- Execution-scope boundary lane-closeout commit:
  `e68ed58e3c5a2560c331f4b69dfe021ae54531e1`.
- Closeout-identity audit acceptance:
  `NATIVE_ADAPTER_EXECUTION_BOUNDARY_CLOSEOUT_IDENTITY_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Accepted closeout-identity audit target:
  `9c9af5cf0cfdffde67a0f2b4e41e8eceb42d673f`.
- Final lane closeout:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_LANE_CLOSED_NO_NATIVE_IO`.
- Accepted final-closeout audit target:
  `f7f6041d6987ea8e3752546bd4c9116c88fbe56a`.
- Accepted execution scope-boundary final-closeout commit:
  `68099a441db5f8b517dbeb296ab234a9ee639bdb`.
- Execution-envelope verifier:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_IMPLEMENTED_NO_NATIVE_IO`.
- Execution-envelope verifier audit acceptance:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit target:
  `4849d1959cab9c289952655eb73e3279117779d2`.
- Execution-envelope verifier audit-acceptance audit pass:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-acceptance audit target:
  `b6bdd01588e9d72113dd9b09fcfa9baf2026424d`.
- Execution-envelope verifier audit pass recorded:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_RECORDED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-pass target:
  `f235879fe6d74dcc02dfe2e56297ef14e5a48800`.
- Execution-envelope verifier audit-pass acceptance:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-pass record target:
  `b64a672984b6e7db16765f13de385b22f3491f11`.
- Execution-envelope verifier audit-pass acceptance audit pass:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_PASS_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-pass acceptance audit target:
  `75a083a684c79b729de04c770371fb6190c9c9e7`.
- Execution-envelope verifier audit-pass acceptance audit accepted:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_AUDIT_PASS_ACCEPTANCE_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier audit-pass acceptance audit-pass target:
  `ba952444d9d3e306da8985e25b93b74aa5f6cff6`.
- Execution-envelope verifier lane closeout:
  `NATIVE_ADAPTER_EXECUTION_ENVELOPE_VERIFIER_LANE_CLOSED_NO_NATIVE_IO`.
- Accepted execution-envelope verifier lane-closeout audit target:
  `e271e5c8dd464ba0aeee82e4dc163b12ae28b8de`.
- Live read-only equipment observation gate:
  `LIVE_READONLY_EQUIPMENT_OBSERVATION_GATE_OPENED_NO_DEVICE_IO`.
- Live read-only equipment observation status:
  `LIVE_READONLY_EQUIPMENT_OBSERVATION_CAPTURED_NO_MUTATION_NO_NATIVE_IO`.
- Live read-only equipment observation evidence:
  `docs/evidence/live-readonly-equipment-observation.json`.
- Live read-only equipment observation mode:
  read-only USB/HID/PnP inventory capture only. No native execution,
  SetupAPI/Newdev invocation, native library load, entry-point resolution,
  Windows mutation, driver action, artifact access, compile-output access, or
  exact-instance binding implementation is performed or authorized.
- Prior execution-envelope verifier audit-pass acceptance audit accepted target:
  `ba952444d9d3e306da8985e25b93b74aa5f6cff6`.
- Prior accepted execution-envelope verifier audit-pass acceptance audit target:
  `75a083a684c79b729de04c770371fb6190c9c9e7`.
- Prior execution-envelope verifier audit-pass record target:
  `f235879fe6d74dcc02dfe2e56297ef14e5a48800`.
- Prior execution-envelope verifier audit-pass transition target:
  `b6bdd01588e9d72113dd9b09fcfa9baf2026424d`.
- Accepted non-live planning audit target:
  `5e7a6f39d0363121b8bd3f6e4b38ceb517889679`.
- Accepted scaffolding audit target:
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e`.
- Native adapter design-gate remediation audit: `AUDIT PASS` for
  `d71c6a46b0066eb8bc48e8de14795c223cdaa00c`; 17 functions traced; full
  compile-output validator, `Get-FileHash`, output enumeration, and native/file
  loading members reachable: `0`.
- Native execution authorization: `false`.
- Design-gate operation evidence validation:
  `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Real DLL access during remediation and fail-closed probes: `false`.
- Static metadata parser implementation:
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED`.
- Parser execution against the real artifact: `STATIC_METADATA_VALIDATED`.
- Metadata review: `STATIC_METADATA_VALIDATED`.
- Real artifact open/parse/hash: `PERFORMED`.
- Real artifact write/overwrite: `NOT_PERFORMED`.
- Post-audit vocabulary-design remediation audit: `AUDIT PASS`, accepted at
  `83eb4acf44d50d8c43a09f7827728763e726e9c2`.
- Real-artifact path gate: `STATUS_BOUNDARY_ACCEPTED`.
- Metadata/parser accepted status:
  `STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED`.
- The static metadata lane is accepted and closed. The generator emits and the
  validator requires this accepted vocabulary.
- Live adapter status: `SCAFFOLD_NON_EXECUTING`; live authorization: `false`.
- Native source has now been compiled only in the isolated non-production
  harness. Compiled output remains unloaded, unexecuted, unreflected, and
  uninvoked. Native adapter execution remains unimplemented.
- Fail-closed native adapter scaffolding now records inert request, evidence,
  authorization, and execution-result models. `Apply`, `Restore`, and
  `Restart` remain blocked with
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`; unsupported operations
  are rejected; malformed or non-current evidence/authorization states fail
  closed; and all native/device/Windows/driver/action counters remain zero.
- Non-live operation planning now evaluates only caller-provided in-memory
  records, always denies execution, emits inert plans for Apply/Restore/Restart,
  and returns typed blocked results with all counters and action flags zero.
- The no-artifact-I/O regression passed under Windows PowerShell 5.1 and
  PowerShell 7. SetupAPI/Newdev invocation, native DLL loading, entry-point
  resolution, device query, Windows mutation, and driver build/sign/package/
  install/load/bind/restore/restart remain not authorized.
- Independent strict read-only audit of documentation-remediation target
  `af41a8eaeea96dcbcad75fb2e261c4352b2a468e` returned `AUDIT PASS`.
  Acceptance records the status transition only; it does not authorize native
  execution, real DLL or compile-output access, device query, Windows mutation,
  or driver action.
- Independent strict read-only audit of non-live planning continuity target
  `5e7a6f39d0363121b8bd3f6e4b38ceb517889679` returned `AUDIT PASS`.
  Acceptance status is
  `NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO`; implementation
  remains `4522510a17354fe53d163546e16ff24af5fa0374`, and all operation plans and
  results remain blocked/non-executing.
- The record-only execution-scope boundary requires an exact single-operation
  authorization statement; exact real-artifact path, size, and SHA-256; exact
  native-entry-point and SetupAPI/Newdev allowlists; exact device binding;
  audited dry-run and rollback evidence; per-call Windows-mutation
  classification; envelope-bound operator confirmation; and independent audits
  before and after implementation. The current repository does not satisfy
  this envelope, and this task grants no execution or artifact-access authority.
- Tracked text evidence uses explicit `canonical_lf_text`; raw working-tree
  identity is informational. Compile outputs use `raw_file_bytes`.
- Old v1 compile-output hashes are superseded historical ignored derived
  artifacts. Current acceptance relies on schema v2 evidence binding current
  outputs and audit-output-root reruns, not preservation of v1 output bytes.
- Audit-root reruns are contained under ignored `artifacts/`, including paths
  with spaces, and cannot delete the canonical output root.

## Exact-instance framework status

The independent audit of the initial T1-T25 framework failed because
restoration identity, evidence origin, execution authorization, cross-runtime
hashing, duplicate JSON handling, runtime schema parity, Unicode identifiers,
analyzer scope, and readiness blockers were fail-open or incomplete.

Remediation commits `a969745f589a55243ca9f9e964a45d7104f9a5e8` and
`c3c0930db1326d56808879f12a9e8951f0051e80` implement the offline corrections.
Commit `fd70e9779056b336b43d09be97e686fa61ed5514` makes complete analyzer
evidence isolated and deterministic. None implements or invokes SetupAPI/Newdev.

Commit `0060cd91be7d460f1a4141f6bf893bd56b32bf35` implements the
offline exact-instance binding and restoration framework. It adds pure plan,
snapshot, path, identity, evidence, authorization, and transition contracts;
a deterministic fake adapter; exact synthetic bind/restore orchestration; a
public default-Plan wrapper with no live adapter; versioned schemas; and
T1-T25 coverage.

Corrective commit `fdcd9448a3dc172213c07928af45d2e68fd0197a`
updates the authoritative 43/6/49 PowerShell inventory and makes manifest
generation run PSScriptAnalyzer error-severity checks when the analyzer is
available.

- Exact-instance suite: `PASS`, 39 records, 155 assertions.
- Full readiness suite: `PASS`, 343 records, 1,879 assertions.
- Category `exact-instance-offline`: 39 records, 155 assertions.
- State machine: all 50 allowed edges accepted; five prohibited probes
  rejected.
- Four-direction Windows PowerShell/PowerShell 7 plan and snapshot validation:
  `PASS`; canonical bytes and hashes match in all directions.
- Complete PSScriptAnalyzer scope: 45 `.ps1` and six `.psm1`; errors `0`,
  warnings `166`, information `910`, tool failures `0`.
- Live binding/restoration/restart, live observations, and Windows mutations:
  all `0`.
- Live readiness: `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_AUDIT`.
- Capability blocker: `BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`.
- Live adapter status: `NOT_IMPLEMENTED`; live authorization: `false`.

The exact-instance definition, Windows API design, operation-plan and snapshot
contracts, failure model, and remaining gates are authoritative in
`docs/EXACT-INSTANCE-BINDING-RESTORATION-DESIGN.md`.

## Enforcement remediation status

The second independent audit found unsupported PASS paths in the readiness
framework. The enforcement remediation fixes those paths while deliberately
keeping the live gate closed.

## Validator-totality remediation status

The third independent audit found remaining uncontrolled exception paths and
unsupported lifecycle-transition acceptances. The validator-totality
remediation is offline-only and keeps the live gate closed.

## Manifest count-validation and branch-provenance remediation status

The independent corrective audit of the empty-subset remediation found two
readiness-evidence defects. First, a corrupted isolated manifest with
`assertion_count = 1.5` failed only because aggregate totals no longer matched;
when dependent totals were adjusted to the value PowerShell would coerce, the
validator passed. Second, the readiness-manifest generator recorded the correct
branch only because the prior branch name was hard-coded.

- Current branch:
  `feature/runtime-bringup-manifest-validator-integral-count-remediation`.
- Corrective implementation commit:
  `72abd0695e34e27d075cb10fdf5b381418bcce1d`.
- The validator now validates count-like fields before conversion. Valid count
  values must be JSON numeric scalars, non-negative where used as counts, in
  signed 64-bit integer range, and have no nonzero fractional component.
  Numeric-looking strings, Boolean values, nulls, arrays, objects, missing
  count fields, fractional values such as `1.5`, `0.1`, `-0.5`, and `2.0001`,
  and oversized values are explicit invalid-integer defects.
- Integer-valued numeric representations such as `1.0` are accepted
  deliberately; this is the documented schema rule for numeric JSON values
  whose fractional component is zero.
- The regression suite creates only temporary isolated manifest copies. F1
  through F4 fail with explicit invalid-integer defects, F5 proves `1.0`
  behavior, and the self-consistent `1.5` coerced-total bypass fails instead
  of passing.
- The malformed-count matrix covers missing property, null, nonnumeric string,
  numeric-looking string, Boolean, array, object, negative integer, fractional
  number, and oversized numeric value. These cases report controlled defects,
  zero uncontrolled exceptions, and no `PropertyNotFoundException`.
- Empty-subset regressions remain preserved: omitted harness and
  `assertion-accounting-negative` subsets fail through controlled accounting
  defects.
- The manifest generator derives the checked-out local branch using Git
  symbolic-ref behavior. Detached HEAD is rejected with a clear failure rather
  than recording a stale hard-coded branch. A local/upstream name mismatch is
  expected to record the local branch name.
- Canonical framework status remains `PASS`; live readiness remains
  `BLOCKED`; blocker remains `BLOCKED_NOT_IMPLEMENTED`; the suite remains 304
  records and 1,724 assertions.

## Manifest-validator empty-subset remediation status

The independent read-only audit of runtime-observer provenance and assertion
accounting accepted the prior implementation but found one remaining
manifest-validator totality defect. In an isolated corrupted manifest copy,
removing all `harness-self-test` records caused the validator to hit a
StrictMode `PropertyNotFoundException` while summing an empty subset instead
of returning a controlled accounting failure.

- Current branch:
  `feature/runtime-bringup-manifest-validator-empty-harness-remediation`.
- Corrective manifest-validator implementation commit:
  `eef5b9c151c884eefaa0157e32446e481db73bb4`.
- Corrective manifest-generator identity commit:
  `f4e98e5719230bd40c7096d2a48efb788eeb5a7d`.
- The manifest validator now aggregates record and assertion counts with an
  explicit integer-sum helper. Empty subsets sum to zero, while missing, null,
  Boolean, array, nonnumeric, and negative count values are controlled
  accounting defects.
- The opt-in corruption regression uses temporary isolated manifest copies and
  does not mutate tracked evidence. The cases for all omitted harness records,
  one omitted harness record, and all omitted `assertion-accounting-negative`
  records fail with controlled accounting defects, zero uncontrolled
  exceptions, and no `PropertyNotFoundException`.
- Canonical framework status remains `PASS`; live readiness remains
  `BLOCKED`; blocker remains `BLOCKED_NOT_IMPLEMENTED`; the suite remains 304
  records and 1,724 assertions.

## Runtime-observer provenance and assertion-accounting remediation status

The independent stop-linkage audit accepted the flat linkage remediation but
returned `AUDIT FAIL` for two remaining defects. First, each of the five
runtime observers could return PASS when `evidence_available=true` and
`triggered=false` without source, session, host, timestamp, producer, artifact,
or condition-specific provenance; explicitly synthetic evidence also passed.
Second, the suite reported 921 assertions from 915 fixture assertions plus six
separately counted harness checks, while category totals covered only the 915
fixture assertions.

- Current branch:
  `feature/runtime-bringup-observer-provenance-accounting-remediation`.
- Primary implementation commit:
  `b6b62a974bf7705e4cabc0bc98ffa44bf0718ddb`.
- Corrective no-BOM generator commit:
  `ac0e25c5f5cab5cc2c3e3ae382b455bb0aaffd10`.
- `Test-ChatpadRuntimeObservationRecordShape` validates record structure
  without granting runtime authorization. Closed source classifications are
  `live`, `synthetic`, `sample`, `planned`, and `unknown`; closed observation
  modes are runtime evaluation, contract-only fixture validation, and
  synthetic negative testing.
- Runtime provenance requires observation/condition/session/host IDs, approved
  producer `ChatpadRuntimeObservation/v1`, exact observer path
  `tools/Test-ChatpadRuntimeObservation.ps1`, ordered and fresh timestamps,
  a positive age policy, artifact ID/path/size/SHA-256, collection result,
  matching session/host/condition IDs, and the condition-specific evidence
  type and payload.
- A runtime-evaluation PASS additionally requires source `live`, a false
  synthetic marker, and an existing repository-contained runtime-evidence file
  whose actual size and SHA-256 match the record. No live record or artifact
  was created by this remediation.
- The five condition-specific evidence types are
  `device-inventory-diff`, `driver-service-transition`,
  `code-integrity-event`, `setupapi-match-analysis`, and
  `input-behavior-observation`. A generic nonempty object is rejected.
- Five missing-provenance probes and five explicit synthetic-source probes
  produce zero PASS results. The complete 140-case observer provenance matrix
  has zero unsupported runtime PASS results and zero uncontrolled exceptions.
  Live observations evaluated: `0`.
- The six harness checks are now ordinary one-assertion fixture records.
  There is no separate assertion counter. Record and category totals are
  calculated from fixture records and independently recomputed from the bound
  suite evidence by the manifest validator.
- Final accounting is 304 fixture/result records and 1,724 assertions:
  record count `304`, category record sum `304`, record assertion sum `1,724`,
  and category assertion sum `1,724`. Unassigned, off-ledger,
  duplicate-counted, and category-reconciliation defect counts are all `0`.
- Framework status remains `PASS`; live readiness remains `BLOCKED`; blocker
  remains `BLOCKED_NOT_IMPLEMENTED`. Exact binding, exact restoration, broad
  approved install, and broad approved rollback operation counts remain zero.
- PSScriptAnalyzer remains `SKIPPED_UNAVAILABLE`.

### Final assertion ledger

| Category | Records | Assertions |
| --- | ---: | ---: |
| accepted-baseline-identity | 1 | 4 |
| assertion-accounting-negative | 18 | 108 |
| authorization | 1 | 4 |
| binary-identity | 1 | 5 |
| collection-shape | 10 | 50 |
| collection-shape-structural | 10 | 50 |
| committed-sample | 1 | 4 |
| current-driver | 1 | 5 |
| event-log | 1 | 5 |
| evidence | 2 | 10 |
| harness-self-test | 6 | 6 |
| host | 1 | 5 |
| install | 2 | 10 |
| nested-array-rejection | 2 | 12 |
| nested-quoting | 1 | 4 |
| operation | 2 | 10 |
| operation-lifecycle | 32 | 181 |
| package-semantic | 1 | 6 |
| powershell-inventory | 1 | 14 |
| reconciliation | 1 | 5 |
| rollback | 2 | 10 |
| rollback-totality | 12 | 60 |
| runtime-observer-linkage | 6 | 26 |
| runtime-observer-provenance | 140 | 700 |
| runtime-observer-shape | 5 | 20 |
| schema-semantic | 4 | 20 |
| schema-structural | 1 | 4 |
| semantic-transition | 8 | 40 |
| signing | 2 | 10 |
| stop-condition-linkage | 14 | 82 |
| target | 1 | 5 |
| target-totality | 12 | 60 |
| validator-totality | 1 | 184 |
| wpp | 1 | 5 |
| **Total** | **304** | **1,724** |

## Prior stop-linkage final remediation status

The fifth independent audit confirmed the operation-lifecycle, committed
sample, and PowerShell inventory repairs, then found two residual defects:
stop-condition linkage arrays were double-wrapped at the validator call site,
and this document still named an older remediation audit as the next task.

- Prior branch:
  `feature/runtime-bringup-stop-linkage-final-remediation`.
- Prior implementation commit:
  `a810d8ba3438a08cfa4742e53be61f64be5aa58e`.
- Framework validation is `PASS`; live installation readiness is `BLOCKED`;
  blocker is `BLOCKED_NOT_IMPLEMENTED`.
- Executable exact-instance binding operations: `0`; executable
  exact-instance restoration operations: `0`; broad approved install
  operations: `0`; broad approved rollback operations: `0`.
- Operation lifecycle validation now requires explicit `start_timestamp` and
  `completion_timestamp` for executed, failed, and rolled-back operations,
  validates timestamp syntax and order, checks result object identity, exit
  code, and outcome consistency, and rejects the exact missing-start-timestamp
  probe with reason `start-timestamp-missing`.
- Lifecycle validation is centralized in `Test-ChatpadOperationPlanContract`
  and reused by runtime evidence semantic validation. Planned, blocked, and
  skipped_authorization states reject execution evidence; blocked states
  require valid stop-condition IDs; skipped_authorization requires
  authorization evidence; rolled_back and restored states require their
  lifecycle-specific evidence.
- The committed sample
  `docs/evidence/runtime-bringup-sample-evidence.json` is explicitly
  synthetic, keeps live readiness blocked, uses `artifacts` and `operations`
  arrays, contains unique IDs and valid session/host/dependency linkage, and
  passes both structural schema validation and semantic validation from its
  actual repository path.
- PowerShell inventory reporting is derived from Git-tracked paths: 41 `.ps1`,
  2 `.psm1`, 43 total tracked PowerShell files; all 43 parse with zero AST
  errors and no exclusions.
- Stop-condition linkage uses one canonical shape: a flat repository-relative
  array of unique normalized `.ps1` paths. The validator rejects nested
  arrays, scalar values, null/non-string/empty items, traversal, wildcards,
  nonexistent paths, duplicate normalized paths, unknown IDs, missing
  linkage, and runtime-observer conditions represented as executable offline.
- All 20 stop-condition IDs are unique and linked exactly once. The five
  runtime-observer conditions link to
  `tools/Test-ChatpadRuntimeObservation.ps1`; unlinked, unknown, malformed,
  and accepted nested-array counts are all zero.
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
- The prior offline suite reported 140 fixtures and 921 assertions. The
  malformed-input matrix covers 15 public validators and 180 cases.
  Uncontrolled exceptions:
  `0`; `PropertyNotFoundException` count: `0`; StrictMode exception count:
  `0`; invalid lifecycle acceptance count: `0`; missing-start-timestamp
  acceptance count: `0`.
- PSScriptAnalyzer remains `SKIPPED_UNAVAILABLE`; no network installation was
  attempted and unavailable static analysis is not counted as PASS.

- Authoritative machine status is split: framework validation is `PASS`, live
  installation readiness is `BLOCKED`, and the blocker is
  `BLOCKED_NOT_IMPLEMENTED`. Documentation may describe this as pass with a
  blocker, but machine-readable evidence must not use top-level PASS as runtime
  authorization.
- Repository identity is dual for the current generation. Validators
  distinguish the frozen accepted baseline, prior final-contract
  implementation commit `4661c1d2a4ce94bd1d7852c716b885c03b8ad7d6`,
  prior final-contract finalization commit
  `30da5003aba75ef0f079c9a8c2c90df3768601d5`, current stop-linkage
  implementation commit `a810d8ba3438a08cfa4742e53be61f64be5aa58e`,
  and the finalization commit supplied as an exact external audit input after
  commit creation. The tracked manifest avoids self-reference.
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

## Compiled-artifact metadata-review design gate

Repository investigation previously found no approved static managed metadata
parser. The remediated non-loading design gate passed independent audit at
`49b41dad087a3d7e6f4db7f52cd51a0c17eed222`. The remediated parser
implementation now passed independent audit at
`f0be4746ad4cc548334336c1e66f07007b71859f`. The authorization-plumbing
audit was accepted at `dca0a9d794b4442de86d53a90e4aab74dfe68971`, and the
transition `3bb2e73a833b99876b1cb5e90452d47a0070c65a` advanced to
`BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION`.
The runtime blocker remains
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

The future allowlist is inert PE/CLI byte parsing through an isolated .NET 9
tool using `System.Reflection.Metadata`, `PEReader`, and `MetadataReader`.
It covers assembly identity, target framework, architecture, module kind,
metadata tables, P/Invoke maps/flags, expected type/method names, and
entry-point absence. The parser design passed independent audit at
`468e8679388481e923a37a985055046f72480921`; the parser implementation was
added and validated only against synthetic fixtures. The first implementation
audit failed because the parser could be pointed at the real compile-only
artifact path under the current gate and because safety flags were not
authoritatively enforced. The remediation adds a pre-read real-artifact-like
path gate, limits current parser input to parser-specific synthetic fixture
roots under ignored `artifacts/logs/`, and enforces immutable static-only
safety policy. A second independent audit then failed because the
`--expected` read path and `--output` write path were not scope-gated. The
file-scope remediation now centrally classifies `--input`, `--expected`, and
`--output` before caller-selected I/O, limits both read paths to synthetic
fixture roots, limits output to parser evidence roots, rejects collisions and
existing outputs, and uses create-new output semantics. A third independent
audit failed because rejected input/expectation paths still wrote an
authorized parser evidence file and because manifest validation accepted only
one hardcoded evidence path. The current remediation exits before output for
every file-preflight rejection, emits zero-I/O console diagnostics for the
test harness, and validates both standard and independent parser evidence
below constrained parser-specific ignored roots. Successful synthetic runs
retain create-new evidence output.

The accepted parser validates that a real-review request is backed by the
authorization gate, accepted parser audit commit, recorded authorization
transition commit, native execution blocker, live-readiness blocker, and exact
compile-only evidence identity. Historically, the first separately authorized
real-artifact review attempt failed closed before artifact I/O because the
parser's authorization status boundary still accepted only
`ACCEPTED_STATIC_ONLY`, while the manifest recorded
`ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED`. At that historical
point the parser was not run normally against the real compile-only artifact,
the artifact was not opened, hashed, parsed, written, overwritten, or
inspected, and metadata review was not performed. See
`docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md`.

The status-boundary remediation updates that parser check to accept only
`ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED` as the
real-artifact preflight authorization fixture status. Old, pending, missing,
empty, null, non-string, synthetic-only, implemented-pending-audit, and
accepted-like lookalike parser statuses remain rejected before real-artifact
I/O. Because parser source changed after authorization-plumbing acceptance,
the gate historically moved to
`BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_STATUS_BOUNDARY_AUDIT`. The later
authorized real-artifact static metadata review completed. The post-audit
vocabulary-design remediation audit passed at
`83eb4acf44d50d8c43a09f7827728763e726e9c2`. The repository applied
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`,
`STATUS_BOUNDARY_ACCEPTED`, and
`STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED`
as the accepted post-audit vocabulary. The static metadata lane is closed.
Live readiness remains `BLOCKED`, native execution remains `NOT_IMPLEMENTED`,
and runtime/native/device/Windows/driver work remains unauthorized.

The first plumbing audit failed at `cb34346d3a2268b92a295e9d135609c1e45e2c68`.
The remediation accepts only canonical independent audit/remediation roots
with hexadecimal commit suffixes, converts malformed authorization manifests
to structured zero-I/O denials, and excludes the canonical readiness manifest
from its own generated entry set. Its independent audit passed, but the later
real-review preflight exposed the stale accepted-status parser boundary.

That remediation is exactly
`2d7a721ce3172b338df0de56853a256b1170fb4a`. Its re-audit found that the
authorized combined
`independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-<hex>`
root was still rejected and that missing or non-object required nested
manifest nodes could reach undefined `JsonElement` property access. The
focused child remediation accepts only that additional 7-to-40-character
hexadecimal family and rejects every required nested-object shape failure as
structured `AUTHORIZATION_MANIFEST_MALFORMED` with zero real-artifact I/O. It
passed independent audit; live readiness stays `BLOCKED`, native execution
stays `NOT_IMPLEMENTED`, and the runtime blocker remains
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

The accepted remediation validates 63 metadata-review safety fields as strict
JSON Booleans, records field-level defects for non-Boolean values, requires
`native_execution_status: NOT_IMPLEMENTED`, and validates
`NO_ARTIFACT_OPEN_DESIGN_GATE_AUDIT` with artifact opening, compiled-output
hash verification, and metadata parsing recorded as not performed.

## Exact-Instance Binding Analysis

The exact-instance binding analysis is completed from the accepted tracked
live read-only observation evidence with status
`EXACT_INSTANCE_BINDING_ANALYSIS_COMPLETED_FROM_ACCEPTED_OBSERVATION_NO_NATIVE_IO_NO_MUTATION`
and evidence path `docs/evidence/exact-instance-binding-analysis.json`. The
analysis records a three-node PnP chain, not a single flat device:
`USB\VID_045E&PID_028E\1C21F10` ->
`USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00` ->
`HID\VID_045E&PID_028E&IG_00\9&2E72F677&0&0000`, sharing ContainerId
`{828F4587-006F-5AD1-B169-6AF57905DFDE}`.

The primary analysis target is the USB HID interface child
`USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00` because it carries
`VID_045E&PID_028E&IG_00`, uses `HidUsb`, and parents to the Xbox composite
node. The HID game-controller child remains important for identity correlation
and runtime behavior reasoning, but it is already HID-enumerated. The
root/composite Xbox node remains the physical/container anchor, but selecting
it blindly may affect broader Xbox controller function. This is analysis only:
no new live observation, device query, hardware access, binding implementation,
native execution, native library load, entry-point resolution, SetupAPI/Newdev
invocation, Windows mutation, driver action, artifact access, or
compile-output access occurred or is authorized. Live readiness remains
`BLOCKED`, native execution remains `NOT_IMPLEMENTED`, execution authorized
remains `false`, and the blocker remains
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## Exact-Instance Binding Implementation Design Gate

The exact-instance binding implementation design gate is opened with status
`EXACT_INSTANCE_BINDING_IMPLEMENTATION_DESIGN_GATE_OPENED_NO_NATIVE_IO_NO_MUTATION`
and evidence path
`docs/evidence/exact-instance-binding-implementation-design-gate.json`. This
is documentation/manifest-only and does not implement binding. It defines a
future implementation contract for the accepted USB HID interface target
candidate `USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`, while preserving the
root/composite node and HID game-controller child as correlation and
precondition evidence.

Before any future action could proceed, a later separately authorized task
must require exact target identity, `HIDClass`, `HidUsb`, the accepted
HardwareId, the accepted parent, the shared ContainerId, the accepted source
observation status, and the accepted source analysis status. It must reject or
no-op on absent, ambiguous, partial, wrong-node, mismatched, unsafe,
artifact-dependent, or premature native/SetupAPI/Newdev-dependent states. A
future non-mutation dry-run must perform no binding, Windows mutation, driver
action, SetupAPI/Newdev invocation, or native execution; it must emit planned
action only and record exact accept/reject reasons. Future operator
confirmation, rollback/no-op, evidence, and follow-up audit requirements are
recorded in the design-gate evidence.

No binding implementation occurred. No new live observation, device query,
hardware access, native execution, native library load, entry-point
resolution, SetupAPI/Newdev invocation, Windows mutation, driver action,
artifact access, or compile-output access occurred or is authorized by this
gate. Future binding implementation remains unauthorized and requires a
separate task after independent audit. Live readiness remains `BLOCKED`,
native execution remains `NOT_IMPLEMENTED`, binding implementation status
remains `NOT_IMPLEMENTED`, execution authorized remains `false`, and the
blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## Exact-Instance Binding Dry-Run Design

The non-mutating exact-instance binding dry-run design is completed with
status
`EXACT_INSTANCE_BINDING_DRY_RUN_DESIGN_COMPLETED_NO_EXECUTION_NO_MUTATION_NO_NATIVE_IO`
and evidence path `docs/evidence/exact-instance-binding-dry-run-design.json`.
This is documentation/manifest-only. It defines a future predicate-validation
and planned-action-reporting dry-run for the accepted USB HID interface target
`USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`; it does not implement or execute
that dry-run.

The future dry-run input model must bind the source observation, source
analysis, and source design-gate evidence paths; the accepted target
InstanceId, parent InstanceId, ContainerId, HardwareIds, class, and service;
the current blocked safety state; an explicit operator-provided dry-run-only
intent; and a non-mutating dry-run mode flag. A future implementation may
require a separately authorized read-only current-state device query, but this
design task does not authorize or perform that query.

The future dry-run must validate exact InstanceId, HardwareIds, class,
service, parent, ContainerId, accepted source statuses, blocked live
readiness, `NOT_IMPLEMENTED` native execution, false execution authorization,
`NOT_IMPLEMENTED` binding implementation status, and false binding
implementation authorization. It must reject or no-op on absent, mismatched,
wrong-node, ambiguous, invalid-source, unsafe, artifact-dependent,
native-dependent, SetupAPI/Newdev-dependent, Windows-mutation-dependent, or
driver-action-dependent states.

The dry-run decision model is limited to non-mutating results:
`DRY_RUN_ACCEPTED_TARGET_NO_MUTATION_PLANNED_ACTION_ONLY`,
`DRY_RUN_REJECTED_TARGET_ABSENT_NO_MUTATION`,
`DRY_RUN_REJECTED_TARGET_MISMATCH_NO_MUTATION`,
`DRY_RUN_REJECTED_AMBIGUOUS_TARGET_NO_MUTATION`,
`DRY_RUN_REJECTED_UNSAFE_STATE_NO_MUTATION`,
`DRY_RUN_REJECTED_UNAUTHORIZED_ACTION_REQUIRED_NO_MUTATION`, and
`DRY_RUN_BLOCKED_SOURCE_EVIDENCE_INVALID_NO_MUTATION`. Planned-action reporting
is descriptive only and is not an executable instruction.

Future dry-run result evidence must use schema
`chatpad-exact-instance-binding-dry-run-result-v1` and record source evidence
chain, target identity, target chain, shared ContainerId, predicate results,
rejection results, final dry-run decision, planned-action summary,
no-mutation safety fields, current safety state, exact commands run if any are
separately authorized in that future task, skipped commands, and audit
requirements. This task did not create
`docs/evidence/exact-instance-binding-dry-run-result.json`.

No dry-run implementation occurred. No dry-run execution occurred. No binding
implementation or binding execution occurred. No new live observation, device
query, hardware access, native execution, native library load, entry-point
resolution, SetupAPI/Newdev invocation, Windows mutation, driver action,
artifact access, or compile-output access occurred or is authorized. Future
dry-run execution and future binding implementation remain unauthorized and
require separate tasks after independent audit. Live readiness remains
`BLOCKED`, native execution remains `NOT_IMPLEMENTED`, binding implementation
status remains `NOT_IMPLEMENTED`, execution authorized remains `false`, and
the blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## Exact-Instance Binding Dry-Run Execution Gate

The non-mutating exact-instance binding dry-run execution gate is opened with
status
`EXACT_INSTANCE_BINDING_DRY_RUN_EXECUTION_GATE_OPENED_NO_EXECUTION_NO_MUTATION_NO_NATIVE_IO`
and evidence path
`docs/evidence/exact-instance-binding-dry-run-execution-gate.json`. This is
documentation/manifest-only. It opens the gate for a later separately
authorized dry-run execution task after independent audit, but it does not
implement or execute the dry-run.

The future dry-run execution scope is limited to validating the accepted
source evidence chain, exact target identity, parent, shared ContainerId,
HardwareIds, class, service, blocked safety state, explicit dry-run-only
operator intent, and non-mutating mode. Its output may only answer whether the
accepted USB HID interface target is matchable, which allowed-match predicates
pass, which rejection predicates trigger, whether the future binding action
would be accepted or rejected, and what planned action would be described
without execution.

Future dry-run execution remains unauthorized until a separate task explicitly
authorizes it after audit. That future task may require a separately
authorized read-only current-state device query, but this gate does not
authorize or perform one. The future result path is
`docs/evidence/exact-instance-binding-dry-run-result.json` with schema
`chatpad-exact-instance-binding-dry-run-result-v1`; this task did not create
that file.

The future result status options remain limited to
`DRY_RUN_ACCEPTED_TARGET_NO_MUTATION_PLANNED_ACTION_ONLY`,
`DRY_RUN_REJECTED_TARGET_ABSENT_NO_MUTATION`,
`DRY_RUN_REJECTED_TARGET_MISMATCH_NO_MUTATION`,
`DRY_RUN_REJECTED_AMBIGUOUS_TARGET_NO_MUTATION`,
`DRY_RUN_REJECTED_UNSAFE_STATE_NO_MUTATION`,
`DRY_RUN_REJECTED_UNAUTHORIZED_ACTION_REQUIRED_NO_MUTATION`, and
`DRY_RUN_BLOCKED_SOURCE_EVIDENCE_INVALID_NO_MUTATION`. The future result
evidence must record the source evidence chain, target chain, shared
ContainerId, exact predicates, final dry-run decision, planned-action summary,
no-mutation safety fields, current safety state, commands run only if
separately authorized in that future task, skipped commands, and follow-up
audit requirements.

No dry-run logic implementation occurred. No dry-run execution occurred. No
future result evidence file was created. No binding implementation or binding
execution occurred. No new live observation, device query, hardware access,
native execution, native library load, entry-point resolution, SetupAPI/Newdev
invocation, Windows mutation, driver action, artifact access, or
compile-output access occurred or is authorized. Live readiness remains
`BLOCKED`, native execution remains `NOT_IMPLEMENTED`, dry-run implementation
status remains `NOT_IMPLEMENTED`, dry-run execution authorization remains
`false`, binding implementation status remains `NOT_IMPLEMENTED`, binding
implementation authorization remains `false`, and all native/device/hardware/
Windows/driver/artifact counters remain false or zero.

## Exact-Instance Binding Dry-Run Result

The first separately authorized non-mutating exact-instance binding dry-run was
executed with status
`DRY_RUN_ACCEPTED_TARGET_NO_MUTATION_PLANNED_ACTION_ONLY` and evidence path
`docs/evidence/exact-instance-binding-dry-run-result.json`. The result uses
schema `chatpad-exact-instance-binding-dry-run-result-v1`.

The dry-run performed read-only current-state predicate checks only:
`Get-PnpDevice -PresentOnly` and `Get-PnpDeviceProperty` for the three
discovered relevant PnP InstanceIds. It recorded 4 read-only query operations,
3 relevant `VID_045E&PID_028E` candidates, 1 exact target candidate, 0 skipped
commands, all allowed-match predicates passing, 0 rejection reasons, and final
decision `DRY_RUN_ACCEPTED_TARGET_NO_MUTATION_PLANNED_ACTION_ONLY`.

The planned action is descriptive only. No action was executed, actual binding
remains unauthorized, and this result does not authorize future binding,
mutation, native execution, SetupAPI/Newdev invocation, Windows mutation, or
driver action. Future binding implementation requires a separate task after
independent strict read-only audit of this dry-run result. Live readiness
remains `BLOCKED`, native execution remains `NOT_IMPLEMENTED`, binding
implementation status remains `NOT_IMPLEMENTED`, execution authorized remains
`false`, artifact/compile-output access remains false, metadata parsing
remains false, and native-library-load, entry-point-resolution,
SetupAPI/Newdev, Windows-mutation, and driver-action counters remain zero.

## Exact-Instance Binding Implementation Authorization Design Gate

The exact-instance binding implementation authorization design gate is opened
with status
`EXACT_INSTANCE_BINDING_IMPLEMENTATION_AUTHORIZATION_DESIGN_GATE_OPENED_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`
and evidence path
`docs/evidence/exact-instance-binding-implementation-authorization-design-gate.json`.
This transition is documentation/manifest-only. The accepted dry-run result
`DRY_RUN_ACCEPTED_TARGET_NO_MUTATION_PLANNED_ACTION_ONLY` is sufficient to
justify preparing the authorization design, but it is not sufficient to
authorize binding implementation or binding execution by itself.

The gate defines a future authorization contract only: future authorization
purpose, the accepted USB HID interface target
`USB\VID_045E&PID_028E&IG_00\8&2AF61D70&1&00`, the required accepted source
evidence chain, future authorization preconditions, rejection/no-op
conditions, operator confirmation package requirements, rollback/no-op plan
requirements, future authorization evidence requirements, and future audit
requirements. Selecting the root/composite node or HID game-controller child
requires separate future authorization and is not allowed by this design gate.

No binding implementation occurred. No binding execution occurred. No dry-run
was performed in this task. No new live observation, device query, hardware
access, native execution, native library load, entry-point resolution,
SetupAPI/Newdev invocation, Windows mutation, driver action, artifact access,
compile-output access, compile-output hash verification, or metadata parsing
occurred. Actual binding remains unauthorized. Future binding requires a
separate task after independent audit. Live readiness remains `BLOCKED`,
native execution remains `NOT_IMPLEMENTED`, binding implementation status
remains `NOT_IMPLEMENTED`, execution authorized remains `false`, and the
blocker remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## Exact next task

Perform an independent strict read-only audit of this exact-instance binding
implementation authorization design-gate commit. Derive its exact identity
from Git; require subject `docs: open binding implementation authorization
gate`, starting commit `3ffe4d5e7cc33ec454b0f145353a86c8cd07f7b6`,
authorization design-gate evidence schema
`chatpad-exact-instance-binding-implementation-authorization-design-gate-v1`,
authorization design-gate status
`EXACT_INSTANCE_BINDING_IMPLEMENTATION_AUTHORIZATION_DESIGN_GATE_OPENED_NO_BINDING_NO_MUTATION_NO_NATIVE_IO`,
source dry-run result evidence, source execution-gate evidence, source dry-run
design evidence, source design-gate evidence, source analysis evidence, source
observation evidence, accepted dry-run result, accepted three-node target
chain, target InstanceId, future authorization purpose, future implementation
target, required source evidence chain, future authorization preconditions,
rejection/no-op conditions, operator confirmation package requirements,
rollback/no-op plan requirements, future authorization evidence requirements,
future audit requirements, and unchanged blocked state. The audit must confirm
no binding implementation, binding execution, dry-run in this task, new live
observation, device query, hardware access, native execution, native library
load, entry-point resolution, SetupAPI/Newdev invocation, Windows mutation,
driver action, or artifact/compile-output access was authorized or performed.
