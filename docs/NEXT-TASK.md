# Next Task

## Objective

Perform a separately authorized real-artifact static metadata-review task using
the accepted static metadata parser.

## Required Starting State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch:
  `feature/runtime-bringup-static-metadata-parser-implementation-audit-acceptance`.
- Starting commit: the pushed audit-acceptance transition commit.
- Accepted parser implementation commit:
  `f0be4746ad4cc548334336c1e66f07007b71859f`.
- Current gate:
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation: `ACCEPTED_STATIC_ONLY`.
- Parser execution against the real artifact: `NOT_PERFORMED`.
- Metadata review: `NOT_PERFORMED`.
- Real artifact open/parse/hash/write: `NOT_PERFORMED`.
- Working tree and index: clean.
- Upstream: matching branch on `origin`, ahead/behind `0/0`.

## Authorization Boundary

The next task may authorize opening, reading, hashing, and parsing the real
compile-only artifact only for static metadata review through the accepted
parser. The task must still prohibit:

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
7. `docs/evidence/static-metadata-parser-evidence-schema-v1.md`
8. `docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md`
9. `tools/StaticMetadataParser/Program.cs`
10. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`

## Acceptance Criteria

- Confirm the accepted parser audit evidence and manifest gate before any real
  artifact access.
- Explicitly authorize the exact real compile-only artifact path for static
  metadata review only.
- Record artifact open/read/hash/parse counters accurately.
- Keep assembly load, runtime reflection, execution, native invocation, device
  query, Windows mutation, and driver-action counters at zero.
- Produce deterministic metadata-review evidence and update the readiness
  manifest only through the repository generator.
- Validate the manifest under Windows PowerShell 5.1 and PowerShell 7.
- Leave live readiness `BLOCKED`, native execution `NOT_IMPLEMENTED`, and the
  runtime blocker `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED` unless a
  later explicit task authorizes native implementation work.
