# Next Task

## Objective

Perform an independent read-only re-audit of the remediated native interop compile-only evidence, output-lineage clarification, and audit-output-root behavior.

## Required Starting Point

- Branch: `feature/runtime-bringup-native-interop-compile-only-evidence-remediation`.
- Starting commit: the final evidence/continuity commit containing implementation commit `164903a8e890dfe1eb1709eeac1272aabcb81b3e`.
- Verify exact HEAD, upstream, `0/0` ahead/behind, clean status, and unchanged native declaration/wrapper source before auditing.

## Current State

- The prior audit failed only because LF evidence identities were validated against raw CRLF working-tree bytes.
- The independent re-audit at `207d00feedb6e419d3f791fbcb757576dfb5dbba` failed narrowly because old v1 compile-output preservation had not yet been resolved as an acceptance criterion. All remediated validation behavior passed in that audit.
- Tracked text identity now uses explicit `canonical_lf_text`; raw working-tree identity is informational.
- Compile outputs use `raw_file_bytes`.
- Old v1 compile-output identities are superseded historical ignored derived artifacts. They are not preserved, are not expected to remain available, and are not required for acceptance.
- Current schema v2 evidence binding current compile outputs is the authoritative output identity.
- Compile evidence schema is `chatpad-native-interop-compile-only-validation-v2`.
- Readiness manifest schema is `chatpad-runtime-bringup-readiness-manifest-v4`.
- The compile runner supports contained ignored audit output roots, including paths with spaces.
- Live readiness is `BLOCKED`.
- Current gate: `BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_COMPILE_ONLY_REAUDIT`.
- Capability blocker: `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## Inspect First

- `AGENTS.md`
- `docs/PROJECT-STATE.md`
- `docs/DECISIONS.md`
- Latest `docs/WORKLOG.md` entry
- `docs/evidence/native-interop-compile-only-validation.json`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `tools/Invoke-ChatpadNativeInteropCompileOnlyValidation.ps1`
- `tools/RuntimeBringup/ChatpadRuntimeBringup.Common.psm1`
- `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
- `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`

## Safety Restrictions

- Do not load, reflect over, execute, or invoke the compiled assembly.
- Do not load SetupAPI/Newdev, resolve entry points, invoke native APIs, query devices/bindings, or access hardware.
- Do not build/link the driver, sign, package, stage, install, load, unload, bind, restore, restart, enable, disable, or remove a driver/device.
- Do not mutate Windows, registry, services, certificates, keys, credentials, boot state, scheduled tasks, or system configuration.
- Keep audit outputs under ignored `artifacts/`; do not modify `legacy/`.

## Acceptance Criteria

- Reproduce portable canonical identities in a clean CRLF checkout.
- Verify raw source identity differences are informational and canonical mismatches fail closed.
- Verify old v1 compile-output identity is documented as superseded historical derived output and not required for acceptance.
- Verify current remediated evidence fully binds the current compile outputs.
- Verify manifest policy corruption cases fail closed.
- Safely rerun compile-only validation in an ignored audit root and a path containing spaces.
- Prove canonical output is not deleted by audit runs.
- Verify all outputs remain raw-byte identified and no load/reflection/execution/invocation occurs.
- Re-run exact, readiness, manifest, native guard, repository safety, generated-file, and Git checks.
- Preserve the pending re-audit gate and native execution blocker.
