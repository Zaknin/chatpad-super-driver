# Project State

*Last updated: 2026-07-04 (static metadata-parser file-scope remediation)*

## Current State

- **Branch:**
  `feature/runtime-bringup-static-metadata-parser-file-scope-remediation`.
- **Starting commit:** `0036474fc241c0ad1957470b87a7443a69d28e2e`.
- **Expected final commit:** the file-scope remediation commit containing the
  central read/write path gate, expanded synthetic evidence, regenerated
  manifest, and continuity updates.
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
- Evidence:
  `artifacts/logs/static-metadata-parser-file-scope-remediation/static-metadata-parser-synthetic-validation.json`.

The second independent implementation audit of
`0036474fc241c0ad1957470b87a7443a69d28e2e` failed because `--expected`
could reach file I/O without scope authorization and `--output` could target
unsafe paths. The remediation centrally classifies all file-bearing options
before caller-selected I/O:

- `--input` and `--expected` are read paths limited to parser-specific
  synthetic fixture roots;
- `--output` is a write path limited to parser-specific ignored evidence
  roots;
- output may not collide with either read path, target an existing file,
  traverse a reparse point, resolve outside the evidence scope, or contain the
  protected compile-only DLL name;
- evidence output uses create-new, no-overwrite semantics.

Synthetic validation passed under Windows PowerShell 5.1 with five fixtures,
573 assertions, eight input-path rejections, one input reparse case not run,
eight expected-path rejections, twelve output-path rejections, two
safety-option rejections, and zero failures. PowerShell 7 passed with five
fixtures, 592 assertions, nine input-path rejections including the directory
symlink case, eight expected-path rejections, twelve output-path rejections,
two safety-option rejections, and zero failures.

## Safety Boundary

- The parser has not been run against the real compile-only artifact.
- The accepted primary-DLL hash remains reference-only; it was not recomputed.
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

- A fresh independent read-only audit must accept the file-scope remediation
  before any real-artifact parser use can be authorized.
- Parser execution against the real artifact, metadata review, and real
  artifact open/parse/hash/write remain unauthorized.
- Native SetupAPI/Newdev adapter execution remains unimplemented.
- Live readiness remains blocked.

## Next Task

Perform a strict independent read-only audit of the file-scope-remediated
parser. Verify all file-bearing channels fail closed before unauthorized I/O
and preserve every real-artifact, runtime, native, device, Windows, and driver
safety restriction.
