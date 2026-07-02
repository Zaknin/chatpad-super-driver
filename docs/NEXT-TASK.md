# Next Task

## Exact current state

- Required branch: `feature/runtime-bringup-readiness-scaffolding`.
- Required starting commit: the final commit containing this file, with subject
  `test: scaffold controlled runtime bring-up and rollback`.
- Required parent: `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`.
- Accepted offline runtime-instrumentation baseline:
  `f49b5cbe9e6bba423cfb59313dbdc9be92c785ca`, audited as
  `AUDIT PASS WITH LIMITATIONS`.
- Provider GUID: `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`.
- Driver state: unsigned, unpackaged, unstaged, uninstalled, unloaded, and
  unexecuted.
- Runtime bring-up readiness evidence manifest:
  `docs/evidence/runtime-bringup-readiness-manifest.json`, schema
  `chatpad-runtime-bringup-readiness-manifest-v1`.

## Next recommended objective

Independent read-only audit of the runtime bring-up readiness commit. The audit
must verify the fail-closed target-selection, signing, package, rollback,
evidence, stop-condition, and authorization contracts before any live Windows
mutation is authorized.

## Preconditions

1. Verify exact branch, HEAD parent and subject, upstream equality, 0/0
   ahead/behind, and clean worktree/index.
2. Inspect the complete `f49b5cbe..HEAD` diff and confirm no production source,
   header, INF, project, solution, protocol, transport, signing credential,
   package, device state, Windows state, or `legacy/` content changed.
3. Rehash every readiness manifest entry without modifying or regenerating
   evidence.
4. Read the runtime bring-up procedure, schema, stop-condition register,
   PowerShell scaffolding, and offline synthetic test log.

## Safety restrictions

- Audit only. Do not modify files, regenerate evidence, or run live runtime
  scripts.
- Do not sign, package, create certificates/keys, stage, install, load, start a
  trace session, mutate Windows, query devices, access USB/HID/XUSB/controller/
  Chatpad state, discover/open targets, or perform request operations.
- Do not modify `legacy/`.

## Acceptance criteria

- All potentially mutating scripts default to plan-only or fixture-only modes.
- Every mutating future action requires an explicit authorization switch,
  exact target instance identity, and evidence directory.
- Target selection rejects zero, multiple, friendly-name-only, hardware-ID
  mismatch, wrong-instance, and unexpected-driver cases.
- Rollback readiness, package validation, signing readiness, WPP planning,
  evidence directory, and post-test reconciliation fail closed in synthetic
  fixtures.
- Runtime evidence schema and stop-condition register cover the required live
  session artifacts and stop boundaries.
- The readiness manifest rehashes with zero missing, duplicate, hash, size,
  state, or containment defects.

## Inspect first

- `docs/RUNTIME-BRINGUP-READINESS.md`
- `docs/evidence/runtime-bringup-evidence-schema-v1.json`
- `docs/evidence/runtime-bringup-stop-conditions.json`
- `docs/evidence/runtime-bringup-readiness-manifest.json`
- `tools/RuntimeBringup/ChatpadRuntimeBringup.Common.psm1`
- `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
- `tools/Show-ChatpadInstallPlan.ps1`
- `tools/Show-ChatpadRollbackPlan.ps1`
- `tools/Show-ChatpadWppSessionPlan.ps1`
