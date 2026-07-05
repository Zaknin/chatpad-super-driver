# Next Task

## Objective

Perform an independent read-only audit of the parser real-artifact authorization
status-boundary remediation.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch:
  `feature/runtime-bringup-static-parser-status-boundary-remediation`.
- Required starting commit: the commit that contains this file and the
  status-boundary remediation; verify with Git before starting.
- Remediation starting commit:
  `906a4d098364956cbc635c5d385a98e33827404d`.
- Previous gate:
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION`.
- Current gate:
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_STATUS_BOUNDARY_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation:
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_PENDING_AUDIT`.
- Parser execution against the real artifact: `REAL_ARTIFACT_NOT_PERFORMED`.
- Metadata review: `NOT_PERFORMED`.
- Real artifact open/read/hash/parse/write: `NOT_PERFORMED`.

## Preconditions

1. Follow `AGENTS.md`.
2. Verify branch, HEAD, upstream, ahead/behind, and clean working tree.
3. Read `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the
   latest `docs/WORKLOG.md` entry.
4. Inspect the remediation diff before trusting this summary.
5. Inspect the ignored evidence under
   `artifacts/logs/static-parser-status-boundary-remediation/`.

## Safety Restrictions

This is an independent read-only audit. Do not run the parser normally against
the real compile-only artifact. Do not open, read, hash, parse, write,
overwrite, load, reflect over, execute, or perform metadata review on the real
compile-only DLL.

Do not invoke native APIs, SetupAPI/Newdev, load native DLLs, resolve entry
points, query devices, access hardware, mutate Windows, or build/link/sign/CAT/
package/stage/install/load/unload/bind/restore/restart a driver.

Do not modify native declaration source, compile-only harness behavior, runtime
adapter implementation, production driver source, INF, project/solution files,
packaging/signing/staging/deployment paths, binaries, frozen artifacts, or
`legacy/`.

## Acceptance Criteria

- Confirm the parser accepts only
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED` for the
  preflight-only real-artifact authorization fixture.
- Confirm old, pending, missing, empty, null, non-string, synthetic-only,
  implemented-pending-audit, status-boundary-pending-audit, and accepted-like
  lookalike parser statuses reject before real-artifact I/O.
- Confirm current repository gate remains
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_STATUS_BOUNDARY_AUDIT`.
- Confirm real-artifact metadata review remains not performed.
- Confirm all prohibited counters remain zero.
- Confirm repository safety, forbidden generated-file scan, prohibited-pattern
  review, documentation consistency, and `git diff --check` pass.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `tools/StaticMetadataParser/Program.cs`
7. `tools/Test-ChatpadStaticMetadataParser.ps1`
8. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
9. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
10. `docs/evidence/runtime-bringup-readiness-manifest.json`
11. `artifacts/logs/static-parser-status-boundary-remediation/status-boundary-validation-summary.json`
12. `artifacts/logs/static-parser-status-boundary-remediation/artifact-inventory.json`
