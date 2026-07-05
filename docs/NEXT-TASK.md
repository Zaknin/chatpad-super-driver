# Next Task

## Objective

Define the next repository-approved design/implementation gate for native
SetupAPI/Newdev adapter execution. Static metadata review is accepted and
closed; native execution remains unimplemented.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch:
  `feature/runtime-bringup-real-artifact-static-metadata-review-authorized`.
- Required starting commit: the audit-acceptance transition commit that follows
  `83eb4acf44d50d8c43a09f7827728763e726e9c2`; verify from Git.
- Previous gate:
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_STATUS_BOUNDARY_AUDIT`.
- Current gate and capability blocker:
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Real-artifact path gate: `STATUS_BOUNDARY_ACCEPTED`.
- Metadata/parser accepted status:
  `STATIC_METADATA_PARSER_ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_STATUS_BOUNDARY_ACCEPTED`.
- Parser implementation:
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED`.
- Metadata review: `STATIC_METADATA_VALIDATED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Static metadata lane: accepted and closed.
- Accepted audit target:
  `83eb4acf44d50d8c43a09f7827728763e726e9c2` (`AUDIT PASS`).

## Preconditions

1. Follow `AGENTS.md`.
2. Verify branch, HEAD, upstream, ahead/behind, and clean status.
3. Read the continuity documents and the audit-acceptance worklog entry.
4. Verify the canonical manifest under Windows PowerShell 5.1 and PowerShell 7.
5. Obtain an explicit repository contract before implementing or executing any
   native adapter behavior.

## Safety Restrictions

Do not load native DLLs, resolve entry points, invoke SetupAPI/Newdev or other
native APIs, query devices, access hardware, mutate Windows, or build, link,
sign, generate CAT files, package, stage, install, load, unload, bind, restore,
or restart a driver without later explicit authorization.

Do not rerun the static metadata parser or open, read, hash, parse, write,
overwrite, load, reflect over, or execute the real compile-only DLL.

## Acceptance Criteria

- Produce a precise, fail-closed native-adapter execution authorization design.
- Keep live readiness `BLOCKED` and native execution `NOT_IMPLEMENTED` until a
  separately authorized implementation and audit complete.
- Preserve the accepted static metadata evidence and manifest identities.
- Preserve zero/not-performed runtime/native/device/Windows/driver counters.
- Pass applicable offline validation, repository safety, generated-file scans,
  documentation consistency, and `git diff --check`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
7. `docs/evidence/runtime-bringup-readiness-manifest.json`
