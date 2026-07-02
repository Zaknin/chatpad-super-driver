# Offline Runtime Instrumentation Dynamic-Emission Remediation

## Scope

The independent audit of `709686f522eafc12913658b076bd0e001d6add32`
found four evidence-contract defects: invalid and self-confirming model event
IDs, synthetic matrix assertions, function-level rather than concrete emission
mapping, and an owner guard that excluded the diagnostic cleanup callback from
its lifecycle assertion. Commit
`38d434e8f7c815f609834f79315600aa73969639` corrected those four reported
surfaces, but a second independent audit found that its dynamic-emitter
allow-list hid one remaining concrete relationship: event 1901,
`DEVICE_ADD_FAILURE`, emitted through `ChatpadTracePreContextTerminal`.

This checkpoint closes that dynamic-emission defect without
changing production `.c`/`.h`, project, solution, INF, protocol, transport,
signing, packaging, installation, hardware, or `legacy/` paths.

The provider GUID remains `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`, trace
schema remains `1`, and the authoritative production catalogue remains 73
semantic IDs and names.

## Pure-model correction

The old model used IDs that do not exist in the production catalogue:

| Invalid ID | Intended transition | Correct production evidence |
|---:|---|---|
| 1313 | request-creation stage failure | 1301 `ORCHESTRATION_STAGE_ENTERED` with request-stage discriminator, followed by 1600-1604 rollback evidence |
| 1314 | outbound-memory stage failure | 1301 with outbound-memory discriminator, followed by 1600-1604 |
| 1315 | inbound-memory stage failure | 1301 with inbound-memory discriminator, followed by 1600-1604 |
| 1407 | lifecycle initialization failure | 1502 `LIFECYCLE_INIT_FAILED` |
| 1410 | mark-device-created failure | 1505 `MARK_DEVICE_CREATED_FAILED` |

Rollback now uses 1600-1604 and cleanup uses 1605-1608. The four object-stage
failure scenarios distinguish stages 2, 4, 6, and 8 while using the shared
production event 1301, matching the production helper contract.

Model execution retains a private numeric transition map. Expected sequences
are separately maintained semantic-name contracts resolved through
`docs/WINDOWS11-OFFLINE-RUNTIME-INSTRUMENTATION-DESIGN.md`; the test runner
does not import the model's numeric map. Changing an emitted numeric constant
therefore cannot update the expected sequence automatically. Validation rejects
unknown emitted IDs, unknown expected names, wrong families, numeric expected
constants, duplicate scenario names, empty scenarios, empty execution, and
failed aggregation. Five negative fixtures cover the audit failure modes.

All 19 intended scenarios pass with 932 executed, 932 passed, and zero failed
assertions. A failed assertion produces a failed machine result and nonzero
process exit.

## Regression-matrix accounting

The matrix no longer substitutes one assertion when parsing fails. Its schema
`chatpad-runtime-instrumentation-regression-matrix-v2` defines six
assertion-bearing suites and seven non-assertion validations. Assertion suites
must report explicit executed, passed, and failed totals with
`executed = passed + failed`; zero requires explicit authorization. Validation
suites must satisfy named machine-parseable checks and configuration binding.
Neither validation exit codes nor check counts are added to assertion totals.

Eight negative fixtures prove rejection of empty output, malformed output,
missing counts, unauthorized zero assertions, inconsistent totals, child
failure under aggregate PASS, wrong configuration, and copied/relabeled
configuration evidence. Debug and Release each pass all 13 entries with 6,980
real assertions executed and passed, zero failed assertions, zero synthetic
assertions, zero parse failures, and zero empty-result failures.

## Concrete semantic-event emission evidence

`runtime-instrumentation-event-sites.csv` is schema `2`. Its 95 rows bind all
73 semantic events to exact production source paths, containing functions,
source lines, normalized call locators and locator hashes, direct WPP or
approved helper emission, helper-to-WPP chains, WPP lines and locator hashes,
physical-site identities, shared-site flags, and stage discriminators.

The guard independently derives the same map from production source. Current
totals are 34 direct WPP macro invocations, 79 helper-mediated semantic
mappings, 93 unique physical semantic emission sites, and 2 shared physical
sites. Nine stage-entered and nine stage-completed locations are represented
separately. Every direct WPP site is either a direct semantic site or an
approved helper endpoint. Missing, extra, phantom, stale, collapsed, duplicate,
and unexplained counts are zero.

Ten negative fixtures reject function co-location without a real relationship,
stale lines, nonexistent helpers, helpers that do not reach WPP, duplicate and
missing IDs, extra and test-only IDs, unexplained WPP sites, and collapsed
repeated sites.

### Dynamic-emitter correction

`ChatpadTracePreContextTerminal` selects between events 1900 and 1901 using
`NT_SUCCESS(status)`. Its only two production callers are the attempt-ID
overflow branch and the failed-`WdfDeviceCreate` branch, so both constrain the
reachable selector result to event 1901. The helper also emits fixed events
1713, 1902, and 1903. Event 1900 is present in the selector domain but is not
reachable from either current caller.

The added mapping binds event 1901 to the concrete WPP sink at
`src/driver/ChatpadFilter/device.c:521:ChatpadTrace`, normalized locator
SHA-256
`3387C13EA8A5F03F4154E6CA20E39B43F17F2DC8C1427E228A8044E904AA95F8`.

The runtime guard no longer treats a helper name as sufficient evidence.
Source-bound contracts cover all five dynamic helpers, enumerate every
parameter-driven caller value, resolve the pre-context selector and both caller
conditions, require each helper-to-WPP sink, and compare every reachable value
with the inventory. Ten additional rejection fixtures cover a removed 1901
row, a new unrecorded selector alternative, unreachable inventory data,
out-of-catalogue and unresolved selectors, a removed WPP sink, an undeclared
caller value, wrong family, stale locator, and an allow-list-only contract.

## Cleanup owner-observation contract

The production-owner guard now isolates and inspects `ChatpadEvtDeviceAdd`,
`ChatpadEvtDeviceContextCleanup`, prepare/release hardware, D0 entry/exit, and
any declared removal or surprise-removal callback. Cleanup has exactly one
permitted owner reference: a diagnostic read passed to
`ChatpadRuntimeCaptureObjectSnapshot`. Mutation, completion, cancellation,
ownership transfer, operational request/queue/target use, synchronization or
lifetime work, callback exclusion, and unclassified references fail closed.
Seven negative fixtures cover those prohibited classes. Full mode passes for
Debug and Release with cleanup classified
`diagnostic-read-only-object-snapshot`.

## Offline validation and evidence

- Runtime instrumentation guards: Debug PASS; Release PASS.
- Dynamic-emitter contracts: five helpers and 78 callers inspected; 79
  reachable/inventoried helper-mediated mappings; ten rejection fixtures PASS;
  zero missing, extra, unresolved, wrong-family, stale, sink, or allow-list
  suppression defects.
- Production owner guard Full: Debug PASS; Release PASS.
- Production orchestration guard Full: Debug PASS; Release PASS.
- Driver and full-solution builds: Debug PASS; Release PASS, zero build errors.
- Debug driver: 68,096 bytes, SHA-256
  `E805693C260E489078D2A9A75E5C0DBCE791EBDDA907C484FE47619CF4256097`,
  Authenticode `NotSigned`.
- Release driver: 40,960 bytes, SHA-256
  `A9C5CD9ABF621ED4B8446A3249843541DB2ADE1BAD7E930D0B8525862758B404`,
  Authenticode `NotSigned`.
- Static target/request symbol checks and repository safety checks pass with
  all prohibited-action counters zero.

Manifest schema `1.2.0` binds the final affected evidence. The false-PASS
runtime guards and transitively tainted matrices from commit `38d434e` are
superseded, along with the earlier guard, model, and matrix reports, and are
not current acceptance
evidence:

- `artifacts/logs/runtime-remediation-guard-Debug-20260701T224927Z.log`
- `artifacts/logs/runtime-remediation-guard-Release-20260701T224927Z.log`
- `artifacts/logs/runtime-remediation-pure-model-20260701T224927Z.log`
- `artifacts/logs/runtime-instrumentation-matrix-Debug-20260701T224235Z.json`
- `artifacts/logs/runtime-instrumentation-matrix-Release-20260701T224337Z.json`
- `artifacts/logs/runtime-evidence-guard-runtime-{Debug,Release}-20260702T041654Z.log`
- `artifacts/logs/runtime-evidence-guard-matrix-final-{Debug,Release}-20260702T042143Z.json`

The manifest cannot hash its own final bytes or name its containing commit
before commit. Independent audit must verify the final commit, parent, branch,
upstream equality, tracked scope, ignored evidence, and all manifest hashes
without regenerating evidence.

This remains offline static/compile evidence. The driver is unsigned,
unpackaged, unstaged, uninstalled, unloaded, and unexecuted. No trace session,
Windows mutation, live device query, target/request operation, controller or
Chatpad access, or hardware test occurred.
