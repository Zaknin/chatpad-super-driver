# Next Task

## Objective

Perform a fresh independent, strict read-only audit of the remediated static
PE/CLI metadata parser preflight-output and evidence-path behavior.

## Required Starting State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch:
  `feature/runtime-bringup-static-metadata-parser-preflight-output-remediation`.
- Starting commit: the branch HEAD containing preflight output suppression,
  evidence-path validation, synthetic evidence, manifest, and this
  continuation document.
- Base commit: `1bdba8c823e1809306ca570f4cc5207c4412db44`.
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
- Any file-preflight rejection: exit `64`, structured console diagnostic,
  zero read/hash/parse/write counters, and no parser output file.
- Successful synthetic output: parser-specific ignored evidence root,
  create-new and no-overwrite.
- Manifest parser evidence: constrained standard or independent
  parser-specific ignored root under `artifacts/logs/`.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest relevant `docs/WORKLOG.md` entry
6. `tools/StaticMetadataParser/Program.cs`
7. `tools/Test-ChatpadStaticMetadataParser.ps1`
8. `tools/New-ChatpadRuntimeBringupReadinessManifest.ps1`
9. `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
10. `docs/evidence/static-metadata-parser-evidence-schema-v1.md`
11. `docs/evidence/runtime-bringup-readiness-manifest.json`
12. Final ignored evidence under
    `artifacts/logs/static-metadata-parser-preflight-output-remediation/`

## Audit Acceptance Criteria

- Verify every file-bearing option is centrally classified.
- Verify every rejected input, expected, or output path produces no parser
  output file and zero input/expectation read, hash, PE/metadata parse, and
  output-write counters.
- Verify the test harness records command, exit code, defect code, console
  diagnostic, and output-file absence.
- Verify successful synthetic fixtures still produce create-new evidence.
- Verify standard and independent parser evidence roots validate.
- Verify missing, empty, non-parser, compile-only, protected-name, tracked,
  metadata-review, production, and legacy evidence paths fail closed.
- Re-run synthetic validation and readiness-manifest validation under Windows
  PowerShell 5.1 and PowerShell 7.
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
