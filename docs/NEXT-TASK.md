# Next Task

## Objective

Perform an independent read-only source audit of the native SetupAPI/Newdev declaration and wrapper boundary. Do not compile, load, invoke, install, bind, restore, restart, query devices, mutate Windows, or execute driver behavior.

## Required Starting Point

- Branch: `feature/runtime-bringup-native-interop-source-boundary`.
- Starting commit: the final commit from the native interop source-boundary task containing:
  - `tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs`;
  - `tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1`;
  - updated exact-suite fixtures through `G132`;
  - regenerated readiness manifest and continuity documentation.
- Required ancestry: `b7672d123200f13e95353d2505bb813843ac3f7c`.
- Before work, verify a clean tree, configured upstream, local/remote equality, and exact current HEAD.

## Current State

- The production native adapter remains non-executing.
- Declaration-only SetupAPI/Newdev signatures are present in an allowlisted source file.
- No project, solution, props, targets, Add-Type path, runtime compiler path, or loader references the declaration source.
- `Apply`, `Restore`, and `Restart` expose planned call sequences only and remain blocked with `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.
- Current gate is `BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_SOURCE_AUDIT`.
- Native operation, live device query, Windows mutation, exact binding, restoration, restart, broad install, and rollback counters remain zero.

## Inspect First

- `AGENTS.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- `docs/WORKLOG.md`
- `tools/ExactInstance/NativeInterop/Chatpad.NativeInterop.SetupApiNewdev.Declarations.cs`
- `tools/ExactInstance/NativeInterop/ChatpadNativeInteropSourceBoundary.psm1`
- `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
- `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
- `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
- `docs/evidence/runtime-bringup-readiness-manifest.json`

## Safety Restrictions

- Read-only audit only unless a later task explicitly authorizes implementation.
- No native compilation, loading, invocation, generated binary, Add-Type shim, `LibraryImport` generator, project reference, or runtime API call.
- No driver build/link, signing, CAT generation, packaging, staging, driver-store mutation, installation, binding, loading, restoration, restart, reboot, device query, hardware access, Windows mutation, production driver source/INF change, frozen-binary change, or `legacy/` change.
- Keep generated audit artifacts under ignored `artifacts/`.

## Acceptance Criteria

- Verify the declaration inventory, structure layout intent, constants, Unicode/last-error choices, ownership model, cleanup plan, call plans, and error mapping.
- Independently confirm declaration source is isolated from build and runtime loading paths.
- Independently confirm executable guard categorizes allowlisted declarations separately from forbidden invocations.
- Reconcile exact-suite, readiness-suite, manifest, parser, PSScriptAnalyzer, and repository-safety evidence.
- Confirm current gate remains `BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_SOURCE_AUDIT`.
- Confirm all live/device/native/Windows mutation counters remain zero.
