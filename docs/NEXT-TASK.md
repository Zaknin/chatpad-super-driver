# Next Task

## Objective

Remediate the accepted static parser real-artifact authorization status
boundary, then produce evidence for independent audit.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch:
  `feature/runtime-bringup-real-artifact-static-metadata-review-20260705`.
- Starting commit for this blocked review:
  `3bb2e73a833b99876b1cb5e90452d47a0070c65a`.
- Current gate:
  `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION`.
- Review result: `FAIL_PARSER_BOUNDARY`.
- Parser preflight result:
  `PARSER_IMPLEMENTATION_NOT_ACCEPTED`.
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation:
  `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED`.
- Parser execution against the real artifact:
  `REAL_ARTIFACT_NOT_PERFORMED_BLOCKED_BY_PARSER_BOUNDARY`.
- Metadata review: `NOT_PERFORMED_BLOCKED_BY_PARSER_BOUNDARY`.
- Real artifact open/read/hash/parse:
  `NOT_PERFORMED_BLOCKED_BY_PARSER_BOUNDARY`.
- Real artifact write/overwrite: `NOT_PERFORMED`.

## Blocker Evidence

- Evidence root:
  `artifacts/logs/real-artifact-static-metadata-review/3bb2e73-preflight-boundary/`.
- Identity evidence source:
  `docs/evidence/native-interop-compile-only-validation.json`.
- Approved DLL path:
  `artifacts/compile-only/native-interop/bin/Release/x64/net9.0-windows10.0.26100.0/Chatpad.NativeInterop.CompileOnlyValidation.dll`.
- Expected size: `11264`.
- Expected SHA-256:
  `77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862`.
- Actual size stat: `11264`.
- Actual SHA-256: not computed because the accepted parser preflight failed
  closed before artifact read/hash/parse.
- Parser preflight console:
  `artifacts/logs/real-artifact-static-metadata-review/3bb2e73-preflight-boundary/preflight-default-manifest-console.json`.

## Required Branch and Starting Commit

Create a new remediation branch from the blocked-review final commit recorded
by Git after this task is committed. Do not reuse or rewrite the occupied local
branch `feature/runtime-bringup-real-artifact-static-metadata-review`, which
currently points at older commit `baab23aece902cbb06e11a308d9092fdc0f9ce0d`.

## Preconditions

1. Follow `AGENTS.md`.
2. Verify branch, HEAD, upstream, and clean working tree.
3. Re-read the blocked evidence root above.
4. Confirm the parser source still contains the stale accepted-status boundary
   before changing it.
5. Keep the remediation separate from real-artifact metadata review.

## Safety Restrictions

Do not open, read, hash, parse, write, overwrite, load, reflect over, execute,
or perform metadata review on the real compile-only DLL during the parser
remediation unless a later task explicitly reauthorizes that exact operation.
Do not invoke native APIs, SetupAPI/Newdev, load native DLLs, resolve entry
points, query devices, access hardware, mutate Windows, or build/link/sign/CAT/
package/stage/install/load/unload/bind/restore/restart a driver.

Do not modify native declaration source, compile-only harness behavior, runtime
adapter implementation, production driver source, INF, project/solution files,
packaging/signing/staging/deployment paths, binaries, frozen artifacts, or
`legacy/`.

## Acceptance Criteria

- Parser real-artifact authorization preflight accepts the current manifest
  status `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED`.
- Negative parser preflight cases still fail closed with zero real-artifact
  open/read/hash/parse/write and zero prohibited counters.
- Parser output remains suppressed for preflight rejection.
- Any remediation evidence remains under ignored `artifacts/`.
- Manifest generation and validation pass under Windows PowerShell 5.1 and
  PowerShell 7 if the manifest/status vocabulary is touched.
- Repository safety, forbidden generated-file scan, prohibited-pattern review,
  and `git diff --check` pass.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `tools/StaticMetadataParser/Program.cs`
7. `tools/Test-ChatpadStaticMetadataParser.ps1`
8. `docs/evidence/runtime-bringup-readiness-manifest.json`
9. `artifacts/logs/real-artifact-static-metadata-review/3bb2e73-preflight-boundary/metadata-review-summary.json`
