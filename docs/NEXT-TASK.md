# Next Task

## Exact current state

- Required branch:
  `feature/offline-runtime-instrumentation-dynamic-emission-remediation`.
- Required starting commit: the final commit containing this file, with subject
  `test: close dynamic instrumentation emission coverage`.
- Required parent: `38d434e8f7c815f609834f79315600aa73969639`.
- Provider GUID: `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`.
- Trace schema/catalogue: schema `1`, 73 semantic IDs and names.
- Emission evidence: CSV schema `2`; 95 mappings, 34 direct WPP invocations,
  79 helper-mediated mappings, 93 unique physical sites, and two shared sites.
- Manifest:
  `docs/evidence/runtime-instrumentation-implementation-manifest.json`, schema
  `1.2.0`.
- Driver state: unsigned, unpackaged, unstaged, uninstalled, unloaded, and
  unexecuted.

## Next recommended objective

An independent read-only audit of the final dynamic-emission remediation
commit. It must independently reconstruct every reachable event from
`ChatpadTracePreContextTerminal` and every approved dynamic emitter, verify
event `1901` has a concrete mapping, reproduce the final mapping/site
arithmetic, test that helper allow-listing cannot hide missing events,
reconcile the affected guard/equality/volume/matrix evidence, and rehash the
complete manifest without regenerating evidence.

## Preconditions

1. Verify exact branch, HEAD parent and subject, upstream equality, 0/0
   ahead/behind, and clean worktree/index.
2. Read the complete dynamic-emitter contracts, production helper and callers,
   schema-v2 inventory, final guard logs, matrices, reports, and manifest.
3. Rehash every tracked and retained ignored manifest entry without modifying
   or regenerating evidence.
4. Inspect the complete `38d434e..HEAD` diff and confirm authorized scope.

## Safety restrictions

- Audit only. Do not modify files or regenerate builds, matrices, guards,
  evidence, or logs.
- Do not sign, package, create certificates/keys, stage, install, load, start a
  trace session, mutate Windows, query devices, access USB/HID/XUSB/controller/
  Chatpad state, discover/open targets, or perform request operations.
- Do not modify `legacy/`.

## Acceptance criteria

- Event 1901 has an exact source-bound mapping through
  `ChatpadTracePreContextTerminal` and the concrete WPP sink.
- Every dynamic helper caller and selector domain is complete, catalogue-valid,
  family-correct, sink-resolved, and inventoried with all dynamic defect
  counters zero.
- Ten dynamic rejection fixtures prove missing, extra, unresolved, wrong-family,
  stale, sink, caller, and allow-list defects fail closed.
- Both matrices contain 13 entries, 6 assertion suites, 7 validations, 6,980
  real passed assertions, and zero synthetic, parse, empty, entry, or assertion
  failures.
- Runtime, owner Full, and orchestration Full evidence is configuration-bound
  and the schema-`1.2.0` manifest rehashes with zero defects.

## Inspect first

- `src/driver/ChatpadFilter/device.c`
- `tools/Test-ChatpadRuntimeInstrumentation.ps1`
- `tools/Invoke-ChatpadRuntimeInstrumentationRegressionMatrix.ps1`
- `docs/evidence/runtime-instrumentation-event-sites.csv`
- `docs/evidence/runtime-instrumentation-debug-release-equality.json`
- `docs/evidence/runtime-instrumentation-trace-volume-report.json`
- `docs/evidence/runtime-instrumentation-implementation-manifest.json`
- `docs/OFFLINE-RUNTIME-INSTRUMENTATION-IMPLEMENTATION.md`
