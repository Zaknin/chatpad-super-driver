# Next Task

## Objective

Perform an independent strict read-only audit of the native adapter execution-
scope boundary commit.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/native-adapter-execution-scope-boundary`.
- Required starting commit: the commit with subject
  `docs: define native adapter execution scope boundary`; obtain its exact full
  hash from Git, require parent
  `bb6cc27c2281e04dee2166c5a67e124092055f9f`, and require upstream
  synchronization `0/0`.
- Accepted non-live planning audit-acceptance commit:
  `bb6cc27c2281e04dee2166c5a67e124092055f9f`.
- Execution-scope boundary status:
  `NATIVE_ADAPTER_EXECUTION_SCOPE_BOUNDARY_DEFINED_NO_NATIVE_IO`.
- Execution design status:
  `NATIVE_ADAPTER_EXECUTION_DESIGN_GATE_ACCEPTED_FAIL_CLOSED_NO_ARTIFACT_IO`.
- Scaffolding status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_IMPLEMENTED_NO_NATIVE_IO`.
- Scaffolding-audit status:
  `NATIVE_ADAPTER_FAIL_CLOSED_SCAFFOLDING_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Non-live implementation status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_IMPLEMENTED_NO_NATIVE_IO`.
- Non-live planning audit status:
  `NATIVE_ADAPTER_NON_LIVE_PLAN_AUDIT_ACCEPTED_NO_NATIVE_IO`.
- Current gate and runtime blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Evidence mode: `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Installation readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.

## Preconditions

1. Follow `AGENTS.md` and verify exact branch, HEAD, parent, upstream, remote
   equality, `0/0`, and a clean tree/index.
2. Verify the candidate changed only authorized documentation, manifest, and
   manifest generator/validator paths.
3. Confirm adapter modules, offline suite, parser, artifacts, compile outputs,
   driver source, INF/project files, binaries, ignored evidence, and `legacy/`
   are unchanged.

## Audit Scope

- Verify the envelope requires exactly one operation class; exact artifact
  path, size, and SHA-256; exact library-qualified native and SetupAPI/Newdev
  allowlists without wildcards; exact device binding; audited dry-run evidence;
  exact rollback/restore evidence; per-call Windows-mutation classification;
  envelope-bound operator confirmation; and independent audits before and
  after implementation.
- Verify the reviewed declaration ceiling is not represented as a current
  invocation allowlist.
- Verify the current repository does not satisfy the envelope and every current
  artifact/native/device/hardware/Windows/driver authorization is false.
- Validate schema v4, 39 entries, duplicate IDs/paths `0`, `NO_PATH` `0`, and
  cross-runtime manifest identity under Windows PowerShell 5.1 and PowerShell
  7.

## Safety Restrictions

This is read-only. Do not edit, commit, or push. Do not run the static parser,
full compile-output validator, full exact/readiness suites, or any artifact,
native, device, hardware, Windows, or driver path. Do not open, read, hash,
parse, stat, scan, write, load, reflect over, or execute the real DLL or compile
outputs.

## Acceptance Criteria

- Scope status, accepted base, exact requirements, declaration ceiling, and all
  false current-authority fields are present and validator-enforced.
- Gate/runtime blocker remain
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`, installation readiness
  remains `BLOCKED`, native execution remains `NOT_IMPLEMENTED`, and evidence
  mode remains `EVIDENCE_RECORD_ONLY_NO_ARTIFACT_IO`.
- Manifest validation passes under both runtimes with zero defects and no
  cross-runtime differences.
- No positive authorization or prohibited executable pattern was added.
- Final Git status remains clean and synchronized `0/0`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
7. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
8. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
9. `docs/evidence/runtime-bringup-readiness-manifest.json`
