# Next Task

## Objective

Apply the already accepted real-artifact static metadata review audit result as
a separate audit-acceptance transition using the repository-approved
post-audit vocabulary. Do not run the parser or open, read, hash, parse, write,
overwrite, load, reflect over, execute, or perform metadata review on the real
compile-only DLL.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/runtime-bringup-real-artifact-static-metadata-review-authorized`.
- Starting commit: `383aaf0a65a867d2773ed91d6a5c8e9c535e4f04`.
- **Previous gate:** `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION` (pre-review).
- **Current gate:** `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_STATUS_BOUNDARY_AUDIT` (audit accepted, transition pending).
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation: `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED`.
- Parser execution against the real artifact: `STATIC_METADATA_VALIDATED`.
- Metadata review: `STATIC_METADATA_VALIDATED`.
- Real artifact open/read/hash/parse/write: `PERFORMED` (open, read, hash, parse) / `NOT_PERFORMED` (write).
- Real-artifact static metadata review audit accepted at:
  `eedf2a515734ca26c528a727e648ec987c0da0bd`.
- Selected post-audit `current_gate`:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Selected post-audit `real_artifact_path_gate_status`:
  `STATUS_BOUNDARY_ACCEPTED`.
- Selected post-audit metadata review gate status:
  `STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED`.

## Preconditions

1. Follow `AGENTS.md`.
2. Verify branch, HEAD, upstream, ahead/behind, and clean working tree.
3. Read `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the
   latest `docs/WORKLOG.md` entry.
4. Verify the accepted audit commit and the vocabulary-design decision.
5. Confirm the tracked manifest remains at the pending-transition gate before
   applying the transition.

## Safety Restrictions

This is a metadata/docs/tooling transition only. Do not run the parser against
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

- Apply `current_gate = BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Apply `real_artifact_path_gate_status = STATUS_BOUNDARY_ACCEPTED`.
- Apply metadata review gate status
  `STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED`.
- Keep runtime blocker `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Keep live readiness `BLOCKED`.
- Keep native execution `NOT_IMPLEMENTED`.
- Do not modify parser source unless a separate explicit contract requires it.
- Do not authorize SetupAPI/Newdev invocation, device query, Windows mutation,
  runtime/native execution, or driver actions.
- Confirm repository safety, forbidden generated-file scan, prohibited-pattern
  review, documentation consistency, and `git diff --check` pass.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/evidence/runtime-bringup-readiness-manifest.json`
7. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
8. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
