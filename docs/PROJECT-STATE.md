# Project State

*Last updated: 2026-07-05 (real-artifact static-review authorization plumbing pending audit)*

## Current State

- **Branch:**
  `feature/runtime-bringup-static-parser-real-artifact-authorization-plumbing`.
- **Starting commit:** `baab23aece902cbb06e11a308d9092fdc0f9ce0d`.
- **Expected final commit:** the authorization-plumbing transition commit
  containing parser, harness, manifest, evidence-schema, and continuity
  updates.
- **Current gate:**
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_AUTHORIZATION_PLUMBING_AUDIT`.
- **Runtime blocker:** `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- **Live readiness:** `BLOCKED`.
- **Native execution:** `NOT_IMPLEMENTED`.
- **Parser implementation:**
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_PENDING_AUDIT`.
- **Parser execution against the real artifact:** `NOT_PERFORMED`.
- **Metadata review:** `NOT_PERFORMED`.
- **Real artifact open/parse/hash/write:** `NOT_PERFORMED` and unauthorized.

## Static Metadata Parser

- Project: `tools/StaticMetadataParser/Chatpad.StaticMetadataParser.csproj`.
- Source: `tools/StaticMetadataParser/Program.cs`.
- Validation: `tools/Test-ChatpadStaticMetadataParser.ps1`.
- Evidence schema:
  `docs/evidence/static-metadata-parser-evidence-schema-v1.md`.
- Accepted prior synthetic evidence root:
  `artifacts/logs/static-metadata-parser-preflight-output-remediation/`.
- Current authorization-plumbing evidence root:
  `artifacts/logs/static-parser-real-artifact-authorization-plumbing/`.

The remediated static metadata parser implementation passed independent audit
at `f0be4746ad4cc548334336c1e66f07007b71859f` as static-only and
synthetic-fixture-only. The transition commit
`baab23aece902cbb06e11a308d9092fdc0f9ce0d` authorized only a narrow
implementation task to add non-caller-controlled real-artifact static-review
authorization plumbing.

This task adds a preflight-only real-artifact review scope that requires all
of the following before the parser can even authorize the exact accepted
compile-only DLL path string:

- the canonical readiness manifest still reports
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION`;
- native execution remains `NOT_IMPLEMENTED`;
- live readiness remains `BLOCKED`;
- the accepted parser audit commit remains
  `f0be4746ad4cc548334336c1e66f07007b71859f`;
- the authorization transition commit
  `baab23aece902cbb06e11a308d9092fdc0f9ce0d` is recorded in the manifest;
- the accepted compile-only evidence identity matches the recorded primary
  DLL path, size, and SHA-256.

The plumbing is pending independent read-only audit. It does not authorize a
normal parser run against the real artifact and does not authorize real
artifact open, read, hash verification, parse, output write, or metadata
review.

## Safety Boundary

- The parser has not been run normally against the real compile-only artifact.
- Metadata review has not been performed.
- Real artifact open, parse, hash verification, write, overwrite, and
  metadata parsing remain unauthorized until the authorization plumbing passes
  independent audit and a later task explicitly reopens that scope.
- Runtime assembly loading, runtime reflection, compiled-output execution,
  native DLL loading, entry-point resolution, native or SetupAPI/Newdev
  invocation, device query, hardware access, Windows mutation, and driver
  actions remain unauthorized.
- Native declarations, compile-only harness/runner behavior, runtime adapter,
  production driver source, INF, production projects/solution,
  signing/package/staging/deployment paths, binaries, frozen artifacts, and
  `legacy/` remain unchanged.

## Unresolved Blockers

- Independent read-only audit of the authorization plumbing is required before
  any real-artifact static metadata review may be retried or authorized.
- Native SetupAPI/Newdev adapter execution remains unimplemented.
- Live readiness remains blocked.

## Next Task

Perform an independent read-only audit of the real-artifact static-review
authorization plumbing. The audit must validate the gate transition,
manifest-bound transition commit, exact artifact identity matching, negative
preflight cases, evidence-root policy, and zero real-artifact I/O. Do not
retry real-artifact metadata review until that audit passes and the gate is
advanced by a separate task.
