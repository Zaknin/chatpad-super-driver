# Next Task

## Objective

Perform an independent read-only audit of the authorized real-artifact static metadata review. Do not run the parser normally against the real compile-only artifact. Do not open, read, hash, parse, write, overwrite, load, reflect over, execute, or perform metadata review on the real compile-only DLL.

## Exact Current State

- Repository: `C:\Dev\chatpad-super-driver`.
- Branch: `feature/runtime-bringup-real-artifact-static-metadata-review-authorized`.
- Starting commit: `383aaf0a65a867d2773ed91d6a5c8e9c535e4f04`.
- **Previous gate:** `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_METADATA_REVIEW_AUTHORIZATION` (pre-review).
- **Current gate:** `BLOCKED_PENDING_REAL_ARTIFACT_STATIC_REVIEW_STATUS_BOUNDARY_AUDIT` (post-review, independent audit pending).
- Runtime blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Live readiness: `BLOCKED`.
- Native execution: `NOT_IMPLEMENTED`.
- Parser implementation: `ACCEPTED_STATIC_ONLY_WITH_AUTHORIZATION_PLUMBING_ACCEPTED`.
- Parser execution against the real artifact: `STATIC_METADATA_VALIDATED`.
- Metadata review: `STATIC_METADATA_VALIDATED`.
- Real artifact open/read/hash/parse/write: `PERFORMED` (open, read, hash, parse) / `NOT_PERFORMED` (write).

## Preconditions

1. Follow `AGENTS.md`.
2. Verify branch, HEAD, upstream, ahead/behind, and clean working tree.
3. Read `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and the
   latest `docs/WORKLOG.md` entry.
4. Inspect the evidence file:
   `artifacts/logs/real-artifact-static-metadata-review/static-metadata-parser-real-artifact-review.json`
5. Inspect the evidence inventory:
   `artifacts/logs/real-artifact-static-metadata-review/evidence-inventory.json`

## Safety Restrictions

This is an independent read-only audit. Do not run the parser normally against
the real compile-only artifact. Do not open, read, hash, parse, write,
overwrite, load, reflect over, execute, or perform metadata review on the real
compile-only DLL.

Do not invoke native APIs, SetupAPI/Newdev, load native DLLs, resolve entry
points, query devices, access hardware, mutate Windows, or build/link/sign/CAT/
package/stage/install/load/unload/bind/restore/restart a driver.

Do not modify native declaration source, compile-only harness behavior, runtime
adapter implementation, production driver source, INF, project/solution files,
packaging/signing/staging/deployment paths, binaries, frozen artifacts, or
`legacy/`.

## Acceptance Criteria

- Confirm the review evidence file exists at:
  `artifacts/logs/real-artifact-static-metadata-review/static-metadata-parser-real-artifact-review.json`
- Confirm evidence file size is 23,302 bytes.
- Confirm evidence file SHA-256 is `024693B23AA26C42CD2F9D5AB995956CEB202A76FBA5481264EF828AAEDF0875`.
- Confirm `Result = PASS` and `ResultCode = STATIC_METADATA_VALIDATED`.
- Confirm input path is the exact approved DLL:
  `artifacts/compile-only/native-interop/bin/Release/x64/net9.0-windows10.0.26100.0/Chatpad.NativeInterop.CompileOnlyValidation.dll`
- Confirm input size is 11,264 bytes.
- Confirm input SHA-256 is `77E352F13B7B0C0115CD3518A16865FA463E6FA8D330F5AFBBB300B14D91B862`.
- Confirm type definitions count is 24.
- Confirm method definitions count is 71.
- Confirm P/Invoke declarations count is 13.
- Confirm actual modules are `newdev.dll`, `setupapi.dll`.
- Confirm all forbidden safety counters are zero:
  AssemblyLoadOccurred, RuntimeReflectionOccurred, NativeDllLoadOccurred,
  NativeInvocationOccurred, DeviceQueryOccurred, WindowsMutationOccurred,
  DriverActionsOccurred.
- Confirm defects are empty or contain only repository-approved non-fatal diagnostics.
- Confirm repository safety, forbidden generated-file scan, prohibited-pattern
  review, documentation consistency, and `git diff --check` pass.

## Inspect First

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. `docs/NEXT-TASK.md`
5. Latest `docs/WORKLOG.md` entry
6. `artifacts/logs/real-artifact-static-metadata-review/static-metadata-parser-real-artifact-review.json`
7. `artifacts/logs/real-artifact-static-metadata-review/evidence-inventory.json`
