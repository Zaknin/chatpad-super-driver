# Next Task

## Exact current state

- Required branch:
  `feature/offline-runtime-instrumentation-evidence-guard-remediation`.
- Required starting commit: the final commit containing this file, with subject
  `test: repair runtime instrumentation evidence contracts`.
- Required parent: `709686f522eafc12913658b076bd0e001d6add32`.
- Provider GUID: `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`.
- Trace schema/catalogue: schema `1`, 73 semantic IDs and names.
- Emission evidence: CSV schema `2`; 94 mappings, 34 direct WPP invocations,
  78 helper mappings, and 92 unique physical sites.
- Manifest:
  `docs/evidence/runtime-instrumentation-implementation-manifest.json`, schema
  `1.2.0`.
- Driver state: unsigned, unpackaged, unstaged, uninstalled, unloaded, and
  unexecuted.

## Next recommended objective

Perform an independent read-only audit of the final remediation commit. The
audit must independently validate model-to-catalogue semantics, matrix
assertion accounting, concrete semantic-event-to-emission mapping, cleanup
inclusion in the owner guard, and the final evidence manifest without
regenerating evidence.

## Preconditions

1. Verify exact branch, HEAD parent and subject, upstream equality, 0/0
   ahead/behind, and clean worktree/index.
2. Read the continuity files, accepted design, remediation document, schema-v2
   event-site evidence, matrix reports, guard logs, and complete manifest.
3. Rehash every tracked and retained ignored manifest entry without modifying
   or regenerating evidence.
4. Inspect the complete `709686f..HEAD` diff and confirm authorized scope.

## Safety restrictions

- Audit only. Do not modify files or regenerate builds, matrices, guards,
  evidence, or logs.
- Do not sign, package, create certificates/keys, stage, install, load, start a
  trace session, mutate Windows, query devices, access USB/HID/XUSB/controller/
  Chatpad state, discover/open targets, or perform request operations.
- Do not modify `legacy/`.

## Acceptance criteria

- The five formerly invalid model IDs are absent; emitted and expected events
  are catalogue-valid, family-correct, and independently attributable.
- Both matrices contain 13 real entries, 6 assertion suites, 7 validations,
  6,980 real passed assertions, and zero synthetic, parse, empty, entry, or
  assertion failures.
- All 73 events resolve through 94 precise mappings; direct/helper/physical-site
  totals and repeated stage sites reproduce with zero mapping defects.
- Cleanup is inspected and limited to one diagnostic snapshot read, with no
  mutation, completion, cancellation, transfer, operational use, or
  unclassified reference.
- Runtime, owner Full, and orchestration Full evidence is configuration-bound
  and the schema-`1.2.0` manifest rehashes with zero defects.

## Inspect first

- `tests/offline/RuntimeInstrumentationModel/RuntimeInstrumentationModel.psm1`
- `tests/offline/RuntimeInstrumentationModel/Test-RuntimeInstrumentationModel.ps1`
- `tools/Invoke-ChatpadRuntimeInstrumentationRegressionMatrix.ps1`
- `tools/Test-ChatpadRuntimeInstrumentation.ps1`
- `tools/Test-ChatpadProductionOwnerInitialization.ps1`
- `docs/evidence/runtime-instrumentation-event-sites.csv`
- `docs/evidence/runtime-instrumentation-implementation-manifest.json`
- `docs/OFFLINE-RUNTIME-INSTRUMENTATION-IMPLEMENTATION.md`
