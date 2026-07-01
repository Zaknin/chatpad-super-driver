# Offline Runtime Instrumentation Remediation

## Scope and audit disposition

Commit `3546ace3892914935276ed74f39d2cd71a53858e` implemented the accepted
WPP design but failed independent implementation audit. The blocking defects
were diagnostic and evidence defects: sixteen catalogue events lacked real
source sites, trace arguments mutated sequence state, prohibited counters and
cleanup invariants were incomplete, event 1308 was not a report summary,
production guards were weakened, the model tests and Debug/Release comparison
were not independent executable evidence, and the manifest/regression evidence
was incomplete.

This checkpoint remediates those defects without changing ordinary production
statuses, creation order, rollback ownership or deletion order, readiness
authority, lifecycle reachability, WDF parenting, target/request absence, or
D0/removal behavior. Independent acceptance is still pending.

## Provider and source coverage

- Provider GUID: `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`.
- Trace schema: `1`.
- Catalogue: all 73 accepted semantic IDs and names are preserved.
- Actual source-site inventory: 73 rows, zero phantom sites.
- Parsed `ChatpadTrace` invocations: 34, with zero side-effectful arguments and
  zero trace sites under the owner spinlock.
- Events 1310, 1701-1712, 1801, 1802, and 1804 now have real diagnostic source
  paths. Event 1713 is emitted on pre-context and context-backed terminal paths.

Sequence mutation now occurs in ordinary statements before trace macros.
Attempt-local state covers failures before `WDFDEVICE` exists and is transferred
to the device context after creation.

## Counter, cleanup, and report semantics

One authoritative twelve-value counter enum and one twelve-counter structure
use interlocked updates. The update helper saturates at `MAXLONG`, records
first-transition and overflow masks, emits the corresponding 1701-1712 event on
the first zero-to-nonzero transition, and emits 1804 on overflow attempts. It
has no production operation callers because no prohibited operation boundary
exists.

Terminal and cleanup validation inspect all twelve counters. Cleanup records
attempt/sequence state, first-transition and overflow masks, counter and final
snapshot state, object presence, owner/fault state, structural readiness,
terminal state, and terminal status. Meaningful invariants cover duplicate
cleanup, missing terminal/final snapshots, incomplete rollback, objects left
after completed rollback, impossible sequence state, successful terminal state
with nonzero counters, and schema mismatch. The unused
`RuntimeCleanupObserved` field was removed.

Event 1308 now emits a bounded initialized orchestration summary: function and
report results, mismatch flag, terminal and failed stages, terminal and first
failure classes, mapped status class, rollback flags, four object-presence
flags, ready-attempted/published flags, object-graph completeness, structural
readiness, and final initialization-mask class. No raw structure, padding,
pointer, handle, or payload is logged. Unexpected orchestration taxonomy is
logged and enters the existing fail-closed terminal path.

## Guard and executable evidence

`Test-ChatpadRuntimeInstrumentation.ps1` parses real trace calls, validates
source/function inventory sites, inspects trace arguments and spinlock regions,
checks counter/cleanup/report fields, validates independent Debug and Release
WPP project configuration, rejects prohibited operations, and verifies that
accepted production guards are not weakened.

Production orchestration Full mode remains Full. Historical tracked-input SHA
values are cross-bound to retained A/B inventories while Git blob IDs bind the
immutable implementation commit; the packaging-only prototype INF remains
outside build-input inventories. Production owner initialization requires the
instrumented binary to match a configuration-specific manifest entry and
retains PE, import, WDF, retention, and target/request checks.

The executable pure model contains 19 scenarios and 228 assertions. It invokes
state-transition, counter, rollback, terminal, and cleanup helpers and checks
exact semantic-event order, terminal outcome, rollback presence/absence,
cleanup, object/final snapshots, twelve-counter snapshots, overflow and first
transition behavior, and returned status class.

Complete Debug and Release matrices each ran 13 required entries and passed
301/301 reported assertions with zero errors. Each matrix independently runs
the request-owner model, protocol, transport, lifecycle, control setup,
protocol-kernel and WDF compatibility, production linkage, production owner
initialization Full guard, KMDF request-owner semantics, production
orchestration Full guard, instrumentation guard, and pure model.

## Build, equality, and volume evidence

- Debug driver: 68,096 bytes, SHA-256
  `1C62C702EC8A28CFBEEAAA96C7642DAA6D7B0120C306349C9596D8AC77BB1B8F`,
  Authenticode `NotSigned`.
- Release driver: 40,960 bytes, SHA-256
  `39BF019DC82C49639EF1977E0742168AC067005F4C7FE4257DA0DE70BD3E544C`,
  Authenticode `NotSigned`.
- Debug and Release driver and full-solution builds passed with the VS 2022
  Community WDK toolchain.
- Static inspection confirms x64 Native images and zero prohibited
  target/request symbols.
- Independent Debug and Release object roots contain separately generated WPP
  metadata with equal hashes for device, driver, and request-owner sources.
- The trace-volume report bounds nine stages, contains no unbounded trace loop,
  and finds zero per-byte, per-packet, payload, or recursive trace sources.

## Manifest and limitations

The implementation manifest is schema `1.1.0` and binds the mandatory evidence
set with configuration, command, result, exit code, SHA-256, size, timestamp,
metadata, and limitations. It excludes failed historical logs from accepted
PASS evidence.

The manifest cannot hash its own final bytes, final logs cannot validate their
own final hashes, and the containing commit does not exist until commit time.
An independent audit must rehash final tracked files and retained ignored
evidence and verify the containing commit, parent, branch, upstream, and clean
state.

This remains offline static/compile evidence, not runtime proof. The driver is
unsigned, unpackaged, unstaged, uninstalled, unloaded, and unexecuted. No trace
session, device query, target discovery, request operation, Windows mutation,
controller action, Chatpad interaction, or hardware access occurred.
