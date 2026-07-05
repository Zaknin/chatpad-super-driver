# Next Task

## Objective

Perform a separately authorized real-artifact static metadata review using the
accepted static parser and accepted real-artifact authorization plumbing.

## Required Starting State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch:
  `feature/runtime-bringup-static-parser-auth-plumbing-audit-acceptance`.
- Starting commit: the local transition commit that records acceptance of
  `dca0a9d794b4442de86d53a90e4aab74dfe68971`; resolve its exact hash from Git.
- Accepted authorization-plumbing remediation:
  `dca0a9d794b4442de86d53a90e4aab74dfe68971`.
- Accepted parser implementation audit:
  `f0be4746ad4cc548334336c1e66f07007b71859f`.
- Current gate:
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation:
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED`.
- Parser execution against the real artifact:
  `REAL_ARTIFACT_NOT_PERFORMED`.
- Metadata review: `NOT_PERFORMED`.
- Real artifact open/read/hash/parse/write: `NOT_PERFORMED`.
- Working tree and index: clean.
- Upstream: none configured unless the transition branch is explicitly pushed.

## Approved Artifact Identity

Use only the identity already recorded in tracked accepted evidence:

- Path:
  `artifacts/compile-only/native-interop/bin/Release/x64/net9.0-windows10.0.26100.0/Chatpad.NativeInterop.CompileOnlyValidation.dll`.
- Recorded size: `11264` bytes.
- Recorded SHA-256:
  `77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862`.

## Preconditions

1. Follow `AGENTS.md` and reconcile all continuity files with live Git state.
2. Confirm the accepted audit binding in
   `docs/evidence/runtime-bringup-readiness-manifest.json`.
3. Require explicit authorization for this exact static review before opening
   the approved DLL.
4. Confirm that the task's output root is ignored, fresh, and limited to
   metadata-review evidence.
5. Stop on any path, size, hash, gate, parser, blocker, or authorization
   mismatch.

## Authorized Scope

The next task may authorize only:

- static open/read of the exact approved compile-only DLL;
- static SHA-256 verification;
- static PE/CLI metadata parsing through the accepted parser;
- metadata-review evidence generation under an approved ignored root.

## Safety Restrictions

Do not load the assembly, use runtime reflection, execute the artifact, invoke
native APIs, invoke SetupAPI/Newdev, load native DLLs, resolve native entry
points, query devices, access hardware, mutate Windows, or build, link, sign,
generate CAT files, package, stage, install, load, unload, bind, restore, or
restart a driver or device.

Do not modify parser implementation source, native declarations, compile-only
harness behavior, runtime adapter implementation, production driver source,
INF, project/solution files, packaging paths, binaries, frozen artifacts, or
`legacy/`.

## Acceptance Criteria

- The exact approved artifact identity is verified statically.
- The accepted parser performs only static PE/CLI metadata inspection.
- Deterministic metadata-review evidence is generated under an approved
  ignored evidence root.
- All runtime/native/device/Windows/driver prohibited-action counters remain
  zero.
- Live readiness remains `BLOCKED`.
- Native execution remains `NOT_IMPLEMENTED`.
- The runtime blocker remains
  `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Only after the review succeeds may a later, separate transition consider a
  metadata-review audit gate.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest relevant `docs/WORKLOG.md` entry
6. `docs/evidence/runtime-bringup-readiness-manifest.json`
7. `docs/evidence/static-metadata-parser-evidence-schema-v1.md`
8. `docs/COMPILED-ARTIFACT-METADATA-REVIEW-DESIGN-GATE.md`
9. `docs/STATIC-METADATA-PARSER-IMPLEMENTATION-DESIGN.md`
10. `tools/StaticMetadataParser/Program.cs`
11. `tools/Test-ChatpadStaticMetadataParser.ps1`
