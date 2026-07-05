# Next Task

## Objective

Perform a fresh independent strict read-only audit of the focused
authorization-plumbing audit-root and manifest-shape remediation.

## Required Starting State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch:
  `feature/runtime-bringup-static-parser-auth-plumbing-audit-root-remediation`.
- Starting commit: the pushed focused remediation commit whose parent is
  `2d7a721ce3172b338df0de56853a256b1170fb4a`; resolve and record its exact
  hash from Git before auditing.
- First remediation:
  `2d7a721ce3172b338df0de56853a256b1170fb4a`.
- Authorization transition base:
  `baab23aece902cbb06e11a308d9092fdc0f9ce0d`.
- Accepted parser implementation audit:
  `f0be4746ad4cc548334336c1e66f07007b71859f`.
- Current gate:
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_AUTHORIZATION_PLUMBING_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation:
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_PENDING_AUDIT`.
- Parser execution against the real artifact:
  `REAL_ARTIFACT_NOT_PERFORMED`.
- Metadata review: `NOT_PERFORMED`.
- Real artifact open/read/hash/parse/write: `NOT_PERFORMED`.
- Working tree and index: clean.
- Upstream: matching remediation branch on `origin`, ahead/behind `0/0`.

## Safety Restrictions

This is audit-only. Do not run the parser normally against the real compile-only
artifact. Do not open, read, hash, parse, write, overwrite, load, reflect over,
or execute that artifact. Do not invoke native APIs, query devices, access
hardware, mutate Windows, or build/link/sign/package/stage/install/load/unload/
bind/restore/restart a driver.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest relevant `docs/WORKLOG.md` entry
6. `docs/evidence/runtime-bringup-readiness-manifest.json`
7. `docs/evidence/static-metadata-parser-evidence-schema-v1.md`
8. `tools/StaticMetadataParser/Program.cs`
9. `tools/Test-ChatpadStaticMetadataParser.ps1`
10. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
11. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
12. Remediation evidence under
    `artifacts/logs/static-parser-auth-plumbing-audit-root-remediation/`

## Acceptance Criteria

- Independently reproduce that the parent `2d7a721...` rejected the exact
  combined remediation-audit root and could expose undefined nested
  `JsonElement` access.
- Run the complete synthetic harness under
  `independent-static-parser-real-artifact-authorization-plumbing-remediation-audit-<7-40 hex>`.
- Verify the audit, remediation, and remediation-audit families are accepted
  narrowly; missing, non-hex, short, long, lookalike, traversal, protected,
  unrelated, and broad-wildcard roots remain rejected.
- Verify all fourteen malformed/shape cases produce structured exit-64
  denials, no output, zero real-artifact I/O, and zero prohibited counters.
- Verify the eight real-artifact preflight-only authorization cases without
  opening, reading, hashing, parsing, or writing the artifact.
- Verify deterministic 39-entry manifest generation and validation under
  Windows PowerShell 5.1 and PowerShell 7 with zero cross-runtime identity
  delta and no canonical self-entry.
- Verify parser-path regression, documentation consistency, repository safety,
  forbidden generated-file scan, prohibited-pattern scan, and
  `git diff --check`.
- Keep the current gate, blocker, readiness, native-execution, parser,
  execution, metadata-review, and real-artifact-I/O states unchanged.

Do not authorize or perform real-artifact metadata review. A separate
post-audit gate transition is required before that work can be considered.
