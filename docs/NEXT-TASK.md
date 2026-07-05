# Next Task

## Objective

Perform a fresh independent read-only audit of the remediated real-artifact
static-review authorization plumbing.

## Required Starting State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch:
  `feature/runtime-bringup-static-parser-real-artifact-authorization-plumbing`.
- Starting commit: the pushed remediation commit whose parent is
  `cb34346d3a2268b92a295e9d135609c1e45e2c68`; resolve and record its exact
  hash from Git before auditing.
- Authorization transition base:
  `baab23aece902cbb06e11a308d9092fdc0f9ce0d`.
- Accepted parser implementation audit commit:
  `f0be4746ad4cc548334336c1e66f07007b71859f`.
- Current gate:
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_AUTHORIZATION_PLUMBING_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation:
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_PENDING_AUDIT`.
- Parser execution against the real artifact: `NOT_PERFORMED`.
- Metadata review: `NOT_PERFORMED`.
- Real artifact open/parse/hash/write: `NOT_PERFORMED`.
- Working tree and index: clean.
- Upstream: matching branch on `origin`, ahead/behind `0/0`.

## Authorization Boundary

The next task is audit-only. It may read source, documentation, tracked JSON
evidence, generated ignored parser evidence, and test logs. It must not run
the parser normally against the real compile-only artifact and must not open,
read, hash, parse, overwrite, or write the real compile-only DLL.

The audit must still prohibit:

- assembly loading;
- runtime reflection;
- compiled artifact execution;
- native DLL loading;
- entry-point resolution;
- native or SetupAPI/Newdev invocation;
- device query;
- hardware access;
- Windows mutation;
- driver build, link, sign, CAT generation, package, stage, install, load,
  unload, bind, restore, or restart.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest relevant `docs/WORKLOG.md` entry
6. `docs/evidence/runtime-bringup-readiness-manifest.json`
7. `artifacts/logs/independent-static-parser-real-artifact-authorization-plumbing-remediation-cb34346/static-metadata-parser-synthetic-validation.json`
8. `docs/evidence/static-metadata-parser-evidence-schema-v1.md`
9. `docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md`
10. `tools/StaticMetadataParser/Program.cs`
11. `tools/Test-ChatpadStaticMetadataParser.ps1`
12. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
13. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`

## Acceptance Criteria

- Reproduce that the accepted parser at
  `f0be4746ad4cc548334336c1e66f07007b71859f` stopped before real-artifact
  review authorization plumbing.
- Verify the new parser scope is preflight-only and requires the manifest
  gate, runtime blocker, live-readiness state, accepted parser audit commit,
  authorization transition commit, and exact recorded compile-only artifact
  identity.
- Verify callers cannot force the real-artifact scope with a flag alone, a
  stale/new gate, a wrong parser status, wrong live readiness, missing
  transition commit, wrong artifact path, wrong output root, or unsafe
  manifest path.
- Verify canonical
  `independent-static-parser-real-artifact-authorization-plumbing-(audit|remediation)-<hex>`
  roots are accepted while missing-hash, non-hex, lookalike, traversal,
  reparse, and unrelated roots remain rejected.
- Verify all six malformed-manifest cases return structured exit-64 denials,
  create no output, and keep every prohibited counter at zero.
- Verify successful preflight writes no parser output and performs no real
  artifact read, open, hash, parse, write, or metadata review.
- Verify Windows PowerShell 5.1 and PowerShell 7 regeneration each produce
  the same intended 39 entry identities, no duplicate IDs or normalized
  paths, and no canonical-manifest self-entry.
- Re-run the full gate/status corruption regression and record its case count,
  result, and elapsed runtime.
- Keep live readiness `BLOCKED`, native execution `NOT_IMPLEMENTED`, and the
  runtime blocker `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
