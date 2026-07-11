# TASK 8F-R2 — Independent read-only audit of the corrected SetupAPI/Newdev declaration ABI and propagated identities

## Current state

- **Required branch:** `feature/task-8f-native-declaration-remediation`.
- **Required starting commit:** the TASK 8F-R1B commit with subject
  `fix: propagate corrected native declaration identity`; derive and verify its
  exact hash from Git after R1B finalization.
- **Required parent:** `bd56cbaed47a9a5f9ba23ea8fab075b5a6c32c57`.
- **R1A source correction:** `bd56cbaed47a9a5f9ba23ea8fab075b5a6c32c57`
  (`fix: correct SetupDiGetDriverInstallParams declaration`), parent
  `6186b37c6b1cacc3fb91c38011bc45525bcc1a54`.
- **Corrected declaration:** `SetupDiGetDriverInstallParamsW` uses
  `ref SP_DRVINSTALL_PARAMS DriverInstallParams`.
- **Corrected declaration raw identity:** 10238 bytes,
  `E55E6E34BBB4DB40904F065292F23A76D48BE809D18E7EB76E0C3A7ECCA786F2`.
- **Corrected declaration canonical-LF identity:** 10034 bytes,
  `B4D24BF374B391A36B4A3513B117A2FF50F8BC3D8795248808086AC984E874D9`.
- **Remediation evidence:**
  `docs/evidence/native-interop-declaration-remediation-task-8f-r1.json`.
- **Manifest section:** `native_interop_declaration_remediation`.
- **Current blocker:**
  `BLOCKED_NATIVE_ADAPTER_TASK_8F_NATIVE_DECLARATION_REMEDIATION_NOT_INDEPENDENTLY_AUDITED`.
- **TASK 8F:** open pending this audit. **TASK 8I:** blocked until TASK 8F
  remediation closes. Production execution remains unavailable.

## Preconditions

- Verify exact branch, HEAD, parent, subject, clean worktree/index, no untracked
  files, upstream `0/0`, and matching remote branch before auditing.
- Read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file, and
  the latest `docs/WORKLOG.md` entries.
- Re-derive R1A and R1B facts from Git and file contents. Do not trust the
  implementation report as audit evidence.
- Confirm R1A remains an exact two-file regular-text change and R1B remains
  within its authorized source/evidence/validator/documentation scope.

## Audit scope and safety restrictions

- Strict read-only repository audit only. Do not edit, stage, commit, push,
  execute native APIs, query devices/PnP/USB/HID/registry/services/drivers,
  issue or consume live authorization, construct or invoke a production
  provider, bind, mutate Windows, build the driver, sign, package, stage,
  install, load, restart, re-enumerate, rollback, restore, or access existing
  driver artifacts/compile outputs.
- Verify the Windows SDK 10.0.26100.0 provenance from `um/setupapi.h`,
  `um/newdev.h`, `shared/devpropdef.h`, and `shared/devpkey.h`.
- Verify the exact sequential `SP_DRVINSTALL_PARAMS` fields and managed types:
  `uint cbSize`, `uint Rank`, `uint Flags`, `UIntPtr PrivateData`, and
  `uint Reserved`; sizes must be 20 bytes on x86 and 32 bytes on x64.
- Verify the old `SP_DEVINSTALL_PARAMS_W` method binding is absent, the exact
  13-method and seven-structure inventories are preserved, and old/new
  declaration identities are not accepted as alternatives.
- Verify compile-only output is isolated, non-invoking, and removed after
  validation; no persistent assembly or binary may remain.
- Verify remediation evidence, manifest entries, source identities, strict
  scalar typing, ordinal arrays, evidence equality, blocker, next task, and
  every integer-zero safety counter independently.

## Acceptance criteria

- Report PASS only if the corrected ABI, raw/canonical identities, all
  propagated contracts, regenerated compile evidence, remediation evidence,
  manifest, validator, and dual-runtime results independently match.
- Run the dedicated ABI suite, canonical compile-only evidence validator,
  TASK 8E-8I focused suites, TASK 8G/TASK 8H/TASK 8F-R1 regressions, and the
  canonical readiness validator under PowerShell 7 and Windows PowerShell 5.1.
- Confirm no declaration was invoked, no device or Windows state changed, no
  production provider was constructed/invoked, no live authorization is
  active, and no operator authorization phrase is carried forward.
- A passing audit closes only the TASK 8F declaration-remediation lane. It does
  not resume TASK 8I or authorize live execution.
