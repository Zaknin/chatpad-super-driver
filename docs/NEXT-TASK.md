# Next Task

## Objective

Perform an independent read-only re-audit of the remediated native
SetupAPI/Newdev adapter capability-boundary design gate. Do not implement or
execute native adapter behavior.

## Required Starting Point

- Branch: `feature/runtime-bringup-native-adapter-capability-boundary-remediation`.
- Starting commit: the finalization commit containing this file, the corrected
  gate implementation from
  `0b3197ba03302bb835fa673685499f957be52c52`, regenerated readiness manifest,
  and continuity updates.
- Before audit work, verify a clean tree, configured upstream, local/remote
  equality, and ancestry from audited commit
  `3c9c04f1870238ad2869c26fc5884d80b961fcc0`.

## Current State

- The native adapter work remains design-and-gate only.
- PowerShell module state is introspectable by callers in the same process;
  caller possession of a PowerShell object is not a trusted mutation boundary.
- No exported/public native adapter mutation gate accepts a caller-supplied
  mutation capability, token, sentinel, secret, object, or equivalent
  authorization value.
- The former `Get-Module ... SessionState.PSVariable.Get(...)` sentinel
  extraction path is covered by regression G16 and cannot authorize the gate.
- Adversarial regressions G16-G25 cover module-state extraction, enumeration,
  module-context invocation, session-state invocation, non-exported function
  discovery, reference wrapping, `PSCustomObject`, `PSTypeNames`, `Add-Member`,
  serialization, scalar/object spoofing, unexpected legacy parameters, exported
  API shape, and zero mutation counters.
- Static guards currently report zero native SetupAPI/Newdev/native Windows
  mutation API declarations or invocations in tracked PowerShell files.
- Full readiness remains offline and blocked for live installation:
  `BLOCKED_PENDING_INDEPENDENT_REAUDIT`.

## Preconditions

- Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, `docs/DECISIONS.md`, this file,
  and the latest `docs/WORKLOG.md` entry.
- Inspect these files first:
  - `docs/NATIVE-SETUPAPI-NEWDEV-ADAPTER-DESIGN-GATE.md`
  - `docs/EXACT-INSTANCE-BINDING-RESTORATION-DESIGN.md`
  - `tools/ExactInstance/ChatpadNativeAdapterDesignGate.psm1`
  - `tools/ExactInstance/ChatpadExactInstance.OfflineSuite.psm1`
  - `tools/Test-ChatpadRuntimeBringupReadiness.ps1`
  - `tools/Test-ChatpadRuntimeBringupReadinessManifest.ps1`
  - `docs/evidence/runtime-bringup-readiness-manifest.json`

## Safety Restrictions

- Read-only audit only.
- No native API implementation, declaration, P/Invoke, Add-Type, C# shim, DLL
  import, driver build/link, signing, CAT generation, packaging, staging,
  driver-store mutation, installation, binding, loading, restoration, restart,
  reboot, device query, hardware access, Windows mutation, production
  source/INF change, frozen-binary change, or `legacy/` change.
- Keep any audit outputs under ignored `artifacts/`.

## Acceptance Criteria

- Reproduce the former SessionState extraction exploit against the old audited
  commit or by code review of that commit, without mutation.
- Confirm the remediated public/exported API surface has no caller-supplied
  mutation capability parameter or equivalent authorization value.
- Confirm module state extraction, enumeration, module-scope `Get-Variable`,
  `& $module { ... }`, session-state invocation, and non-exported function
  discovery do not provide mutation authorization.
- Confirm wrappers, extracted references, `PSCustomObject`, `PSTypeNames`,
  `Add-Member`, serialization/deserialization, strings, numbers, Booleans,
  GUID-like values, arbitrary objects, and unexpected legacy parameters cannot
  authorize mutation.
- Re-run the exact suite, full readiness suite, manifest validation/corruption
  regression, executable guard, AST parse inventory, PSScriptAnalyzer, and
  repository safety checks without live execution.
- Confirm exact-instance opening, driver-node identity, restoration identity,
  postcondition, restart/reboot, and evidence-origin contracts remain intact.
- Confirm all live/device/Windows mutation counters remain zero.
- Leave live readiness blocked as `BLOCKED_PENDING_INDEPENDENT_REAUDIT`.
- Do not recommend native adapter implementation until this independent
  re-audit passes.
