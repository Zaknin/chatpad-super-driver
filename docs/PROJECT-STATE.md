# Project State

*Last updated: 2026-07-04 (static metadata-parser preflight-output remediation)*

## Current State

- **Branch:**
  `feature/runtime-bringup-static-metadata-parser-preflight-output-remediation`.
- **Starting commit:** `1bdba8c823e1809306ca570f4cc5207c4412db44`.
- **Expected final commit:** the remediation commit containing preflight output
  suppression, parser-evidence-path policy alignment, tests, manifest, and
  continuity updates.
- **Current gate:**
  `BLOCKED_PENDING_STATIC_METADATA_PARSER_IMPLEMENTATION_AUDIT`.
- **Runtime blocker:** `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- **Live readiness:** `BLOCKED`.
- **Native execution:** `NOT_IMPLEMENTED`.
- **Parser implementation:** `IMPLEMENTED_PENDING_AUDIT`.
- **Parser execution:** `SYNTHETIC_FIXTURES_ONLY`.
- **Metadata review:** `NOT_PERFORMED`.
- **Real artifact open/parse/hash/write:** `NOT_PERFORMED` and unauthorized.

## Static Metadata Parser

- Project: `tools/StaticMetadataParser/Chatpad.StaticMetadataParser.csproj`.
- Source: `tools/StaticMetadataParser/Program.cs`.
- Validation: `tools/Test-ChatpadStaticMetadataParser.ps1`.
- Evidence schema:
  `docs/evidence/static-metadata-parser-evidence-schema-v1.md`.
- Evidence root:
  `artifacts/logs/static-metadata-parser-preflight-output-remediation/`.

The third independent implementation audit of
`1bdba8c823e1809306ca570f4cc5207c4412db44` failed because rejected
`--input` and `--expected` paths still caused authorized parser evidence
writes, and the manifest validator hardcoded the standard parser evidence
path.

The remediation now:

- centrally classifies `--input`, `--expected`, and `--output`;
- exits with code `64` before any parser output when any file path is rejected;
- emits a structured console diagnostic whose read/hash/parse/write counters
  are all zero;
- has the test harness record rejected-command evidence and prove no parser
  output file was created;
- preserves create-new, no-overwrite evidence for successful synthetic runs;
- accepts standard and independent parser evidence only below constrained
  parser-specific ignored `artifacts/logs/` roots;
- rejects missing, empty, non-parser, compile-only, real-artifact,
  metadata-review, protected-name, tracked, production, and legacy evidence
  paths.

Synthetic validation passed during remediation development under Windows
PowerShell 5.1 with five fixtures, 973 assertions, eight input-path
rejections, one input reparse case not run, eight expected-path rejections,
twelve output-path rejections, two safety-option rejections, and zero
failures. PowerShell 7 passed with five fixtures, 999 assertions, nine
input-path rejections including the directory symlink case, eight
expected-path rejections, twelve output-path rejections, two safety-option
rejections, and zero failures. Final evidence is regenerated after continuity
updates.

## Safety Boundary

- The parser has not been run against the real compile-only artifact.
- The accepted primary-DLL hash remains reference-only and was not recomputed.
- No real artifact open, parse, hash, write, overwrite, or metadata review
  occurred.
- No assembly loading, runtime reflection, compiled-output execution, native
  DLL loading, entry-point resolution, native or SetupAPI/Newdev invocation,
  device query, hardware access, Windows mutation, or driver action occurred.
- Native declarations, compile-only harness/runner, runtime adapter,
  production driver source, INF, production projects/solution,
  signing/package/staging/deployment paths, binaries, frozen artifacts, and
  `legacy/` remain unchanged.

## Unresolved Blockers

- A fresh independent read-only audit must accept this remediation before any
  real-artifact parser use can be authorized.
- Parser execution against the real artifact, metadata review, and real
  artifact open/parse/hash/write remain unauthorized.
- Native SetupAPI/Newdev adapter execution remains unimplemented.
- Live readiness remains blocked.

## Next Task

Perform a strict independent read-only audit of parser preflight-output
suppression and approved parser-evidence-path validation. Preserve every
real-artifact, runtime, native, device, Windows, and driver restriction.
