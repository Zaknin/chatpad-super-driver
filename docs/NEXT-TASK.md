# Next Task

## Objective

Perform a fresh independent, strict read-only audit of the remediated static
PE/CLI metadata parser file-scope implementation.

## Required Starting State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch:
  `feature/runtime-bringup-static-metadata-parser-file-scope-remediation`.
- Starting commit: the branch HEAD containing the central file-scope
  remediation, synthetic evidence, manifest, and this continuation document.
- Base commit: `0036474fc241c0ad1957470b87a7443a69d28e2e`.
- Working tree and index: clean.
- Upstream: matching branch on `origin`, ahead/behind `0/0`.

## Current State

- Current gate:
  `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation: `IMPLEMENTED_PENDING_AUDIT`.
- Parser execution: `SYNTHETIC_FIXTURES_ONLY`.
- Metadata review: `NOT_PERFORMED`.
- Real artifact open/parse/hash/write: `NOT_PERFORMED`.
- File-bearing options: `--input`, `--expected`, and `--output`.
- Read policy: parser-specific ignored synthetic fixture roots only.
- Write policy: parser-specific ignored evidence roots only, create-new and
  no-overwrite.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest relevant `docs/WORKLOG.md` entry
6. `tools/StaticMetadataParser/Program.cs`
7. `tools/Test-ChatpadStaticMetadataParser.ps1`
8. `docs/evidence/static-metadata-parser-evidence-schema-v1.md`
9. `docs/evidence/runtime-bringup-readiness-manifest.json`
10. `artifacts/logs/static-metadata-parser-file-scope-remediation/static-metadata-parser-synthetic-validation.json`
11. PowerShell 7 sibling evidence root

## Audit Acceptance Criteria

- Verify every file-bearing option is classified before caller-selected I/O.
- Verify `--input` and `--expected` reject blocked roots, protected names,
  traversal, slash/case variants, out-of-scope paths, and reparse points before
  read/hash/parse.
- Verify `--output` rejects blocked/protected/out-of-scope paths, read/write
  collisions, tracked paths, existing files, and reparse paths without
  creating or overwriting the requested output.
- Verify evidence counters distinguish input read/hash, expectation read/hash,
  PE/metadata parse attempts, and output write attempt/completion.
- Re-run synthetic validation under Windows PowerShell 5.1 and PowerShell 7.
- Validate the readiness manifest under both runtimes and run targeted
  parser/manifest negative regressions.
- Confirm no real artifact open, parse, hash, write, overwrite, or metadata
  review occurred.

## Safety Restrictions

Do not run the parser against the real compile-only artifact. Do not open,
parse, hash, write, overwrite, load, reflect over, or execute that artifact.
Do not invoke native APIs, query devices, access hardware, mutate Windows, or
build/link/sign/package/stage/install/load/bind/restore/restart a driver. Do
not modify native declarations, compile-only harness/runner behavior, runtime
adapter implementation, production driver source, INF, production
project/solution files, binaries, frozen artifacts, or `legacy/`.
