# Decisions

Durable technical or workflow decisions only. Each entry includes date, decision, rationale, alternatives rejected, and consequences.

---

## 2026-07-04 - Require strict JSON Boolean safety fields for metadata-review manifests

**Decision:** Metadata-review design-gate safety fields in the readiness
manifest must be explicit JSON Boolean values. The manifest validator rejects
missing, null, numeric, string, empty-string, array, and object values instead
of relying on PowerShell Boolean coercion. The design-gate audit path also
records `native_execution_status` as `NOT_IMPLEMENTED` and uses
`NO_ARTIFACT_OPEN_DESIGN_GATE_AUDIT` when artifact opening, hash verification,
and metadata parsing are prohibited.

**Rationale:** The independent design-gate audit proved that numeric `0` in a
prohibited-action field could validate as `$false`. Safety evidence must
preserve JSON type as part of the contract, otherwise malformed or ambiguous
inputs can be reinterpreted as acceptable false values.

**Alternatives rejected:** Casting values through `[bool]`, accepting numeric
or string false equivalents, documenting expected values without enforcing
JSON type, or running standard compiled-output validation during a
no-artifact-open design audit.

**Consequences:** Future manifest producers must emit real JSON Booleans for
every metadata-review safety field. Future validators and re-audits must prove
field-level rejection for non-Boolean values and must keep native execution
`NOT_IMPLEMENTED` until a separately authorized native implementation exists.

## 2026-07-04 - Gate compiled-artifact metadata review behind independent design audit

**Decision:** Because the repository has no approved static managed metadata
parser, stop at
`BLOCKED_PENDING_COMPILED_ARTIFACT_METADATA_REVIEW_DESIGN_AUDIT`. Preserve
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED` as the runtime capability
blocker. A future implementation may inspect only inert PE/CLI bytes under an
explicit allowlist and requires separate authorization after design audit.

**Rationale:** Existing metadata-related findings are absent tools, unrelated
native `dumpbin` workflows, runtime `Add-Type`, guards, or documentation. None
provides an audited non-loading managed-artifact inspection path.

**Alternatives rejected:** Loading or reflecting over the assembly, executing
it, using runtime compilation, repurposing native-driver `dumpbin` workflows
without a managed metadata contract, implementing a parser in this phase, or
advancing directly to native adapter execution.

**Consequences:** Live readiness remains `BLOCKED`; metadata review remains
not implemented and unauthorized; assembly loading, runtime reflection,
execution, native DLL loading, entry-point resolution, native invocation,
device query, Windows mutation, and driver actions remain prohibited. The next
task is an independent read-only audit of the design gate.

## 2026-07-04 - Accept compile-only evidence remediation re-audit

**Decision:** Accept the independent `AUDIT PASS` for compile-only evidence
remediation commit `3e922470f2e46d5eeb4b6fe7500c4f105c608b3b` and transition the
active readiness gate from
`BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_COMPILE_ONLY_REAUDIT` to
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

**Rationale:** The independent re-audit reproduced the original five-input
line-ending defect, accepted canonical LF identity for tracked text, confirmed
that old v1 outputs are superseded ignored derived artifacts, validated current
schema v2 output identity, and passed the exact, readiness, manifest,
audit-output-root, native-boundary, repository-safety, and generated-file
checks with zero prohibited actions.

**Alternatives rejected:** Keeping the accepted phase pending another re-audit,
treating old v1 output preservation as active, advancing directly to native
loading or invocation, or treating compile-only acceptance as live readiness.

**Consequences:** Live readiness remains `BLOCKED`; native execution remains
`NOT_IMPLEMENTED`; loading, reflection, execution, native invocation, device
query, Windows mutation, and driver installation or binding remain
unauthorized. The next task must be a separately authorized non-loading static
metadata review or a design gate for such a review.

## 2026-07-04 - Treat v1 compile-only outputs as superseded derived artifacts

**Decision:** The 18 compile outputs recorded by
`chatpad-native-interop-compile-only-validation-v1` are historical ignored
derived artifacts only. Their raw hashes are not an active preservation
requirement after the evidence-lineage remediation. Acceptance of the
compile-only phase depends on the current remediated evidence binding the
current compile outputs, contained audit-output-root reruns, canonical tracked
text input identity, raw-byte identity for current outputs, and zero
load/reflection/execution/native/device/Windows/driver actions.

**Rationale:** The v1 evidence recorded outputs under ignored `artifacts/`
paths and did not declare them tracked, durable, or required to remain
available after a later remediation. The independent re-audit of
`207d00feedb6e419d3f791fbcb757576dfb5dbba` reproduced the original source
identity defect and validated all remediated behavior, but could not prove old
v1 output preservation because 9 of 18 current output hashes differed from v1
and the v1 primary DLL hash was no longer present. That mismatch is expected
for per-run ignored compile artifacts and does not weaken the line-ending
defect reproduction.

**Alternatives rejected:** Requiring the old v1 DLL/PDB/NuGet/cache output
bytes to remain available as a long-term acceptance artifact, silently
regenerating or reconstructing old ignored outputs, treating v1 output hashes
as the authoritative identity after schema v2, or marking the compile-only
phase independently accepted without another re-audit.

**Consequences:** Future independent re-audit must verify that v1 output
identity is explicitly superseded, not preserved, and not required for
acceptance. The audit must instead validate the current schema v2 evidence,
the current canonical output root before/after audit reruns, isolated audit
output roots including paths with spaces, invalid-root rejection, and all
prohibited-action counters. The gate remains
`BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_COMPILE_ONLY_REAUDIT`, and native
adapter execution remains `BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

## 2026-07-03 - Canonicalize tracked text evidence and isolate audit compilation

**Decision:** Evidence-bound tracked text uses `canonical_lf_text`: strict
UTF-8, optional UTF-8 BOM removed, CRLF or CR normalized to LF, then UTF-8
without BOM. Canonical SHA-256 and byte size are authoritative; raw
working-tree SHA-256 and size are informational. Compile outputs use
`raw_file_bytes`. Compile-only audit reruns must supply a distinct ignored
`artifacts/` output root and explicit no-load, no-reflection, and no-invoke
switches.

**Rationale:** The first independent compile-only audit proved all five
recorded LF identities matched canonical source content while a clean Windows
checkout exposed CRLF bytes. Raw working-tree identity therefore was not a
portable source boundary. Auditors also could not safely reproduce compilation
because the runner hard-coded and deleted the canonical output root.

**Alternatives rejected:** Recording CRLF-only hashes, silently normalizing
without declaring policy, using raw hashes for tracked text, treating raw and
canonical identity as interchangeable, or allowing audit runs to overwrite
tracked evidence or canonical compile output.

**Consequences:** Compile evidence schema v2 and readiness manifest schema v4
declare identity policy per file. Missing, unknown, mixed, mismatched, or
raw-on-tracked-text policies fail closed. Raw compile-output hashes may vary by
commit or output path and are not presented as cross-run deterministic.
Independent re-audit remains required; native execution is still unimplemented
and unauthorized.

## 2026-07-03 - Accept compile-only native interop validation without execution

**Decision:** The accepted declaration-only SetupAPI/Newdev source boundary may
be compiled only through the isolated non-production harness under
`tools/ExactInstance/CompileOnlyValidation/`. The active readiness gate is now
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`; the historical
`BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED` gate remains
only as the prior transition state recorded in evidence.

**Rationale:** The compile-only harness proves the audited declarations,
structure contracts, `cbSize` assignments, marshaling metadata, Unicode and
last-error signatures, and compiler diagnostics can compile cleanly without
adding any production build reference or runtime behavior. It still does not
prove safe loading, entry-point resolution, native invocation, device query, or
Windows mutation.

**Alternatives rejected:** Treating compilation as runtime readiness, loading
or reflecting over the produced assembly during validation, invoking
SetupAPI/Newdev, adding the declarations to production driver build inputs,
using `dotnet test` or a test host, querying devices, or advancing directly to
live adapter authorization.

**Consequences:** Compile-only artifacts remain ignored under `artifacts/` and
require separate independent audit before any loading, reflection inspection,
entry-point resolution, native invocation, or live adapter implementation can
rely on them. Current readiness remains `BLOCKED`, and native adapter
execution remains unimplemented.

## 2026-07-03 - Supersede native interop source-audit gate with compile-only validation gate

**Decision:** The independent source audit for the declaration-only
SetupAPI/Newdev boundary is accepted with verdict `AUDIT PASS`, so current
readiness records now use
`BLOCKED_NATIVE_INTEROP_COMPILE_ONLY_VALIDATION_NOT_AUTHORIZED` instead of the
historical `BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_SOURCE_AUDIT` gate.
The downstream blocker remains
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`.

**Rationale:** The audit accepted the source boundary as declaration-only and
non-executing, but it did not compile the declarations, validate structure
sizes or `cbSize`, load an assembly, invoke native APIs, query devices, or
mutate Windows. The next honest blocker is therefore lack of explicit
compile-only validation authorization, not lack of source audit.

**Alternatives rejected:** Marking the adapter runtime-ready, treating source
audit acceptance as compile validation, editing the audited NativeInterop
source files only to change status text, authorizing native loading or
invocation, or folding compile-only validation into production build/package
paths.

**Consequences:** Current-state producers, validators, tests, generated
readiness evidence, and docs report the compile-only-not-authorized gate.
Native source hashes remain bound to the accepted source implementation.
Compile-only validation must be a separate authorized phase in an isolated
non-production harness, and any compiled artifact requires separate
independent audit before loading or invocation.

## 2026-07-03 - Keep SetupAPI/Newdev interop as declaration-only source until independent audit

**Decision:** In the source-boundary implementation phase, the native
SetupAPI/Newdev boundary could declare allowlisted
`setupapi.dll` and `newdev.dll` P/Invoke signatures and typed structure
contracts in isolated source under `tools/ExactInstance/NativeInterop/`, but it
must not compile, load, invoke, reference from build files, generate binaries,
query devices, or mutate Windows in this phase. The final gate is
the historical `BLOCKED_PENDING_INDEPENDENT_NATIVE_INTEROP_SOURCE_AUDIT`.

**Rationale:** The next useful step after accepting the non-executing adapter
scaffold is source-level review of the exact Win32 signatures, ownership
tokens, planned call sequences, cleanup obligations, and error mapping. Keeping
the declarations isolated lets the project audit correctness without creating
an executable native adapter or widening the live surface.

**Alternatives rejected:** Adding `Add-Type`, `LibraryImport`, runtime
compilation, project references, generated native interop binaries,
Configuration Manager declarations without a proved need, PnPUtil/DevCon/DIFx
fallbacks, or any direct SetupAPI/Newdev invocation.

**Consequences:** G78-G132 permanently cover declaration inventory, build
isolation, non-execution call plans, caller-boundary integrity, error mapping,
and zero live counters. A later native implementation still requires separate
authorization, implementation, evidence, independent audit, and explicit live
authorization.

## 2026-07-03 - Require explicit primitive native adapter and operation selection

**Decision:** Public native adapter scaffold operations require explicit
primitive string adapter and operation selections. The production adapter is not
selected by default, synthetic fallback is never implicit, caller objects are
not introspected for authoritative identity, and scaffold constants are rebuilt
from literal values per call instead of trusted through mutable module state.
The current gate is
`BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_REAUDIT`.

**Rationale:** The initial scaffold audit showed that omitted adapter
selection defaulted to production, script-scope values could be modified inside
the process, caller objects could influence identity through object behavior,
and manifest corruption regression children did not honor custom manifest
paths. Those were integrity gaps even though native execution remained
unimplemented.

**Alternatives rejected:** Defaulting missing adapter input to production,
trusting script-scope constants as security facts, calling methods or relying
on extensible PowerShell object behavior for identity, allowing broad
object-typed public gate inputs, or letting child manifest validators silently
fall back to the tracked manifest path.

**Consequences:** G68-G77 permanently cover omitted adapter selection,
non-string adapter and operation values, caller-object spoofing, mutable
module-state tampering, unsupported operation ordering, and custom manifest
path forwarding. Live readiness remains blocked until independent re-audit
accepts the remediated scaffold, and native SetupAPI/Newdev execution remains
a later separately authorized implementation boundary.

## 2026-07-03 - Treat snapshot identity and offline producer context as the only current trust roots

**Decision:** Restoration uses the exact prior-driver identity read from a
validated, hash-authenticated snapshot. The plan's restoration identity is a
non-authoritative comparison copy and must be deeply equal. Evidence schema v1
is permanently synthetic/offline, and the production composition root
unconditionally reports `LIVE_ADAPTER_NOT_IMPLEMENTED` for real Apply/Restore.

**Rationale:** Independent audit showed that an outer plan rehash authorized a
changed restoration node, coordinated serialized-origin changes produced
apparently live evidence, and public adapter strings plus a reproducible hash
could satisfy the former real-execution gate.

**Alternatives rejected:** Trusting a caller-editable restoration field,
inferring live origin from serialized strings or Booleans, reserving a magic
future adapter name, accepting elevation/switches as capability, or retaining a
deterministic public authorization hash.

**Consequences:** T26-T29 and T37 are permanent adversarial regressions. A
future native adapter requires a separately authorized implementation, an
internally controlled capability, a separately audited live-evidence contract,
and cannot reuse evidence schema v1 to claim live origin.

## 2026-07-03 - Canonicalize from a duplicate-aware raw JSON model

**Decision:** `chatpad-canonical-json-v1` parses raw JSON before ordinary
PowerShell deserialization, rejects duplicate names case-insensitively at every
object depth, preserves strings as strings, accepts only unambiguous finite
JSON numbers, sorts object names ordinally, preserves array order, applies
explicit JSON escaping, and hashes UTF-8 bytes without BOM.

**Rationale:** PowerShell 7 converted ISO strings to DateTime values and changed
hash inputs, while ordinary deserialization discarded duplicate-property
evidence. Culture-sensitive property sorting and runtime object conversions
were not a stable security boundary.

**Alternatives rejected:** Hashing `ConvertFrom-Json` output, last-value-wins or
first-value-wins duplicate handling, culture-sensitive sorting, non-finite
numbers, and timestamp-type normalization during hashing.

**Consequences:** Plan/snapshot creation and validation are stable in all four
Windows PowerShell/PowerShell 7 directions. Raw plan entry points use the
duplicate-aware parser, and T30-T33/T38 permanently cover the canonical
contract.

## 2026-07-03 - Model audit gate and live-adapter absence as separate blockers

**Decision:** Readiness records expose `readiness=BLOCKED`,
`current_gate=BLOCKED_PENDING_INDEPENDENT_AUDIT`, and
`capability_blocker=BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`; live-adapter status
is `NOT_IMPLEMENTED` and live binding authorization is false.

**Rationale:** Passing an audit of offline contracts cannot create the absent
SetupAPI/Newdev implementation or its canonical opening, node enumeration,
binding, restoration, postcondition, and restart capabilities.

**Alternatives rejected:** Describing the independent audit as the only
remaining live prerequisite or implying that a successful audit authorizes
hardware execution.

**Consequences:** A future audit may accept the offline framework, but live
readiness remains blocked until a separate native-adapter implementation and
audit phase is explicitly authorized and completed.

## 2026-07-03 - Separate the offline exact-instance transaction framework from the native Windows adapter

**Decision:** Exact-instance selection is defined by one complete canonical
Plug and Play instance ID opened directly by an adapter, ordinal comparison
with the adapter-returned canonical ID, one retained device element, immutable
driver-node identity, verified postconditions, and exact prior-driver
restoration. The repository now implements pure contracts, deterministic plan
and snapshot hashing, a fake adapter, transaction orchestration, replay and
uncertainty handling, evidence/accounting, and T1-T25 coverage. The public
entry point defaults to `Plan` and cannot invoke a live adapter. Live readiness
is `BLOCKED_PENDING_INDEPENDENT_AUDIT`.

**Rationale:** Hardware IDs, compatible IDs, class/container/location
properties, filename-only package selection, first-match enumeration, and
best-driver reevaluation can affect or select a different device. Offline fake
execution is required to prove exact scoping, restoration identity, replay
protection, and failure accounting without mutating the audit host.

**Alternatives rejected:** `pnputil /add-driver ... /install`,
`UpdateDriverForPlugAndPlayDevices`, class-wide or hardware-ID-wide update,
package staging counted as binding, global package removal as rollback,
device removal and rescan, first/best candidate fallback, API-return-only
success, automatic restart/reboot, and synthetic evidence accepted as live.

**Consequences:** Plans and restoration snapshots are versioned and hashed;
all synthetic mutation calls carry the same canonical instance ID; zero or
multiple driver-node candidates fail closed; uncertain post-mutation states
require restoration/manual recovery; and a future native SetupAPI/Newdev
adapter must be implemented and independently audited in a separate authorized
task before any live operation can be considered.

## 2026-07-03 - Require exact numeric manifest counts and derived local branch provenance

**Decision:** Manifest count fields are valid only when they are JSON numeric
scalars in signed 64-bit range with no nonzero fractional component. The
validator rejects strings, numeric-looking strings, Boolean values, nulls,
arrays, objects, missing count properties, negative counts, non-finite values,
fractional values, and oversized values before any integer conversion or
aggregate arithmetic. Integer-valued numeric representations such as `1.0` are
accepted deliberately. The readiness-manifest generator derives the checked-out
local branch from Git and rejects detached HEAD.

**Rationale:** The independent corrective audit showed that `assertion_count =
1.5` was converted by PowerShell before validation. With unchanged totals the
manifest failed only through aggregate mismatch, and with dependent totals
adjusted to the coerced value the validator passed. The same audit showed the
canonical branch identity was correct only because the generator hard-coded the
prior feature branch.

**Alternatives rejected:** Relying on `[int]` or `[long]` casts, parsing
numeric strings, rounding or truncating fractional values, accepting Boolean
conversion, treating oversized values as saturated integers, inferring branch
identity from upstream names or stale documentation, or silently recording a
previous branch in detached HEAD.

**Consequences:** Count validation is centralized and field-level defects
survive before reconciliation. The malformed-copy regression suite includes
F1-F5, the self-consistent fractional bypass, and the malformed-count matrix.
Manifest generation now follows the checked-out local branch and remains
blocked in detached HEAD. Live readiness stays `BLOCKED_NOT_IMPLEMENTED`.

## 2026-07-03 - Treat empty manifest accounting subsets as validation defects

**Decision:** Manifest-readiness accounting must be total over empty record
subsets. Empty subsets aggregate to numeric zero, and mismatches against the
expected suite/category/harness totals are reported as controlled accounting
defects. Missing, null, Boolean, array, nonnumeric, and negative count values
remain invalid data and cannot be silently coerced into PASS.

**Rationale:** The independent manifest-validator audit showed that removing
all `harness-self-test` records from an isolated manifest copy reached an
uncaught `PropertyNotFoundException` because empty `Measure-Object -Sum`
results expose no `.Sum` property under StrictMode. That made a corrupt
manifest fail as an internal tool error instead of as a controlled accounting
failure.

**Alternatives rejected:** Disabling StrictMode, catching and suppressing all
property exceptions, treating omitted categories as absent-but-valid, or
normalizing corrupted tracked evidence in place instead of using isolated
corruption copies.

**Consequences:** Manifest arithmetic uses an explicit integer-sum helper,
corrupt empty-subset cases remain expected FAIL results, and regression
coverage must prove omitted harness/accounting records do not surface
uncontrolled exceptions or `PropertyNotFoundException`.

## 2026-07-02 - Separate runtime-observation shape from live evaluation and account every assertion

**Decision:** Runtime-observation record structure is validated separately from
runtime evaluation. Only source-classification `live`, runtime-evaluation mode,
non-synthetic provenance, approved producer/script identity, coherent
session/host/timestamps, condition-specific evidence, and a matching existing
artifact size and SHA-256 may reach an evaluated runtime result. Synthetic,
sample, planned, unknown, or missing provenance cannot produce runtime PASS.
All suite assertions belong to first-class fixture records; aggregate and
category totals are derived from those records and independently recomputed by
the manifest validator.

**Rationale:** The independent stop-linkage audit showed that
`evidence_available=true` and `triggered=false` could PASS without provenance,
including explicitly synthetic input. It also found 140 fixture records with
915 assertions while six off-ledger harness checks produced the reported 921,
so category totals could not independently reconcile.

**Alternatives rejected:** Treating `evidence_available` as proof, accepting a
generic payload for every condition, marking fixtures live, combining
structural validation with runtime authorization, retaining an implicit
`915 + 6` accounting rule, or trusting manifest aggregate numbers without
enumerating the bound suite records.

**Consequences:** Five condition-specific evidence contracts and permanent
missing/synthetic provenance matrices are required. Structurally valid
synthetic records may pass only the shape validator and remain blocked by the
runtime evaluator. Harness checks are normal one-assertion fixtures. Record,
category, and aggregate arithmetic must match exactly or fail with
`ASSERTION_ACCOUNTING_INVALID`. Live readiness remains
`BLOCKED_NOT_IMPLEMENTED`.

## 2026-07-02 - Centralize final operation lifecycle and evidence inventory truth

**Decision:** Operation lifecycle validity is enforced by the shared
`Test-ChatpadOperationPlanContract` contract and reused by runtime evidence
semantic validation. Executed, failed, and rolled-back operations require
explicit start and completion timestamps; committed sample evidence must pass
both structural and semantic validation from its repository path; PowerShell
inventory reporting must derive separate tracked `.ps1`, tracked `.psm1`, and
total counts from Git-tracked paths and reconcile those counts with AST parse
results.

**Rationale:** The fourth readiness audit found that executed operations could
be accepted without `start_timestamp`, the committed sample evidence had not
been proven against both validators as committed, and the manifest/docs
collapsed 41 `.ps1` plus 2 `.psm1` files into an ambiguous 41-file
PowerShell total.

**Alternatives rejected:** Adding a wrapper-only missing-start check, treating
semantic validation as separate lifecycle logic, validating only in-memory
sample equivalents, hardcoding PowerShell totals without Git enumeration, or
silently excluding `.psm1` files from AST parsing.

**Consequences:** Lifecycle fixtures must cover status symmetry directly, the
missing-start-timestamp probe is a permanent regression, sample validation is
part of the suite and manifest truthfulness checks, and all 43 tracked
PowerShell files are expected to parse unless an explicit reported exclusion is
added and justified.

## 2026-07-02 - Treat readiness validators as total functions over malformed JSON-compatible input

**Decision:** Exported runtime readiness validators must reject malformed
JSON-compatible inputs with controlled machine-readable result records instead
of exposing PowerShell property, StrictMode, null, index, conversion, parser, or
runtime exceptions. Public validator entry scripts include a last-resort
`VALIDATOR_INTERNAL_ERROR` boundary for unexpected internal defects.

**Rationale:** The third independent readiness audit found remaining
`PropertyNotFoundException` paths in target selection and rollback validation,
plus lifecycle and semantic evidence validators that accepted invalid executed,
rolled-back, and restored transitions. These defects could make audit results
depend on incidental PowerShell behavior rather than validator contracts.

**Alternatives rejected:** Preserving direct dot-property access after informal
required-field checks, treating exception side effects as valid rejection,
duplicating lifecycle rules in separate validators, or allowing malformed
runtime evidence transitions to fail only in later consumers.

**Consequences:** Safe property/array/object/string/timestamp access is part of
the readiness contract. Malformed-input matrix coverage is required for public
readiness validators, lifecycle and semantic transition checks are fail-closed,
and live readiness still remains `BLOCKED_NOT_IMPLEMENTED` until exact-instance
binding and restoration are separately implemented and audited.

## 2026-07-02 - Separate immutable baseline identity from approved readiness identity

**Decision:** Runtime repository validation uses two identities: the frozen
accepted offline baseline and an exact readiness branch/full commit supplied as
an external approval input. The tracked manifest binds candidate-tree content
but neither hashes itself nor embeds its own final commit.

**Rationale:** The first scaffold hardcoded the baseline commit as current HEAD,
so it failed on the readiness commit. A tracked file cannot truthfully contain
both its own final hash and its own final commit.

**Alternatives rejected:** Accepting commit prefixes, validating only ancestry,
hardcoding the baseline as HEAD, or claiming a pre-commit identity result for a
post-commit tree.

**Consequences:** A future audit/session must provide the exact 40-character
approved readiness commit and branch. Candidate content and final Git identity
are independently attributable without self-reference.

## 2026-07-02 - Use BLOCKED as authoritative live readiness until exact binding exists

**Decision:** Runtime readiness evidence separates framework validation from
live authorization. The framework may report `PASS`, but live installation
readiness reports `BLOCKED` with blocker `BLOCKED_NOT_IMPLEMENTED` until an
audited exact-instance binding and exact-instance restoration implementation
exists. PSScriptAnalyzer absence is recorded as `SKIPPED_UNAVAILABLE`, not
PASS.

**Rationale:** The second independent audit found unsupported PASS paths caused
by unrelated exception handling, Boolean binding availability, empty operation
lists, token-only package checks, unlinked stop conditions, and ambiguous
top-level PASS-with-blocker semantics.

**Alternatives rejected:** Treating any negative-test exception as rejection,
allowing callers to set binding availability with a Boolean, accepting package
token presence without effective INF relationships, preserving top-level
`PASS_WITH_BLOCKER` in machine-readable evidence, or counting unavailable
static analysis as PASS.

**Consequences:** Future runtime consumers must gate on
`live_installation_readiness`, not framework status alone. Any future exact
binding implementation must be added in a separate implementation commit and
audited before live mutation is authorized.

## 2026-07-02 - Make argument vectors authoritative and keep exact binding blocked

**Decision:** Future runtime actions are versioned structured operation plans.
Executable identity and argument arrays are authoritative; display text is
non-executable. Package staging is separate from exact-device binding, broad
rescan is separate recovery authorization, and install/rollback remain blocked
until an exact-instance helper is implemented and audited.

**Rationale:** Raw command strings permit shell injection and broad
`pnputil /install` or `/scan-devices` operations do not prove which device is
bound or restored.

**Alternatives rejected:** Escaping a shell command string, reparsing display
text, treating package staging as binding, or relying on Windows to choose any
compatible rollback driver.

**Consequences:** Future launch code must use
`ProcessStartInfo.ArgumentList`. The framework can pass offline readiness
checks while still returning `BLOCKED_NOT_IMPLEMENTED` for live mutation.

## 2026-07-02 - Gate first runtime bring-up on fail-closed readiness scaffolding

**Decision:** The first Windows 11 runtime bring-up must be preceded by a
separate readiness commit containing an operator procedure, fail-closed
PowerShell scaffolding, offline synthetic safety tests, versioned runtime
evidence schema, stop-condition register, and manifest. The readiness scaffold
may render future mutating commands, but execution must require explicit
runtime authorization, exact target instance identity, and an evidence
directory.

**Rationale:** The accepted offline instrumentation proves observability and
source/binary identity, but the first live session still carries device
selection, signing, rollback, package binding, trace capture, and emergency
recovery risks. Those risks need reviewable contracts before any Windows state
or hardware is touched.

**Alternatives rejected:** Proceeding directly to signing/staging would combine
planning errors with live mutation. Relying on friendly names or broad
wildcards would risk binding the wrong device. Creating certificates or
packages in the readiness commit would cross the preparation-only boundary.

**Consequences:** No live runtime gate opens until an independent read-only
audit accepts the readiness commit. Future install, rollback, trace, and device
commands must be target-specific, evidence-bound, and stop on failed
prerequisites.

## 2026-07-02 - Require source-bound contracts for every dynamic emitter

**Decision:** A helper name may not exempt a dynamic WPP call from semantic
emission coverage. Every dynamic emitter must have a source-bound contract that
proves its complete caller or selector domain, catalogue and family validity,
concrete WPP sink, and exact inventory mappings.

**Rationale:** The independent audit of
`38d434e8f7c815f609834f79315600aa73969639` found that
`ChatpadTracePreContextTerminal` dynamically emitted event 1901 through a real
production WPP site omitted from the inventory. The helper allow-list suppressed
unexplained-site detection and produced false Debug/Release PASS evidence.

**Alternatives rejected:** Adding only a special-case event-1901 row would
leave future dynamic values and callers invisible. Continuing to treat helper
allow-list membership as emission proof would preserve the blind spot.

**Consequences:** All five dynamic helpers are contract-checked against source;
new or unresolved values, callers, sinks, families, locators, or inventory rows
fail closed. Ten isolated negative fixtures exercise the contract, and final
acceptance requires another independent read-only audit.

## 2026-07-02 - Require independently attributable event and suite evidence

**Decision:** Runtime-instrumentation acceptance uses semantic-name model
expectations resolved independently from the executable model's numeric event
map, explicit assertion-versus-validation suite contracts with no synthetic
counts, schema-v2 concrete semantic-event emission mappings with precise source
locators and helper-to-WPP resolution, and explicit diagnostic-read-only
classification for cleanup owner observation.

**Rationale:** Independent audit found five nonexistent model IDs, shared
constants that made expected sequences self-confirming, eleven matrix entries
represented by fabricated assertions, function-co-location evidence that did
not prove event emission, collapsed repeated stage sites, and an owner guard
that excluded the callback containing the only cleanup owner observation.

**Alternatives rejected:** Preserving the historical 228/301 totals, treating
exit zero as an assertion, requiring 73 direct WPP macros, accepting function
co-location without a concrete call path, or deleting cleanup from the owner
guard contract would retain the audited defects.

**Consequences:** The model now reports its real strengthened assertion total;
matrix validations contribute zero assertions; the event-site evidence schema
is version 2; cleanup permits exactly one diagnostic snapshot read and rejects
mutation or operational use. Final acceptance still requires independent
read-only audit.

## 2026-07-02 - Require source-real instrumentation and hash-bound independent evidence

**Decision:** Runtime-instrumentation acceptance requires real production
emission sites for every catalogue event, side-effect-free trace arguments, a
saturating twelve-counter model with terminal and cleanup validation, meaningful
sequence/cleanup invariants, executable pure-model tests, independently derived
Debug/Release WPP evidence, complete per-configuration regression matrices, and
a hash-bound manifest. Production orchestration Full mode may not downgrade to
SourceOnly, and instrumented binary identity must be configuration-bound.

**Rationale:** Independent audit of `3546ace3892914935276ed74f39d2cd71a53858e`
found that header/CSV declarations were being accepted as source coverage,
model tests were strings, configuration equality reused one CSV, counter and
cleanup evidence was incomplete, event 1308 was misclassified, guards were
weakened, and accepted evidence was not fully bound.

**Alternatives rejected:** Treating declarations as emissions, retaining
state-mutating macro arguments, accepting syntactically valid arbitrary hashes,
or silently reducing Full inspection would preserve the audit defects. Adding
dummy prohibited-operation calls would change production behavior and was also
rejected.

**Consequences:** The remediation remains offline and audit-pending. The next
task is independent read-only audit. Signing, packaging, staging, installation,
loading, tracing, device query, target/request operations, Windows mutation,
and hardware gates remain closed.

## 2026-07-01 - Gate instrumentation implementation on independent design acceptance

**Decision:** Every runtime instrumentation event definition must contain
expected IRQL, maximum frequency, first-load criterion, and failure or rollback
action metadata before the design can be accepted. Continuity documents must
not advance from design authoring to implementation until an independent design
audit passes. A design verdict written in an authoring checkpoint does not
constitute independent acceptance.

**Rationale:** The independent audit of
`b26514f59e9d07fbee09e8bab5ea296d18c0dd85` failed for documentation-only
reasons: the 73-event catalogue did not include all required per-event
metadata, and continuation documents prematurely named implementation as the
next task. The repository needs an explicit audit gate to prevent authoring
optimism from opening source or runtime work.

**Alternatives rejected:** Treating category-level prose as complete per-event
metadata would preserve ambiguity for IRQL, frequency, criteria, and operator
action. Treating the design author's "ready" verdict as acceptance would bypass
the independent-review workflow. Opening an implementation task before audit
would widen the gate without independent diagnostic-design approval.

**Consequences:** The next task is independent read-only audit of the
remediated offline runtime instrumentation design. Source implementation,
signing, packaging, staging, installation, loading, device query, target
discovery, request execution, and hardware gates remain closed.

## 2026-07-01 - Select WPP as primary first-load diagnostic mechanism

**Decision:** Use WPP software tracing as the primary mechanism for the future
first controlled load diagnostic instrumentation. Retain existing `KdPrintEx`
statements only as fallback evidence. The instrumentation must be present in
the intended Release-capable diagnostic binary and must use stable source-level
event IDs, bounded scalar fields, per-attempt correlation, prohibited-operation
counters, and object-presence snapshots.

**Rationale:** The first-runtime recovery plan found the accepted binary
insufficiently observable. WPP is a native kernel-driver tracing pattern that
can be collected from a session started before load, works with KMDF driver
code, has low disabled overhead, and can provide durable ETL evidence without
target/request behavior. Existing debug prints lack stable event identity and
structured terminal proof.

**Alternatives rejected:** `KdPrintEx` alone is not durable or structured
enough. A custom ETW/TraceLogging provider or Windows event-log reporting would
be more invasive for the first dormant load. Debugger-only inspection is not
auditable enough for acceptance evidence.

**Consequences:** WPP remains the selected primary mechanism for the remediated
design, but implementation is not authorized until an independent design audit
passes. Signing, packaging, staging, installation, loading, device query,
target discovery, request execution, and hardware gates remain closed.

## 2026-07-01 - Require offline runtime instrumentation before first load

**Decision:** The current accepted production orchestration build is not
sufficiently observable for first controlled runtime load. A separate offline
runtime instrumentation design and implementation gate is required before any
signing, package construction, staging, installation, driver loading, device
query, or hardware observation.

**Rationale:** Existing Windows evidence can show coarse service/PnP outcomes,
and current `KdPrintEx` call sites can show `DriverEntry`, `EvtDeviceAdd`,
`WdfDeviceCreate` failure, and lifecycle callback results if debug capture is
armed. The source does not currently emit durable evidence for orchestration
result/report fields, report/function mismatch, structural-ready reachability,
cleanup after failure, or runtime target/request absence.

**Alternatives rejected:** Loading the driver to discover whether observability
is adequate would collapse the planning gate into runtime execution. Relying on
source-only absence of target/request calls would not prove runtime absence.
Relying only on SetupAPI, System, Kernel-PnP, SCM, or WDF framework events would
not prove the project-specific orchestration state.

**Consequences:** The next task is offline runtime instrumentation design.
Signing, packaging, staging, installation, loading, live device identity
capture, and hardware testing remain closed independent gates.

## 2026-07-01 - Require independently validated raw evidence, PDB binding, and negative root tests

**Decision:** Final production-orchestration provenance acceptance requires a
tracked independent raw-TLOG validator, exact raw-root validation, parser and
freshness recomputation from retained bytes, a retained PDB inventory, and an
extra-TLOG negative test performed only on a disposable duplicate root.

**Rationale:** The remaining provenance-completeness audit defects were about
independent verifiability of generated evidence, not production source. A
separate validator and negative test prove that the accepted raw roots are
complete and closed, while PDB inventory binding prevents retained debug
artifacts from being outside the manifest surface.

**Alternatives rejected:** Trusting producer-generated parser reports would
not independently prove raw byte interpretation. Testing extra-file rejection
against accepted roots would mutate evidence. Leaving PDBs retained but
unmanifested would keep part of the accepted artifact surface unaudited.

**Consequences:** Manifest schema `1.6.0` has 102 mandatory entries. Final
guards recompute root, parser, freshness, object/library/input/PDB, Git-state,
and negative-test evidence with zero explicit defect counters. Runtime,
target/request, signing, packaging, installation, loading, and hardware gates
remain closed.

## 2026-07-01 - Separate production and wrapper-build provenance contracts

**Decision:** Maintain two immutable tracked-input contracts for production
orchestration evidence: a 26-path production runtime/link boundary and a
32-path A/B wrapper-build boundary. Require isolated retained raw roots,
lossless parser reports, retained generated-object/library bytes, source-input
closure, generated-library closure, complete transcripts, and same-set closure.

**Rationale:** The earlier 26-path contract correctly described the production
boundary but did not cover all projects explicitly built by the wrapper.
Shared mutable TLOGs and unretained intermediates could not prove complete
per-set provenance.

**Alternatives rejected:** Expanding the production boundary to include
wrapper-only protocol sources would conflate runtime linkage with build
orchestration. Trusting generated counters without independent guard
recomputation would preserve the audit defects.

**Consequences:** Schema `1.5.0` has 99 mandatory evidence IDs. The wrapper
contract includes complete `ChatpadProtocol` closure. Every accepted set is
independently root-enumerated and byte-bound. Runtime, signing, packaging,
installation, loading, and hardware gates remain closed.

## 2026-07-01 - Require tracked producer and retained raw tlog provenance

**Decision:** Production-orchestration A/B evidence must be generated by a
tracked producer whose SHA-256 and Git blob are bound before evidence capture.
Acceptance now requires retained raw per-set MSBuild tracking logs,
machine-readable raw-tlog inventories, freshness checks, and intermediate
producer-closure records that bind linked `.obj` and `.lib` inputs to their
producer and consuming tlogs.

**Rationale:** The final independent audit found that the previous A/B
evidence did not retain raw tlogs and was generated by an ignored, untracked
producer. Without retained tlogs and producer identity, a later audit could
rehash derived inventories but could not independently verify provenance from
the actual clean-build tracking logs.

**Alternatives rejected:** Keeping the ignored producer would leave the
evidence-generation source unauditable. Retaining only derived input
inventories would preserve the raw-tlog gap. Claiming a historical path count
without an explicit tracked contract would remain unsupported.

**Consequences:** The manifest schema is `1.4.0` with 77 mandatory evidence
entries. A tracked 26-path frozen input set, tracked producer, retained raw
tlogs, freshness logs, closure inventories, and cross-set tlog summary are now
part of the acceptance surface. Runtime, target/request, signing, packaging,
installation, loading, and hardware gates remain closed.

## 2026-07-01 - Complete A/B input identity with tracking-log closure

**Decision:** The production-orchestration A/B evidence now proves input
identity from the effective clean-build dependency closure rather than a
manually selected source subset. The retained schema-`1.3.0` manifest includes
four machine-readable input inventories and two A/B input-comparison logs. The
inventory method uses explicit solution/project/`Directory.Build.props` files,
`ChatpadFilter` compiler/linker tracking logs, the
`ChatpadKmdfRequestOwnerContext` project-reference producer compiler/librarian
tracking logs, external SDK/WDK/MSVC headers and libraries, system reads, and
toolchain executable identity.

**Rationale:** The final independent audit found that the previous eight-file
claim did not cover the actual build dependency closure and that the
equivalence manifest metrics did not match the retained logs. Tracking-log
closure ties the proof to the evaluated build outputs instead of a maintained
filename list, while the manifest now derives equivalence metrics from the
retained logs' `ManifestMetricValue` lines.

**Alternatives rejected:** Keeping the eight-file subset would preserve the
audit failure. Claiming generated `.obj`/`.lib` intermediates as stable
pre-build source inputs would overstate the proof because those intermediates
are produced during each clean build; they are instead accounted for through
their producer tlog closure. Expanding PE normalization to force equality was
also rejected.

**Consequences:** Debug inventories contain 116 inputs and Release inventories
contain 118 inputs, with A/B path sets, hashes, build configuration digests,
and toolchain identity matching. Set B remains canonical. Runtime,
target/request, signing, installation, packaging, and hardware gates remain
closed.

## 2026-07-01 - Replace historical binary inference with retained A/B evidence

**Decision:** Finalize the production-orchestration evidence on a second
evidence-only branch. Manifest schema `1.2.0` independently declares all 56
mandatory IDs, preserves exact single or ordered multi-command transcripts,
requires explicit KMDF and repository-safety metrics, and accepts binary
equivalence only from a retained source-identical A/B rebuild. Normalization is
limited to COFF timestamp, PE checksum, debug-directory timestamp, and CodeView
GUID.

**Rationale:** The second audit showed that the first remediation's 42-entry
manifest could not independently prove its mandatory set, exact retention
commands, semantic totals, complete prohibited-action counters, or equivalence
to an earlier binary pair that was no longer available.

**Alternatives rejected:** Inferring historical equivalence from unchanged
source and equal size would remain unprovable. Collapsing commands into
pseudo-commands would prevent reproduction. Treating prose safety statements
as counters would not close action evidence. Normalizing executable bytes or
unnamed differing fields would conceal behavior changes.

**Consequences:** Earlier binary hashes remain historical observations only.
Set B of the retained A/B experiment is canonical. Both A/B pairs must match in
normalized PE, executable sections, imports, disassembly, symbols, WDF
references, retention, target/request absence, and Authenticode state.
Production source remains frozen, and another independent read-only audit is
required before any runtime or deployment gate.

## 2026-07-01 - Bind production orchestration evidence to immutable scope

**Decision:** Remediate the production orchestration checkpoint on a separate
branch without changing production source. The semantic guard binds the exact
implementation parent and commit, requires Git's authoritative 14-path scope,
proves all 18 status mappings, and requires a closed metadata-complete evidence
set. Pre-final and self-referential evidence limitations are explicit.

**Rationale:** Independent source inspection passed, but the initial evidence
audit found that current-worktree scope inspection, partial mapping checks,
open-ended manifest iteration, compile-only KMDF context evidence, and missing
repository/Git evidence could not independently prove the checkpoint.

**Alternatives rejected:** Fabricating a fifteenth implementation path would
contradict Git. Amending the implementation commit would erase checkpoint
provenance. Embedding the final remediation hash in its own manifest or
claiming a guard validated its own changing transcript would be
self-referential.

**Consequences:** Runtime source remains identical to implementation commit
`efb729502a0527ac70e2d20fa31a323c3beb2920`. Acceptance requires a new
independent read-only audit of the remediated guard, manifest, ignored
evidence, containing commit, and final clean upstream state. Runtime,
target/request, signing, installation, and hardware gates remain closed.

## 2026-07-01 - Invoke dormant request-owner orchestration in production offline

**Decision:** Production `ChatpadEvtDeviceAdd` now invokes
`ChatpadKmdfRequestOwnerCreateDormantObjectGraph` exactly once after ordinary
owner initialization and explicit pre-object validation, and before lifecycle
initialization. The production call uses a stack-local zero-initialized report,
cross-checks the function return against report `Result`, maps failures before
lifecycle, and requires structural ready state before continuing.

**Rationale:** The prior defensive taxonomy and report contract selected this
binding point and failure model. The production source needed the first real
offline invocation so linker, object, binary, and guard evidence could prove
the dormant graph is reachable without adding any target/request/runtime
surface.

**Alternatives rejected:** Directly calling creation helpers from `device.c`
would duplicate orchestration and rollback ownership. Invoking orchestration
before pre-object validation would create from an unproven baseline. Invoking
after lifecycle initialization would widen cleanup obligations. Retaining
helpers through `/INCLUDE` or `/WHOLEARCHIVE` would obscure proof of actual
production reachability. Runtime loading, signing, package work, target
discovery, and request operations remain outside this offline gate.

**Consequences:** If a later authorized gate loads this driver, `EvtDeviceAdd`
would create the dormant internal spinlock, reusable request, and two
request-parented preallocated memory objects before lifecycle initialization.
This checkpoint proves only compile/link/offline evidence. Independent
implementation audit, runtime planning, signing/package work, staging,
installation, target discovery, request formatting/submission/completion/
cancellation, D0/removal rundown, and hardware observation remain separate
future gates.

## 2026-07-01 - Close defensive rollback reachability and origin evidence

**Decision:** Production orchestration uses the actual sequential no-observer
model: every ordinary R1-R20 entry is P1-P4 and permits only `ROLLBACK_OK` plus
the exact successful S1-S4 effect state. A separate finite offline
fault-injection model classifies every source rollback enum through the closed
12-label set `N0`, `J0`, `A0`, `AF`, `S1`-`S4`, and `F1`-`F4`; it is not a
production concurrency premise. Valid already-ready input requires exact
`READY`, while invalid `OWNER_READY`-bearing input preserves its actual mask.
Each R1-R20 record is self-contained and future evidence is one-to-one.

**Rationale:** The fifth independent design audit found that invalid
ready-shaped masks were normalized incorrectly, rollback rejection/effects
were not closed under the stated mutation premise, R1-R20 required cross-table
inference, and section 23 did not explicitly require R1-R20 evidence.

**Alternatives rejected:** An unlimited mutation premise cannot support a
finite exhaustive state model. Treating `ALREADY_CLEAN` as zero effects
contradicts source-populated masks and `AlreadyClean=TRUE`. Retaining compact
origin rows that depend on category/effect prose would not meet independent
field binding. Generic rollback coverage would not prove all 20 identifiers.

**Consequences:** Every rollback result enum is classified; already-clean,
invalid-mask, owner-ready, rejection, success, and post-effect states have
exact effect/final-state contracts. The 28 sections, 22 categories, insertion
point, single call/report lifetime, status mapping, WDF parentage, lifecycle
subcases, and separate implementation/runtime gates remain unchanged. Another
independent read-only audit is required before implementation.

## 2026-07-01 - Close orchestration taxonomy values and rollback effects

**Decision:** The production orchestration taxonomy uses closed
source-supported validator sets, exact rollback-effect profiles `E0` through
`E4`, and a closed rollback-origin matrix. Successful and post-effect rollback
always end in `MODEL_READY | FAULTED`; rejection before deletion is explicitly
defensive and retains its enumerated prefix. Section 28 binds every exact report
field by name, meaning, production use, and guard/evidence requirement.
`ReadyPublicationAttempted` is guarded as false before `PUBLISH_READY`, true
for final-ready validation and success, and persistent through rollback.

**Rationale:** The fourth independent audit found that taxonomy cells still
used inferred helper/validator/effect wording, section 28 omitted ten exact
field names, and the semantic guard checked only
`ReadyPublicationAttempted` presence rather than its source-level truth table.

**Alternatives rejected:** Open-ended rollback state wording would not prove
final owner state. Referring to another row's result would preserve inference.
A field-name text search would not prove ready-attempt assignment or rollback
persistence. Generic field groups in section 28 would remain incomplete.

**Consequences:** The 22 categories, 28 sections, insertion point, report
lifetime, one-call rule, early rejection, no-object faulting, status mapping,
WDF parentage, lifecycle subcases, and separate implementation/runtime gates
remain unchanged. Future guards and evidence must validate every exact report
field, rollback-effects member, ready truth-table row, and closed final state.
The next gate is another independent read-only audit.

## 2026-07-01 - Bind every orchestration report field and lifecycle outcome

**Decision:** The production orchestration-invocation taxonomy explicitly
binds all 19 source report fields for every category. Production classifies
from the orchestration function return and cross-checks report `Result`; a
mismatch is a hard `STATUS_INVALID_DEVICE_STATE` failure that cannot reach
lifecycle initialization or trigger caller-owned rollback. Exact
`ReadyPublicationAttempted` state is independent from `ReadyPublished`, final
mask `OWNER_READY`, `ObjectGraphComplete`, and successful report `Result`.
After orchestration success, current later failure behavior is split into
lifecycle-initializer failure and device-created-transition failure.

**Rationale:** The third independent design audit found that semantic shorthand
did not explicitly bind `Result` or `ReadyPublicationAttempted`, later
lifecycle wording did not reflect the deterministic current `device.c` order,
and the future evidence contract did not name both mask checks.

**Alternatives rejected:** Treating the function return as an implicit report
field would hide mismatch handling. Treating any ready-related flag as
equivalent would contradict the source. Retaining one conditional lifecycle
phrase would obscure whether initialization or the device-created transition
failed. Generic mask-evidence wording would not bind the required checks.

**Consequences:** The 22-category taxonomy and 28-section structure remain
unchanged, with category 22 divided into deterministic subcases 22A and 22B.
Future evidence explicitly checks `HighestPartialInitializationMask`
progression/rollback stability and `FinalInitializationMask` final-state
accuracy. Early rejection, no-object faulting, insertion point, one-call rule,
rollback ownership, WDF parentage, and separate implementation/runtime gates
remain unchanged. The next gate is another independent read-only audit.

## 2026-07-01 - Bind orchestration report initialization and field semantics

**Decision:** Future production `EvtDeviceAdd` code will use exactly one local
`ChatpadKmdfRequestOwnerOrchestrationReport orchestrationReport = { 0 };`,
pass it to the single synchronous orchestration call, and inspect it only after
return. The orchestrator's internal `RtlZeroMemory` remains authoritative API
behavior. Early rejection retains the incoming non-null-owner mask; after an
accepted clean baseline, `HighestPartialInitializationMask` records the
greatest published pre-ready prefix before recovery and excludes tentative
`OWNER_READY` and later `FAULTED`. `FinalInitializationMask` records the
actual non-null-owner return state.
Production status selection preserves a failing framework status only for a
creation-stage failure and maps all local validation/rollback failures to the
existing stable local status.

**Rationale:** The second independent design audit found that the prior
documentation omitted mandatory per-category report and mask behavior and
described an uninitialized C declaration as initialized. The source already
provides the required report fields and deterministic writes; the defect was
documentation completeness, not dormant implementation behavior.

**Alternatives rejected:** Leaving caller initialization implicit would keep
the future call shape ambiguous. Persisting the report in device context would
create an unnecessary observer and lifetime. Inferring cleanup from only the
top-level result would discard rollback effects and original failure evidence.
Requiring named final PE symbols would misstate COMDAT and LTCG behavior.

**Consequences:** The report remains stack-local, handle-free, synchronous,
and non-escaping. The corrected 22-category taxonomy is the binding source for
future status mapping and offline guards. The insertion point, early-rejection
semantics, one-call/no-retry rule, orchestrator-owned rollback, WDF parentage,
and separate implementation/runtime gates remain unchanged. The next gate is
an independent read-only audit of the corrected report-aware design.

## 2026-06-30 - Distinguish early rejection from no-object stage failure

**Decision:** The production orchestration-invocation design treats null
parent-device rejection, invalid-baseline rejection, and post-baseline
no-object stage failure as separate failure categories. Null parent-device and
invalid-baseline rejections return before the common orchestration failure
label, perform no rollback, and do not receive the post-baseline no-object
fault transition. Only a post-baseline staged creation failure before any
object publication uses the existing no-object fault helper. Partial-state
validation failures are represented through the existing failed stage result,
`FailedStage`, and `ValidationResult`, not through a new orchestration enum.

**Rationale:** The independent audit found that the first invocation design
overgeneralized no-object behavior by implying every pre-publication failure
entered `MODEL_READY | FAULTED`. The existing dormant orchestrator returns
invalid-baseline and null-parent results before common failure handling, while
the no-object fault helper is reached only after baseline acceptance and
staged creation entry.

**Alternatives rejected:** Treating early rejection and post-baseline
no-publication stage failure alike would keep a known source/design
contradiction. Adding a new partial-validation enum would misrepresent the
current implementation. Asking future production code to repair, reinitialize,
fault, or roll back invalid baseline state would move ownership outside the
existing orchestrator contract.

**Consequences:** The corrected design keeps the accepted insertion point,
single orchestration call, no-retry rule, production no-direct-WDF/no-direct-
rollback boundary, WDF parentage, and separate implementation/audit/runtime
gates, but the next gate returns to an independent read-only audit of the
corrected documentation before source implementation.

## 2026-06-30 - Bind production dormant orchestration after pre-object validation

**Decision:** The first future production invocation of
`ChatpadKmdfRequestOwnerCreateDormantObjectGraph` will be inserted in
`ChatpadEvtDeviceAdd` after successful ordinary owner initialization and the
additional explicit `ChatpadKmdfRequestOwnerValidatePreObjectState` check, and
before `ChatpadFilterLifecycleInitialize`. Production `device.c` will call the
orchestrator exactly once, map its result to `NTSTATUS`, and continue to
lifecycle initialization only after orchestration success. The future dormant
graph remains device-parented spinlock, device-parented targetless request,
and request-parented outbound/inbound preallocated memory.

**Rationale:** At this point the production `WDFDEVICE` and device context
exist, scalar context fields are initialized, the embedded owner is in the
validated clean `MODEL_READY` pre-object baseline, and no callback currently
observes the owner. Placing orchestration before lifecycle initialization lets
object-graph failure fail `EvtDeviceAdd` without admitting an operation or
creating lifecycle obligations. The existing orchestrator already owns
pre-ready rollback, final ready validation, and rollback-failure reporting.

**Alternatives rejected:** Invoking orchestration before ordinary validation
would duplicate baseline checks and risk creating objects from unproven
storage; invoking it after lifecycle initialization would require reasoning
about lifecycle unwind after object-graph failure; invoking helpers directly
from production `device.c` would duplicate orchestration and rollback
ownership; using prepare-hardware, D0 entry, or lazy activation would mix
device-lifetime object creation with hardware, power, or first-use state.

**Consequences:** The next gate is an independent read-only audit of the
documentation-only orchestration-invocation design. A later implementation
will be the first production slice that intentionally retains WDF
object-management helper code and changes request-owner WDF object-creation
behavior if the driver is loaded. Target discovery, request formatting,
submission, completion, cancellation, D0/removal rundown, signing,
installation, loading, and hardware observation remain separately gated.

## 2026-06-30 - Link dormant KMDF request-owner through an exact native project reference

**Decision:** The project-linkage-only production slice links
`ChatpadFilter` to `ChatpadKmdfRequestOwnerContext` with one native
`ProjectReference` and no solution-file dependency change. The reference keeps
native library dependency propagation enabled, removes inherited
`OutDir`/`IntDir` globals, and supplies explicit `AdditionalProperties` so WDK
driver-packaging project-reference passes rebuild the context library under
`artifacts\bin|obj\x64\<Configuration>\ChatpadKmdfRequestOwnerContext\`.

**Rationale:** A plain native project reference proved sufficient for ordinary
MSBuild dependency ordering and link-input propagation, but the WDK packaging
reference pass reused the consumer driver's output/intermediate directories and
emitted `MSB8028`. `GlobalPropertiesToRemove` fixed the ordinary reference
pass, while the WDK packaging target also required explicit
`AdditionalProperties` because it constructs the referenced build from item
metadata. Keeping the dependency as a project reference avoids hardcoded
library paths and keeps Debug/Release resolution configuration-correct.

**Alternatives rejected:** Directly compiling isolated request-owner sources
into `ChatpadFilter` would bypass the static-library boundary; adding a manual
`.lib` path in linker settings would be configuration- and machine-path prone;
adding `/WHOLEARCHIVE` or request-owner `/INCLUDE` would hide whether unused
library members are naturally extracted; relying on solution dependency alone
would not prove linker input propagation; accepting the WDK shared-output
warning would leave evidence ambiguous.

**Consequences:** The final driver sees the context library as a link input,
but unused request-owner object members are not extracted and no request-owner
symbols or WDF object-management imports appear in the final driver image.
Future production slices must not remove the exact output metadata unless they
replace it with equivalent WDK-packaging proof.

---

## 2026-06-30 - Gate production request-owner integration through linkage-first slices

**Decision:** Production integration of the dormant KMDF activation
request-owner graph will proceed through separately authorized slices:
project-linkage-only dormancy first, device-context embedding second, ordinary
owner-storage initialization third, and dormant orchestration invocation only
after independent audit. The production linkage mechanism is a native
`ChatpadFilter` project reference to the existing
`ChatpadKmdfRequestOwnerContext` static-library project, with required native
dependency resolution for the pure request-owner model. The future owner field
is one embedded `ChatpadKmdfActivationRequestOwner ActivationRequestOwner` in
the per-device context. Ordinary initialization and later orchestration both
belong in `ChatpadEvtDeviceAdd` after current context scalar setup and before
`ChatpadFilterLifecycleInitialize`.

**Rationale:** The isolated dormant implementation is complete, but production
linkage, storage placement, ordinary initialization, and framework object
creation have distinct binary and runtime effects. Slicing them preserves proof
that unused static-library linkage contributes no behavior, embedding ordinary
storage contributes no WDF object-management imports, ordinary initialization
creates no WDF objects, and orchestration is the first slice that creates the
dormant graph. Placing integration before lifecycle initialization keeps the
owner one-per-device and allows `EvtDeviceAdd` failure propagation before any
current callback can observe the owner.

**Alternatives rejected:** Compiling isolated sources directly into
`ChatpadFilter` would duplicate project ownership and bypass the existing
static-library boundary; adding `/INCLUDE` for request-owner helpers would hide
whether production calls naturally retain symbols; heap-allocating or globally
storing the owner would weaken per-device lifetime; invoking orchestration in
prepare-hardware, D0 entry, or lazy activation would mix device-lifetime
objects with hardware or power-cycle state; using partial rollback after
structural ready state would violate the rollback helper's pre-ready contract.

**Consequences:** The next implementation gate is project-linkage-only
dormancy, not owner embedding or helper invocation. Later ready-state
`EvtDeviceAdd` failures rely on framework cleanup of the failed device
instance and parented children, subject to an implementation audit proving the
framework cleanup contract. Future evidence manifests should be tracked as
JSON under `docs/evidence/` while full logs remain ignored under
`artifacts\logs`.

---

## 2026-06-30 - Compose dormant object creation as one all-or-nothing helper

**Decision:** The isolated KMDF request-owner module exposes one dormant
orchestration helper that validates a clean `MODEL_READY` owner, calls the
existing one-object helpers exactly in spinlock/request/outbound-memory/
inbound-memory order, validates each partial state, publishes `OWNER_READY`
only after complete pre-ready validation, and uses the existing rollback helper
exactly once for any object-published failure.

**Rationale:** Keeping orchestration as a single composition point preserves
helper independence while giving initialization one deterministic all-or-
nothing boundary. Reports carry stage, creation result, framework status, and
rollback result separately, so production linkage can later reason about
failure without guessing which object exists.

**Alternatives rejected:** Calling creation helpers from `EvtDeviceAdd` now
would execute framework object creation before the audit/linkage gate; resuming
pre-existing partial states would hide ownership ambiguity; best-effort direct
deletion from orchestration would duplicate rollback ownership; setting
`OWNER_READY` before complete validation would expose an incomplete dormant
graph.

**Consequences:** `OWNER_READY` now means only that the dormant structural
object graph is complete and non-admitting. Ready, faulted, and partial owners
are classified before helper invocation. The helper remains unlinked and
uninvoked; the next safe step is an independent read-only audit, not production
linkage.

---

## 2026-06-30 - Roll back partial creation through request-parent ownership

**Decision:** Pre-ready initialization rollback deletes the reusable request
hierarchy first and the independent bookkeeping spinlock second. Deleting the
request owns deletion of both memory children; memory objects are never deleted
individually. Owner publication is cleared immediately after each deletion is
initiated, and the resulting mask is exactly `MODEL_READY | FAULTED`.

**Rationale:** Request-parent deletion avoids sibling-order assumptions and
matches the selected object graph. Retaining `FAULTED` preserves diagnostic
failure while clearing all live-object publication. The pre-ready/no-operation
gate makes immediate handle/bit invalidation safe without synchronization.

**Alternatives rejected:** Individual memory deletion duplicates parent
ownership; best-effort cleanup of inconsistent handles guesses ownership;
returning to plain `MODEL_READY` erases failure state; normal-cleanup callbacks
would conflate initialization rollback with operation rundown.

**Consequences:** Clean and already rolled-back owners are idempotent. Invalid,
ready, draining, active, or inconsistent owners are rejected without deletion.
Full creation orchestration and owner-ready publication remain separately
gated.

---

## 2026-06-30 - Keep preallocated-memory creation independent and owner-authoritative

**Decision:** The isolated module compiles two independent
`WdfMemoryCreatePreallocated` helpers over the exact two-byte owner arrays.
Each creates at most one request-parented `WDFMEMORY`; outbound creation must
precede inbound creation. The owner's memory fields are authoritative, and the
request context does not duplicate them. Neither helper performs rollback,
deletion, readiness publication, or another creation step.

**Rationale:** One-object helpers preserve the failure boundary: outbound
failure leaves no memory state, while inbound failure leaves a valid outbound
partial state for a future orchestrator. Request parentage couples descriptor
lifetime to the reusable request, while device-owner storage keeps the arrays
alive longer than the descriptors.

**Alternatives rejected:**

* One helper creating both memory objects - would require rollback on the
  second failure.
* Dynamic memory or device-parented memory - contradicts the selected fixed
  storage and request-tree lifetime.
* Duplicate context handles - adds mutable synchronization without a consumer.
* Publish `OWNER_READY` - readiness and rollback remain separately gated.

**Consequences:** Partial validation accepts outbound-only and both-memory
states while the pure model remains unavailable/non-admitting. A future
authorized orchestrator must own reverse-order rollback.

---

## 2026-06-30 - Keep dormant lock and request creation independent

**Decision:** The isolated KMDF request-owner module compiles two independent
creation helpers: one device-parented bookkeeping `WDFSPINLOCK`, and one
device-parented reusable `WDFREQUEST` created with `WDF_NO_HANDLE` as its
initial target. Each helper calls at most one WDF creation API and never calls
the other. Successful creation publishes the handle before its corresponding
created bit. The request helper initializes its typed context before validating
the lock/request-created partial state. Neither helper performs deletion,
rollback, readiness publication, or production-driver linkage.

**Rationale:** Independent one-object helpers keep failure ownership explicit:
lock failure leaves no object, request failure leaves the already valid lock
unchanged, and a later orchestrator can own reverse-order rollback without
hidden cleanup inside a creation primitive. Targetless request creation
preserves the no-hardware boundary, while deterministic context initialization
establishes stable inactive identity before any future memory or formatting
work.

**Alternatives rejected:**

* One helper creating both objects - would require rollback inside the helper
  when the second creation fails.
* Assign an I/O target during request creation - would require target discovery
  and hardware visibility before that design gate.
* Delete an object after post-creation validation failure - deletion and
  rollback are explicitly deferred to a later orchestration slice.
* Publish owner-ready after request creation - memory objects do not exist and
  the complete owner invariant is not satisfied.
* Execute the helpers through fake handles or a fake WDF runtime - would test a
  non-production framework model and risk actual invalid WDF calls.

**Consequences:**

* The initialization mask can now represent compile-defined lock-created and
  lock/request-created partial states, but validation never executes those
  transitions.
* Exact WDF `NTSTATUS` remains separately visible from the typed project result;
  local rejection uses the stable `STATUS_INVALID_DEVICE_STATE` sentinel.
* A later request-parented memory-creation slice may build on the partial-state
  validator, but rollback remains separately gated after that slice.

---

## 2026-06-30 - Prepare exact KMDF parentage without object creation

**Decision:** The compile-only context module exposes four typed
`WDF_OBJECT_ATTRIBUTES` preparation helpers: device-parented bookkeeping lock,
device-parented activation request with
`ChatpadKmdfActivationRequestContext`, request-parented outbound memory, and
request-parented inbound memory. Each helper rejects null output and parent
arguments, leaves execution level inherited, explicitly selects
`WdfSynchronizationScopeNone`, and registers no cleanup or destroy callback.

**Rationale:** Exact public helpers make parentage and context intent
compile-checkable before object creation is authorized. Disabling automatic
synchronization preserves the separate design rule that the future spinlock,
not WDF callback serialization, owns short request bookkeeping transitions.

**Alternatives rejected:**

* Keep generic request/plain-memory initializers without parent arguments -
  would not encode or validate the selected object graph.
* Use one public memory helper for both directions - would obscure outbound
  versus inbound intent at future creation call sites.
* Inherit automatic synchronization scope - could silently bind future object
  callbacks to parent serialization despite no such callback design.
* Register cleanup or destroy callbacks now - no independent resource or
  authorized operation-rundown behavior exists for those callbacks.

**Consequences:**

* Future creation code must supply the selected device or request parent and
  check the typed preparation result.
* Attribute preparation remains side-effect free with respect to the WDF
  object graph; no handle or owner-ready state is published.
* The next safe implementation slice is dormant lock and targetless request
  creation in isolation, without memory creation or production linkage.

---

## 2026-06-30 - Initialize KMDF request-owner ordinary storage before object creation

**Decision:** The first implementation slice after the object-lifecycle design
initializes only ordinary `ChatpadKmdfActivationRequestOwner` storage in the
isolated `ChatpadKmdfRequestOwnerContext` module. The initializer clears owner
storage, writes the context signature/version, initializes the embedded pure
`ChatpadActivationRequestOwner` model, explicitly leaves all future WDF handle
fields null, clears fixed transfer storage and completion snapshots, and sets
only `CHATPAD_KMDF_REQUEST_OWNER_INIT_MODEL_READY`. A separate pre-object
validator reports typed failures and proves the model-ready-only baseline
before any framework object can be created.

**Rationale:** This gives future dormant object creation a deterministic
ordinary-storage baseline without publishing owner-ready state or introducing
framework object lifetime. It also preserves the pure model as the sole
operation/lifecycle accounting authority and keeps the production driver
unchanged until a later explicit linkage gate.

**Alternatives rejected:**

* Set `OWNER_READY` during storage initialization - would falsely represent
  lock/request/memory objects that do not exist.
* Create a fake host-side WDF runtime to execute the helper outside WDK/KMDF -
  risks duplicating opaque handle layout and testing a different contract than
  the production helper.
* Add the helper to `ChatpadFilter` immediately - would alter runtime code
  before object creation, parentage, rollback, and D0-rundown gates are
  authorized.
* Introduce a second request-owner state machine in the KMDF layer - would
  split ownership from the already tested pure model.

**Consequences:**

* `MODEL_READY` now means ordinary storage and the embedded pure model are
  initialized, but no WDF object exists.
* Validation can reject repeated initialization, non-null handles, active model
  state, unexpected initialization-mask bits, premature owner-ready state,
  nonzero transfer storage, and nonzero completion snapshots before object
  creation starts.
* Verification remains WDK compile-check plus semantic guard; host execution of
  the exact helper remains intentionally absent.
* The next safe slice is compile-only object-attribute/parentage preparation,
  still without object creation or production-driver linkage.

---

## 2026-06-30 - Select dormant KMDF object creation and cleanup ownership

**Decision:** Future dormant activation request-owner object creation will run
immediately after successful `WdfDeviceCreate` in `EvtDeviceAdd`. The future
object graph is one ordinary per-device owner structure in the device context,
one device-parented `WDFSPINLOCK`, one device-parented reusable `WDFREQUEST`
with typed request context, and two request-parented preallocated `WDFMEMORY`
objects over fixed two-byte owner arrays. The request will be created without
an initial I/O target; target discovery, formatting, submission, completion,
and cancellation remain separate gates. No cleanup or destroy callback is
selected for these dormant objects. Initialization failure will use explicit
reverse-order rollback, deleting the request before the lock; normal teardown
will rely on framework parent hierarchy deletion only after separately
designed operation rundown.

**Rationale:** Creating immediately after `WdfDeviceCreate` gives one
device-lifetime allocation path, requires no hardware or USB target, allows
failure to propagate from `EvtDeviceAdd` before owner-ready publication, and
avoids repeated allocation across D0 cycles. Device-parenting the request and
lock gives stable device lifetime. Request-parenting both memory objects keeps
transfer descriptors tied to request lifetime while ordinary owner storage
owns the fixed arrays. Explicit rollback prevents stale ordinary handle fields
after initialization failure; parent hierarchy cleanup remains sufficient for
normal no-operation teardown.

**Alternatives rejected:**

* Create in prepare-hardware - closer to hardware-resource transitions than
  needed and can repeat across resource rebalance.
* Create in first D0 entry - mixes device-lifetime allocation with power-cycle
  transitions and may repeat.
* Lazy-create before first activation - complicates first-use errors and races
  operation admission.
* Parent the request to a future target - requires target discovery before
  dormant creation and weakens the no-hardware boundary.
* Device-parent the memory objects - lets transfer descriptors outlive request
  reuse independently.
* Use cleanup/destroy callbacks for operation retirement - operation terminal
  ownership belongs to the pure model and future completion/cancellation/
  rundown paths.

**Consequences:**

* Future implementation slices have exact parentage, creation order, rollback,
  callback, and stop-condition rules.
* No current WDF object exists; this is documentation-only.
* The next safe slice is a pure owner-structure initialization and validation
  helper with no WDF object-creation call.
* Future completion and D0-rundown work must separately prove IRQL correctness
  and exact lifecycle-release ownership before any request can be submitted.

---

## 2026-06-30 - Define KMDF request-owner contexts without production linkage

**Decision:** The future activation request-owner KMDF storage is defined in
an isolated WDK static-library module,
`ChatpadKmdfRequestOwnerContext`, with a separate kernel compile-check target.
The per-device owner embeds the pure `ChatpadActivationRequestOwner` model and
declares future `WDFREQUEST`, outbound `WDFMEMORY`, inbound `WDFMEMORY`, and
`WDFSPINLOCK` handles. The reusable request receives a typed context with an
owner pointer, immutable operation token, lifecycle generation, activation
step, transfer metadata, setup packet, active transfer-memory handle, and
bounded completion snapshot.

**Rationale:** The next risk after the pure state model is type placement:
which state belongs to the device owner, which facts must be stable in the
request context, and which transfer bytes have request lifetime. Isolating
these declarations under the WDK compiler proves KMDF context/type
compatibility while avoiding object creation, callback registration, or
production-driver behavior.

**Alternatives rejected:**

* Embed the owner directly in the current `ChatpadFilter` device context - would
  alter the live driver context before creation, cleanup, and D0-rundown rules
  are authorized.
* Duplicate the pure state machine in a WDF-only structure - would create two
  ownership authorities for generation, operation token, terminal ownership,
  and exact-once lifecycle release.
* Add a WDF memory context now - no per-memory metadata is currently justified
  beyond the owner and request context fields.
* Define arbitrary or large transfer buffers - the authoritative activation
  sequence needs exactly two-byte outbound and inbound storage.

**Consequences:**

* Future object-creation work has a single intended storage layout to use.
* The new module remains absent from `ChatpadFilter` compile and link inputs.
* WDF context declarations and object-attribute initialization are compile
  checked, but no WDF object is created and no runtime behavior changes.
* The pure model gained a narrow kernel-mode `UINT32_MAX` fallback so its source
  can compile under the WDK C path.

---

## 2026-06-30 - Keep request-owner races in a pure effect-emitting model first

**Decision:** The first request-owner implementation is a portable,
WDF-independent C state model that owns no framework object and performs no I/O.
It consumes value events, validates lifecycle generation and operation identity,
and emits caller-visible effects for future lifecycle admission/release,
preparation, formatting, send/cancel call boundaries, terminal ownership,
sequence advance/abort, reuse, stale completion, and diagnostic faults.

**Rationale:** The request-owner problem is primarily exact-once ownership and
race accounting. Modeling it before KMDF integration makes send-return,
immediate completion, cancellation, stale generation, duplicate completion,
draining, and reuse rules deterministic and exhaustively testable without
creating a request, target, transfer memory, or callback.

**Alternatives rejected:**

* Implement the rules directly inside future KMDF callbacks - would combine
  object lifetime, framework call ordering, and race semantics before the state
  contract is testable in isolation.
* Extend the existing transport adapter to own request state - would mix
  portable operation planning with one specific reusable request slot and its
  lifecycle-release obligations.
* Add a WDF compile scaffold immediately - would prove type compatibility
  before proving the transition/accounting contract.
* Treat cancellation as terminal release ownership - unsafe because a cancel
  request is only an attempt to cause completion and does not itself retire an
  accepted asynchronous send.

**Consequences:**

* Future KMDF code must adapt the model effects behind explicit framework
  calls rather than inventing separate request-owner rules.
* The pure model and tests remain usable by user-mode validation and cannot
  include WDF/WDM/USB/HID/PnP headers or symbols.
* Completion remains the terminal owner after a successful send; a false send
  return retires through the initiator; cancellation alone never releases the
  lifecycle obligation.
* This checkpoint still creates no production request, transfer memory, target,
  callback, or runtime driver path.

---

## 2026-06-30 - Preallocate one activation request with request-parented transfer memory

**Decision:** A future per-device KMDF activation owner will contain exactly
one reusable `WDFREQUEST`, explicitly parented to its `WDFDEVICE`. The request
will own a typed context and two distinct nonpaged `WDFMEMORY` children: one
two-byte outbound object and one two-byte inbound object. One per-device
`WDFSPINLOCK` will protect only short lifecycle, identity, state, exact-once,
and send/cancel call-pin transitions. Completion is the terminal owner after a
successful send; a send that returns false is retired by the initiating path.

**Rationale:** The activation model permits exactly one control operation at a
time and defines a fixed two-byte maximum for both confirmed outbound payloads
and expected inbound responses. Preallocation bounds resources and makes
cancellation, generation binding, immediate completion, and request reuse
deterministic. KMDF 1.15's asynchronous USB control formatter accepts
`WDFMEMORY`, so request-parented memory gives the transfer storage the same
effective lifetime boundary as the reusable request. Send/cancel call pins
prevent a fast completion from returning the slot to idle while a framework
call still has the request on its caller's stack.

**Alternatives rejected:**

* Allocate one request per activation step - adds allocation/unwind paths and
  can become unbounded without supporting required concurrency.
* Use a request pool or global request - weakens the one-in-flight invariant or
  violates per-device isolation.
* Use stack, raw context arrays, or `WDF_MEMORY_DESCRIPTOR` as the asynchronous
  transfer lifetime - the selected asynchronous formatter requires stable
  `WDFMEMORY`, and stack-backed transfer storage is invalid.
* Use one shared bidirectional or device-parented memory object - makes
  direction and stale-data ownership less explicit and can outlive request
  reuse independently.
* Hold the spinlock across send/cancel or use synchronous blocking transfer -
  creates completion, cancellation, and D0-rundown hazards.

**Consequences:**

* Request reuse is legal only after terminal completion, return of send/cancel
  call pins, exact-once lifecycle retirement, and buffer invalidation.
* Separate outbound/inbound capacities remain exactly two bytes; no `90 00`
  payload or arbitrary response capacity is introduced.
* Failed, cancelled, stale, malformed, or duplicate terminal observations do
  not advance the six-step activation sequence.
* Activation and continuous input require separate requests, buffers, state,
  and cancellation ownership.
* This design creates no WDF object or runtime path. Each implementation slice
  requires separate authorization.

## 2026-06-30 - Compile authoritative activation preparation directly into the driver

**Decision:** `ChatpadFilter` compiles the existing activation-request,
activation-sequence, pure control-setup, and WDF formatter `.c` files directly
under the WDK toolchain. `ChatpadActivationPreparation` consumes those APIs and
is retained as a dormant linker input; it is not called by any runtime
callback. The driver adds no project reference and does not link the user-mode
libraries or `ChatpadTransport`.

**Rationale:** The portable projects use the v143 user-mode toolset, while the
same sources already pass kernel compile checks. Shared-source compilation
preserves one authoritative implementation and gives the driver exact WDK ABI
and warning validation without copying constants or linking user-mode library
artifacts.

**Alternatives rejected:**

* Copy request/setup constants into the driver - creates a second source of
  truth.
* Link the v143 user-mode static libraries - weakens kernel-toolchain proof.
* Create WDF requests or a USB target to exercise the path - crosses the
  offline preparation boundary.
* Invoke preparation from a PnP/power callback - changes runtime behavior
  before ownership, cancellation, visibility, and recovery gates pass.

**Consequences:**

* The production driver contains a deterministic six-step preparation seam.
* The same authoritative source files compile independently in portable,
  kernel-compatibility, compile-check, and driver contexts.
* Build logs and `/INCLUDE:ChatpadPrepareActivationStep` prove compilation and
  linkage while the API remains dormant.
* Request creation, target access, submission, completion, timing execution,
  installation, loading, and hardware behavior remain separate future gates.

## 2026-06-30 - Fix the offline extension prototype identity and validation floor

**Decision:** The source-controlled offline prototype uses extension ID
`{69E7CCD7-7011-4059-95D4-618974E126DD}`, AMD64 model decoration
`NTamd64.10.0...22000`, exact hardware ID `USB\VID_045E&PID_028E`, service
`ChatpadFilter`, KMDF `1.15`, DIRID 13, and declarative
`AddFilter=ChatpadFilter` with `FilterPosition=Lower`. It declares future
catalog identity `ChatpadFilterExtension.cat` but no catalog is generated or
tracked.

**Rationale:** Installed WDK 10.0.26100.0 evidence and inbox Windows INFs prove
the Extension class, stable `ExtensionId`, DIRID 13, non-associated
demand-start service, KMDF declaration, and position-based declarative filter
syntax. `InfVerif` declarative mode requires `CatalogFile`; declaring its future
identity satisfies static syntax without creating, signing, or packaging a
catalog. Windows 11 build 22000 is the narrow supported prototype floor.

**Alternatives rejected:**

* Omitting `CatalogFile` - `InfVerif /k` returns error 1233 and exit 1627.
* Naming a filter level - no reviewed `xusb22` level is available, so a level
  would invent an ordering relationship.
* Using a revision-specific, compatible-ID, HID, USB-class, XNA-class, root, or
  software-device match - broadens or changes the selected physical target.
* Associating `ChatpadFilter` as the function service - would conflict with the
  requirement to preserve `xusb22`.
* Adding the INF to the driver project or package output - crosses the isolated
  offline-prototype boundary.

**Consequences:**

* The prototype has a stable package-family identity for later offline package
  validation.
* Static validation proves syntax, exact association, lower-filter role, and
  service metadata only; it does not prove effective ordering or installation.
* Any future catalog generation, signing, staging, installation, load, or
  device action requires a separate explicit authorization gate.

## 2026-06-30 - Use a declarative extension INF for future device filtering

**Decision:** A future package for the physical
`USB\VID_045E&PID_028E` controller will be a device-specific extension INF
that registers `ChatpadFilter` through `DDInstall.Filters` and `AddFilter` with
`FilterPosition=Lower`. It must preserve Microsoft's `xusb22.inf` as the base
package and `xusb22` as the function service. Package creation, signing,
staging, attachment/loading, and device interaction remain separate explicit
authorization gates.

**Rationale:** Windows 10 version 1903 and later provide declarative
device-filter metadata and extension INFs can add a filter service without
claiming function-driver ownership. This is narrower and more serviceable than
direct filter-value writes and makes removal of the exact published extension
package the primary rollback path.

**Alternatives rejected:**

* Direct `LowerFilters` `AddReg` writes - legacy mechanism with weaker package
  ownership and ordering metadata.
* Class-wide XNA, HID, or USB filter placement - affects unrelated devices.
* Base-package replacement or WinUSB rebinding - risks removing normal
  `xusb22`/XInput behavior.
* Device Manager, DevCon, custom installer, or direct registry mutation as the
  primary workflow - creates alternate state-changing paths and weaker package
  identity evidence.
* Disabling Secure Boot, Memory Integrity/HVCI, or signature enforcement -
  weakens the safety baseline instead of validating a compatible signed driver.

**Consequences:**

* A future INF must match only `USB\VID_045E&PID_028E`, use a stable
  `ExtensionId`, define a non-associated demand/PnP filter service, and avoid
  all class-key filter writes.
* Staging must capture and verify the assigned `oem#.inf`; rollback removes
  that exact package with PnPUtil, with offline DISM reserved for last-resort
  recovery.
* The extension design and recovery specification do not prove effective
  stack ordering, default-control access, Chatpad input visibility, or runtime
  safety.
* Gate F remains operationally incomplete until the procedure is independently
  reviewed against an actual signed package and demonstrated on a noncritical
  test system.

## 2026-06-30 - Preserve exact WDF setup bytes through the public generic member

**Decision:** The compile-only WDK formatter validates the pure translation's
direction and data-stage lengths, clears the caller-owned output, and copies
the authoritative eight setup bytes directly into
`WDF_USB_CONTROL_SETUP_PACKET.Generic.Bytes`. Its kernel static-library project
has no project reference; the separate compile-check project references only
the formatter with library linkage disabled.

**Rationale:** Installed KMDF 1.15 `wdfusb.h` publicly exposes the eight-byte
generic member. Its `WDF_USB_CONTROL_SETUP_PACKET_INIT`, `_INIT_CLASS`, and
`_INIT_VENDOR` helpers construct or normalize type, recipient, and direction
fields and intentionally leave `wLength` for a later request-formatting API.
Direct byte copying is therefore the only inspected public representation that
preserves the already validated request type, recipient, value, index, and
length exactly without creating or formatting a request.

**Alternatives rejected:**

* Reconstructing the packet with class/vendor initializers - would normalize
  fields and require separate length mutation.
* Populating bitfields and words independently - would repeat endian and field
  interpretation already owned by the pure translator.
* Linking portable projects into the WDK library - unnecessary toolset coupling
  for a representation-only compile check.
* Linking the formatter into `ChatpadFilter` - would cross the approved
  compile-only boundary without transport or installation authorization.

**Consequences:**

* The formatter is deterministic, allocation-free, and caller-owned.
* Payload and control-IN response storage remain outside the setup packet.
* Compile success proves installed-WDK type compatibility only; it does not
  prove target access, transmission, completion, acknowledgement, or readiness.
* Future request-owner work must pass separate lifecycle, installation,
  recovery, stack-visibility, and explicit-authorization gates.

## 2026-06-30 — Represent control setup as explicit caller-owned bytes

**Decision:** Pure activation control-setup translation uses an eight-byte
array for setup fields plus explicit data-stage direction, fixed-capacity
outbound value bytes, outbound length, and expected inbound length. The
translator validates the caller-provided `ChatpadActivationRequest`, clears the
complete non-null output before validation, encodes 16-bit setup fields
little-endian, and has no packed or on-wire structure overlay.

**Rationale:** Explicit bytes make field order and endianness inspectable in
user-mode tests and through the kernel compile toolchain without importing
Windows, WDF, WDM, or USB headers. Caller-owned values avoid allocation,
pointer lifetime, mutable global state, fabricated response storage, and
coupling to future request formatting.

**Alternatives rejected:**

* Packed setup structure or cast overlay — creates unnecessary layout and
  packing assumptions.
* Returning payload or setup pointers — introduces lifetime and aliasing
  concerns.
* Deferring malformed direction or length validation — permits inconsistent
  descriptors to cross the pure boundary.
* Creating a response buffer for control-IN descriptors — response contents
  and semantics remain unresolved.
* Translating directly to a WDF setup type — mixes pure evidence translation
  with the later compile-only framework formatting boundary.

**Consequences:**

* The six confirmed descriptors remain owned by
  `ChatpadBuildActivationRequest`; the translator duplicates no request tuple.
* Host-to-device payload length must equal setup `wLength` and fit capacity;
  device-to-host descriptors must have no outbound payload and expected inbound
  length must equal `wLength`.
* Zero-length requests have no data stage. `09 00` is copied only for confirmed
  request 4; arbitrary synthetic payload content remains structurally valid.
* A later WDK formatter may consume this value, but it must remain isolated
  from target/request creation, formatting, submission, and `ChatpadFilter`.

## 2026-06-30 — Use a per-device KMDF transport owner for future bridge work

**Decision:** Future KMDF transport bridge work will use one per-device
transport owner under `WDFDEVICE`. That owner conceptually owns bounded
activation bridge state, generation-bound request-owner records, future target
references, future delay scheduler state, diagnostics, and separate
continuous-input state. WDF requests will be associated with one nonzero D0
generation through a request-owner record containing the portable
`ChatpadTransportOperationToken`; raw request pointers must not become
generation or operation tokens.

**Rationale:** The lifecycle scaffold already models per-device resource and
D0 epochs, and the transport adapter already models bounded activation
operations. A per-device owner keeps those facts aligned without recreating
legacy global device selection or sideband raw-context lifetime hazards.
Generation-bound request records give stale and duplicate completions a clear
rejection point and keep lifecycle outstanding counts paired exactly once.

**Alternatives rejected:**

* Global transport state — repeats legacy multi-device and unplug hazards.
* Raw WDF request pointer as a portable token — couples portable state to object
  addresses and weakens stale-generation checks.
* Linking portable transport directly into `ChatpadFilter` without a bridge
  owner — hides lifetime, cancellation, and synchronization responsibilities.
* Reusing the activation adapter's 64-operation model for continuous input —
  continuous reads need a separate bounded owner and resubmission model.

**Consequences:**

* Future request creation, cancellation, and completion must pass through the
  per-device owner.
* D0 exit must close admission before cancellation and before delay scheduling.
* Stale and duplicate completion handling must compare stored generation/token
  and completion-once state before releasing lifecycle counts or scheduling
  follow-on work.
* Continuous input remains a separate future design and cannot reuse the
  activation operation table as its architecture.

## 2026-06-30 — Prefer a per-device spinlock for first bridge synchronization

**Decision:** The first KMDF bridge implementation should use a per-device
`WDFSPINLOCK` for short shared-state transitions covering lifecycle/bridge
state, request-owner records, completion-once flags, cancellation flags,
generation validation, scheduler state, and bounded diagnostics. Passive work
may later orchestrate passive-only operations, but it must not replace the
per-device protected state boundary.

**Rationale:** Future request completions and cancellation paths may not all be
passive-level. The lifecycle core is externally serialized and not internally
thread-safe, so bridge state needs one explicit protection model before any
runtime request work exists. A spinlock supports completion-path validation as
long as no blocking, allocation, formatting, submission, waiting, or callbacks
occur while it is held.

**Alternatives rejected:**

* Unsupported lock-free use — no current atomic or memory-ordering proof exists.
* KMDF automatic synchronization alone — callback coverage can be incomplete
  for timers, completions, and future side paths.
* `WDFWAITLOCK` as the default — useful only for passive paths and unsuitable
  if completions can arrive at dispatch level.
* Passive serialized work as the only model — useful for orchestration but
  too indirect for urgent cancellation, completion-once, and generation checks.

**Consequences:**

* Future code must keep spinlock critical sections tiny.
* The lock must not be held across lower-target calls or waits.
* Every callback that touches bridge state must be listed against the
  synchronization model before runtime implementation progresses.

## 2026-06-29 — Use a device-specific lower-filter direction, conditional on transport evidence

**Decision:** The Windows 11 attachment architecture targets the physical
`USB\VID_045E&PID_028E`/`XnaComposite` controller devnode with a
device-specific lower filter beneath `xusb22`. This is a conditional design
direction, not an implementation approval or a preferred candidate. It cannot
become preferred until evidence proves both default-control access and a safe
Chatpad input path at that position.

**Rationale:** The current inventory proves that the controller node is owned
by `xusb22`, that no independent Chatpad node exists, and that no relevant
filter is installed. The legacy device-specific lower filter is the only
candidate with historical evidence for both device-level control requests and
a separately owned Chatpad read. Current endpoint and transport visibility
remain unknown.

**Alternatives rejected:**

* `IG_01` attachment — function semantics and parent-control access are not
  established.
* HID-descendant attachment — the collection is not attributed to Chatpad and
  does not prove default-control access.
* Class-wide XNA/HID filtering — broad impact without additional capability.
* WinUSB/binding replacement — risks removing normal Microsoft/XInput behavior.

**Consequences:**

* A future INF must target the exact hardware ID in a device install section
  and must not alter XNA or HID class filter values.
* Normal `xusb22` traffic must be forwarded unchanged; proxying ordinary reads
  is prohibited unless separately evidenced and approved.
* Attachment, preservation, transport-visibility, endpoint/input, lifecycle,
  recovery, and explicit-authorization gates are hard stops.
* Failure to prove either transport path reopens the attachment decision; it
  does not authorize guessing legacy pipe ordinals.

## 2026-06-29 — Separate physical transport from keyboard presentation

**Decision:** Physical controller attachment and USB transport remain separate
from future keyboard presentation. Transport produces portable decoded state;
a distinct output boundary may later use an approved virtual HID mechanism.
The installed WDK's VHF surface is a candidate, not a selected implementation.

**Rationale:** Keyboard policy and presentation do not require ownership of the
physical Xbox stack. Separation reduces blast radius, keeps `xusb22` behavior
independent, and allows output signing, HVCI, report, and lifecycle questions
to be validated without connected-controller traffic.

**Alternatives rejected:**

* Reproduce the legacy KMDF plus WDM HID-minidriver and PnP-ID spoofing stack —
  obsolete and unnecessarily complex.
* Treat the existing HID descendant as Chatpad output or input — unsupported by
  inventory evidence.
* Couple user-mode key injection directly to USB transport — mixes security,
  session, and device-lifetime responsibilities.

**Consequences:**

* `ChatpadProtocol` remains free of WDF, USB, HID, timer, and handle types.
* A future output prototype must independently validate target support,
  signing, Memory Integrity, report semantics, cancellation, and teardown.
* No semantic key mapping or keyboard technology is selected by the transport
  architecture.

## 2026-06-29 — Separate raw machine inventory from stable driver-design facts

**Decision:** Exact connected-device instance IDs, container GUIDs, symbolic
interface paths, location paths, serial-like instance components, and raw
registry/topology metadata remain only beneath ignored
`artifacts/device-inventory/`. Committed documentation records redacted identity
patterns and stable design facts such as VID/PID, hardware/compatible IDs,
class, service, driver binding, interface-class GUIDs, and topology shape.

**Rationale:** Exact raw values are necessary to prove one inventory run and
compare baseline/final device state, but several values identify this machine,
physical port, or device instance and are not required for portable design.

**Alternatives rejected:**

* Commit the canonical inventory JSON — would retain machine-specific paths,
  GUIDs, and identifiers in repository history.
* Remove exact values from generated output — would weaken auditability and
  prevent exact local correlation.
* Treat missing cached properties as physical-device absence — a selected
  read-only source can be incomplete.

**Consequences:**

* `tools/Get-ConnectedChatpadInventory.ps1` writes all raw output only beneath
  ignored artifacts.
* Stable documentation distinguishes direct observation, derived relationship,
  inference, and unresolved detail.
* Future tasks must not promote exact raw identifiers into tracked files unless
  they are independently proven non-unique and technically necessary.

## 2026-06-29 — Represent activation sequencing and legacy timing as declarative metadata

**Decision:** The activation-sequence planner exposes exactly six steps through
`ChatpadGetActivationSequenceStepCount` and
`ChatpadGetActivationSequenceStep`. Each step carries a sequence index, the
matching request-builder index, a caller-owned request descriptor obtained from
`ChatpadBuildActivationRequest`, and declarative timing metadata. The current
timing metadata is `DelayBeforeMilliseconds = 0` and
`DelayAfterMilliseconds = 12` for every step.

**Rationale:** The legacy evidence confirms a software call order and that
`SendControlRequest` slept 12 ms after each call returned, including after
failure. It does not prove a device-required inter-request minimum,
pre-request delay, response deadline, retry policy, acknowledgement, or ready
condition. Modeling the observed post-call delay as data preserves evidence
without adding runtime behavior.

**Alternatives rejected:**

* Sleeping, waiting, enforcing deadlines, or adding retry policy in the
  planner — would convert evidence metadata into active transport behavior.
* Duplicating the six request tuples in a second planner table — would create
  another source of truth and risk drift from the request builder.
* Encoding `90 00`, response bytes, acknowledgement states, readiness states,
  or timeout statuses — none are confirmed by the evidence.
* Treating zero before-delay as a device no-delay requirement — zero only means
  no confirmed pre-request timing metadata exists.

**Consequences:**

* Callers can inspect the confirmed order and legacy timing metadata offline.
* The planner remains allocation-free, I/O-free, transport-free, driver-free,
  and hardware-free.
* Mutating a returned step cannot affect later planner calls.
* Future executor work must consume the metadata without sleeping or claiming
  device readiness unless a later task explicitly opens that scope.

## 2026-06-29 — Represent activation requests as immutable value-copy descriptors

**Decision:** The activation-request API exposes exactly six confirmed legacy
setup descriptors through `ChatpadGetActivationRequestCount` and
`ChatpadBuildActivationRequest`. The implementation stores a private
`static const` table and copies one descriptor into caller-owned output. The
public value separates raw setup fields, direction, outbound payload length,
expected inbound data length, and embedded outbound payload bytes.

**Rationale:** The audit proves six setup tuples and exactly one outbound
payload, `09 00`, but does not prove response bytes, acknowledgement,
readiness, retries, status decoding, or complete initialization success. A
value-copy descriptor preserves exact evidence without exposing transport,
static payload pointers, mutable state, or lifetime assumptions.

**Alternatives rejected:**

* Returning pointers into a public request table — would expose internal
  storage and create lifetime/mutation assumptions.
* Encoding `90 00` — the audit classifies it as a comment-only claim on an
  unused internal structure.
* Naming requests as ready, acknowledged, initialized, or successful — those
  semantics remain unresolved.
* Adding transport results, timeout statuses, retry states, or response
  buffers — outside the confirmed evidence boundary.
* Including MSVC `stdint.h` unconditionally under the WDK toolchain — it
  collides with kernel CRT headers under `/W4 /WX`, so the public header uses
  standard `<stdint.h>/<stddef.h>` for normal C callers and a primitive
  kernel-safe fallback only when `_MSC_VER` and `_KERNEL_MODE` are both set.

**Consequences:**

* Callers always receive a deterministic value copy; modifying one result does
  not affect later calls.
* Invalid indexes clear non-null output; null output is rejected safely.
* Device-to-host descriptors carry no fabricated outbound data or response
  bytes.
* The API remains portable C, allocation-free, I/O-free, transport-free, and
  compile-compatible with the isolated WDK static-library check.

## 2026-06-29 — Model offline protocol progress as caller-supplied classifications

**Decision:** The portable state machine records only the latest neutral
classification: awaiting classification, accepted keyboard data, unsupported
input, policy-rejected input, or unresolved control/status. Inputs are explicit
abstract events. Existing parser results map only `OK`, unsupported type, and
policy-rejected modifier; parser argument and length failures remain
unclassified and cause no transition. Initialization/status forms are accepted
only through an unresolved caller event, never decoded from raw bytes.

**Rationale:** Current evidence proves the five-byte keyboard boundary but does
not prove a complete initialization sequence, status codes, readiness meaning,
timing, retries, or transport behavior. A caller-classified state machine adds
deterministic offline sequencing without converting missing evidence into
protocol claims.

**Alternatives rejected:**

* Decoding `0x90, 0x00` as a complete initialization command — evidence says
  only that the legacy structure contains those bytes.
* Naming states initialized, connected, ready, online, or authenticated — none
  of those semantics is proven.
* Treating malformed parser input as unsupported protocol data — argument and
  length failures are API/boundary failures, not confirmed device forms.
* Retaining packets or caller pointers — unnecessary for classification and
  contrary to the portable ownership boundary.

**Consequences:**

* State and transition storage are caller-owned, allocation-free, and reset
  explicitly.
* Repeated events are deterministic and report whether the classification
  changed.
* Unresolved initialization/status input stays visibly unresolved until new
  offline evidence supports a narrower classification.
* The layer remains disconnected from `ChatpadFilter` and all runtime paths.

## 2026-06-29 — Use a protocol-owned type boundary and an isolated WDK static-library proof

**Decision:** Public protocol data uses `ChatpadUInt8` and `ChatpadSize` from
`ChatpadProtocolTypes.h`. MSVC derives them directly from compiler primitive
types; other C compilers map them to standard `uint8_t` and `size_t`. The
parser declaration remains in `ChatpadKeyboardParser.h` with C++ `extern "C"`
linkage. Kernel compatibility is proven by compiling both the full parser
implementation and a small interface consumer into a standalone WDK static
library that is not referenced by `ChatpadFilter`.

**Rationale:** Including MSVC's user-mode `stdint.h` beneath the WDK kernel
toolchain collides with the WDK kernel CRT headers under strict `/W4 /WX`.
Protocol-owned aliases preserve fixed-width and size semantics without a
Windows or WDK dependency, warning suppression, packing, or an ABI change.
The isolated static library proves compile compatibility without introducing
runtime driver behavior.

**Alternatives rejected:**

* Suppressing WDK/MSVC header-collision warnings — would weaken the strict
  warning gate and leave the public boundary dependent on conflicting headers.
* Using WDK types such as `UCHAR` or `SIZE_T` — would make the public header
  kernel-specific.
* Linking the parser or compatibility library into `ChatpadFilter` — runtime
  integration is outside this task and would violate driver isolation.
* Marking decoded output packed — no wire-layout ABI requirement is proven.

**Consequences:**

* C and C++ user-mode callers retain the existing parser behavior and ABI.
* Kernel-mode C can consume the headers and compile the parser without Windows
  user-mode headers, WDK API headers, allocation, mutable globals, or callbacks.
* Compatibility output is a non-loadable `.lib`; no `.sys`, signing, package,
  deployment, or hardware path is introduced.

## 2026-06-29 — Keep the Phase 1 parser raw, neutral, and policy-labeled

**Decision:** `ChatpadParseKeyboardPacket` accepts exactly five bytes, supports only raw type `0x00`, preserves all five accepted bytes without semantic key decoding, returns `CHATPAD_PARSE_UNSUPPORTED_TYPE` for `0xF0` and every other unsupported type, and returns `CHATPAD_PARSE_POLICY_REJECTED_MODIFIER` when modifier upper bits are set. A non-null output is cleared before every failure return.

**Rationale:** The protocol audit confirms the five-byte shape and that legacy code ignores `0xF0`, but it does not establish the exact meaning of `0xF0`, modifier bit meanings, or Byte 4. Neutral names prevent project policy from being mistaken for device protocol fact. Deterministic clearing makes all failure paths safe for callers and directly testable.

**Alternatives rejected:**

* Naming `0xF0` as repeated — the evidence does not confirm that semantic meaning.
* Naming upper modifier bits invalid — rejection is a conservative Phase 1 policy, not a proven device rule.
* Decoding raw key bytes or Byte 4 — those interpretations are outside the confirmed parser boundary.
* Copying input before validation or retaining input pointers — weakens failure determinism and caller safety.

**Consequences:**

* Callers receive raw fields only and must not infer key or modifier meaning from this parser API.
* Every accepted packet is exactly five bytes with type `0x00` and modifier upper bits clear.
* The parser remains portable C with no allocation, I/O, Windows, WDK, USB, HID, IOCTL, device, or kernel dependency.
* Future protocol evidence may extend supported forms through an explicit API and policy decision rather than silently changing Phase 1 semantics.

## 2026-06-29 — Distinguish wire-format evidence from internal transport structures in protocol documentation

**Decision:** The protocol evidence document (`docs/CHATPAD-PROTOCOL.md`) MUST use two separate sections: Section A for packets or bytes actually received from or sent to the Chatpad/device transport, and Section B for internal software structures (keyboard IOCTL, mouse IOCTL, control-transfer request parameters, internal state messages, user-mode mapping structures). Any structure not directly proven to be transmitted unchanged on the device endpoint must be labeled "Internal transport structure — not confirmed as Chatpad wire format."

**Rationale:** The initial protocol document placed the 4-byte virtual mouse message and 9-byte control-transfer structure under "Confirmed Packet Forms," implying wire format. The virtual mouse message is constructed internally to emulate a Windows HID mouse; the control-transfer structure describes USB setup packet fields, not a serialized device wire frame. Misclassification risks the next parser implementation treating internal constructs as device protocol.

**Alternatives rejected:**
* Keeping everything under a single "Confirmed" section — loses the distinction needed for parser boundary decisions.
* Adding inline footnotes — harder to scan than a structural section split.
* Removing the internal structures from the document entirely — they are useful context; the fix is clearer labeling, not omission.

**Consequences:**
* The parser boundary defined in the Proposed Phase 1 section can now be read as policy rather than protocol, since the surrounding context properly distinguishes what is device evidence from what is internal.
* The next agent (parser implementation) can safely treat Section A as the sole source of wire-format fixture data.
* The distinction is durable and will apply to any future protocol documentation in this project.

## 2026-06-29 — Keep compile-only WDK builds unsigned and route paths through the wrapper

**Decision:** Set `<SignMode>Off</SignMode>` in both supported configuration property groups in `ChatpadFilter.vcxproj`. Compute absolute `OutDir` and `IntDir` paths from the repository root in `tools/Build-Driver.ps1`, ensure each ends with the platform directory separator, and pass both as MSBuild global properties.

**Rationale:** WDK kernel-mode imports enable test signing by default when `SignMode` is empty. The repository has no certificate or installable package and this phase authorizes compilation only. Wrapper-owned global properties keep generated paths independent of project location and machine-specific checkout paths.

**Alternatives rejected:**

* `SignMode=Disabled` — not the supported WDK value required for this repository.
* TestSign, ProductionSign, certificate generation, digest options, or custom SignTool commands — outside the compile-only safety boundary.
* `MSBuildThisFileDirectory` output paths in the project or shared props — resolve relative to an imported file or project context and previously allowed source-tree output.
* Forcing `ObjectFileName=$(IntDir)\` — masked a missing trailing separator and created a spurious `+` intermediate directory rather than fixing directory semantics.

**Consequences:**
* Debug x64 and Release x64 builds produce unsigned `.sys` files only beneath ignored `artifacts/`.
* `tools/Build-Driver.ps1` is the canonical build entry point and rejects any active signing task, unexpected output path, signed result, or nonzero MSBuild result.
* Installation, packaging, signing, deployment, loading, and runtime testing remain prohibited until separately authorized.

## 2026-06-29 — Establish persistent project continuity workflow (AGENTS.md)

**Decision:** Every agent working in this repository must follow the START/DURING/END routine defined in `AGENTS.md`. Documentation must be kept in sync with actual repo state before each task begins.

**Rationale:** Previous sessions lacked a continuity system, causing agents to work from assumptions rather than verified state. The START-OF-TASK routine forces agents to read the actual branch, commit, git status, and relevant history before implementation. The END-OF-TASK routine ensures the next agent starts from accurate documentation.

**Alternatives rejected:**
* Per-agent self-documentation without a shared protocol — too fragile, inconsistent.
* Storing state only in session history — not portable across agents.
* Embedding workflow rules in project metadata — agents don't read MSBuild props as workflow instructions.

**Consequences:**
* Every task now takes ~30s of read-in before implementation.
* Stale documentation must be corrected before being trusted.
* Future agents can pick up work from `docs/NEXT-TASK.md` without session context.

## 2026-06-29 — Protocol build integration approach

**Decision:** Build ChatpadProtocol as a dependency of ChatpadFilter using separate MSBuild invocations (not solution-level Build).

**Rationale:** Building the solution with `/t:Build` on ChatpadFilter would route ChatpadProtocol's intermediate output into ChatpadFilter's IntDir, causing PDB collisions and incorrect output paths. Separate MSBuild calls ensure each project's own IntDir/OutDir is respected.

**Alternatives rejected:** Building the solution file directly with `/t:Build`.

**Consequences:** `Build-Driver.ps1` now builds ChatpadProtocol first, then ChatpadFilter. Both use `/p:RepoRoot` and pass explicit `OutDir`/`IntDir` to MSBuild. Directory.Build.props adds a `RepoRoot` property. `ChatpadFilter.vcxproj` SignMode remains Off.

## 2026-06-29 — SignTool detection expansion

**Decision:** Expand SignTool execution detection in `Build-Driver.ps1` to match MSBuild diagnostic log patterns including `:` after target name, `Task`/`Using` prefix, `SIGNTASK:`, and explicit `signtool.exe` paths.

**Rationale:** The original regex only matched target names with `(\")` suffix, missing the `(:)` form present in diagnostic logs.

**Consequences:** `Build-Driver.ps1` now reliably detects active WDK signing tasks in MSBuild diagnostic output.

## 2026-06-29 — PowerShell 5.1 compatibility

**Decision:** Replace `[System.Text.UTF8Encoding]::new($false)` with `[System.Text.Encoding]::UTF8` and use `.NET` SHA256 fallback for `Get-FileHash` in `Test-ChatpadProtocolParser.ps1`.

**Rationale:** `[System.Text.UTF8Encoding]::new(false)` is not available in PowerShell 5.1 (requires .NET Framework 4.6+). The .NET fallback ensures compatibility.

**Consequences:** Test scripts work across PowerShell 5.1+ without version-specific syntax.

## 2026-06-29 — Native ProjectReference for ChatpadProtocol linkage

**Decision:** Use a native `ProjectReference` in `ChatpadProtocolTests.vcxproj` referencing `ChatpadProtocol.vcxproj` instead of hardcoded `AdditionalDependencies` and `AdditionalLibraryDirectories`.

**Rationale:** ProjectReference is the standard MSBuild mechanism for library dependencies. It ensures configuration-independent linking (Debug links Debug, Release links Release), build ordering (ChatpadProtocol builds before ChatpadProtocolTests), and eliminates hardcoded machine paths. The previous approach required manual synchronization of library paths and was configuration-specific.

**Alternatives rejected:**
* Hardcoded AdditionalDependencies/AdditionalLibraryDirectories — configuration-specific, requires manual path maintenance, breaks build ordering.
* Solution-level SolutionDependencies only — doesn't propagate linker dependencies to the consuming project's MSBuild evaluation.

**Consequences:**
* ChatpadProtocolTests links ChatpadProtocol.lib via native MSBuild dependency resolution.
* Debug/Release configurations automatically resolve to matching library configurations.
* ChatpadProtocol builds before ChatpadProtocolTests due to ProjectReference build ordering.
* No hardcoded paths in the vcxproj files.
* SolutionDependencies section in ChatpadWin11.sln removed as redundant with ProjectReference.

## 2026-06-29 — Activation execution is callback-only planning emission

**Decision:** `ChatpadExecuteActivationPlan` is a transport-independent
executor contract that consumes `ChatpadGetActivationSequenceStep` output and
emits planned operations through caller-provided callbacks only. A request
callback means the planned request was emitted to the caller, not transmitted.
A delay callback means nonzero delay metadata exists, not that time elapsed.
Callback acceptance means the caller accepted the emitted operation for its own
recording or orchestration; callback rejection is an API/callback outcome, not
a device, USB, HID, IOCTL, driver, or hardware failure.

**Rationale:** The repository has confirmed request tuples and declarative
timing metadata, but it does not yet have confirmed transport behavior,
response bytes, acknowledgement, readiness, timeout, retry, or hardware
semantics. A callback-only executor lets tests validate ordering, value-copy
request propagation, and delay metadata propagation without widening the
evidence boundary.

**Alternatives rejected:**

* Sending USB/HID/IOCTL requests from the executor — outside the current safety
  authorization and not supported by confirmed device inventory.
* Sleeping or starting timers for delay metadata — would convert legacy
  post-call timing evidence into runtime behavior.
* Returning transport/device statuses — no transport has been authorized or
  proven.
* Retaining caller pointers or allocating execution records internally — would
  weaken portability and deterministic testability.

**Consequences:**

* The executor is reusable in user-mode and kernel compile contexts without
  Windows or WDK API calls.
* Callers must provide both request and delay metadata callbacks and a summary
  output.
* Summaries contain only planned count, emitted counts, last completed step,
  rejected operation kind, and rejected step index.
* Future transport work must adapt this contract explicitly and cannot treat
  callback emission as successful hardware transmission.

## 2026-06-29 — Transport adapter is a neutral static-library contract

**Decision:** Add `ChatpadTransport` as a WDF-independent static-library
contract with caller-owned state, explicit device generations, neutral
operation tokens, callback-based activation-plan emission, and deterministic
test-only mocks. Keep it separate from `ChatpadFilter`.

**Rationale:** The project has confirmed portable activation descriptors and
executor ordering, but it still lacks confirmed Windows 11 default-control
access, input-transfer ownership, endpoint identity, response semantics,
readiness, retry, and hardware behavior. A neutral adapter contract lets the
repository test cancellation and generation semantics without pretending to
own a real transport.

**Alternatives rejected:**

* Adding WDF request objects or USB/control-transfer fields to the contract —
  would cross the current evidence and authorization boundary.
* Linking the transport into `ChatpadFilter` immediately — would imply runtime
  driver integration before a lifecycle scaffold and hardware evidence exist.
* Duplicating activation descriptor constants in the transport layer — would
  create a second source of truth instead of using the existing protocol
  interfaces.

**Consequences:**

* `ChatpadTransport` builds as a user-mode static library and compiles through
  the WDK static-library compatibility project.
* Tests use bounded mocks under `tests/transport/` and remain fully offline.
* `ChatpadFilter` remains disconnected from protocol and transport libraries.
* Future KMDF work must explicitly adapt this neutral contract and still pass
  the architecture stop gates before any hardware behavior.

## 2026-06-29 — Keep KMDF filter lifecycle state in a portable core

**Decision:** `ChatpadFilter` owns per-device lifecycle bookkeeping through a
portable C core compiled into both the KMDF driver and a native user-mode test
executable. The KMDF layer registers only prepare/release hardware and D0
entry/exit callbacks, then delegates neutral phase, D0 generation, admission,
rundown, stale-generation, and snapshot state transitions to that core.

**Rationale:** Lifecycle and generation rules are easier to validate offline
when they are isolated from WDF objects, USB targets, request queues, timers,
threads, and hardware. This preserves the current evidence boundary while
giving future KMDF work a deterministic stop/admission model.

**Alternatives rejected:**

* Put lifecycle counters directly in WDF callbacks only — would make most
  rules hard to validate without driver execution.
* Link the existing transport or protocol libraries into `ChatpadFilter` now —
  would imply runtime integration before hardware transport evidence exists.
* Add queues, timers, work items, or USB request holders with the lifecycle
  scaffold — outside the compile-only authorization.

**Consequences:**

* The lifecycle core has no WDF/WDM/Windows/USB/HID/IOCTL/runtime dependency
  and must remain externally serialized by its caller.
* `WdfFdoInitSetFilter(DeviceInit)` is documented as filter-capability only;
  INF targeting and lower-filter placement remain future install
  responsibilities.
* Future runtime integration must acquire operation admission for the current
  nonzero D0 generation and must handle busy D0 exit without waiting in the
  callback.

## 2026-06-30 - Link the portable owner model as a production WDK object

**Decision:** Compile `ChatpadRequestOwnerModel.c` directly in
`ChatpadFilter.vcxproj` for Debug and Release x64. Keep the existing
`ChatpadKmdfRequestOwnerContext` project reference as the only source of the
authoritative KMDF context implementation.

**Rationale:** The ordinary KMDF owner initializer and validator depend on the
pure model. The existing user-mode model static library carries
`MSVCRT`/`MSVCRTD` default-library metadata and is not an appropriate
kernel-driver link input. The source is already portable and is compiled
directly by the WDK compatibility project.

**Alternatives rejected:**

* Link the user-mode model library into the driver - imports user-mode runtime
  link assumptions into a kernel binary.
* Compile `ChatpadKmdfRequestOwnerContext.c` directly in `ChatpadFilter` -
  duplicates the authoritative context project and violates the established
  project-linkage boundary.
* Duplicate the model implementation - creates a second source of truth.

**Consequences:** Production links one WDK-compiled pure-model object, adds
only the context/model/transport include roots, and remains independent of the
user-mode model library. The production source calls only the authoritative
KMDF ordinary initializer and pre-object validator; dormant orchestration and
WDF object creation remain unreferenced.

## 2026-06-30 - Treat production owner-initialization evidence as combined proof

**Decision:** The production owner-initialization checkpoint is audited through
combined source, project, object, COMDAT, linker-tlog, PE section, symbol, and
manifest-containment evidence. The guard and manifest must report direct
observations separately from inferences, and the retained manifest entries for
the corrected evidence must include exact commands and working directories.

**Rationale:** Debug object references can show the two allowed owner calls
directly, while Release `/GL` inputs may inline them before final PE
inspection. Also, KMDF named imports alone cannot prove absence of framework
calls because KMDF APIs dispatch through the WDF function table. A combined
evidence rule prevents the audit from over-claiming what ordinary import or
final-symbol inspection can prove.

**Alternatives rejected:**

* Treat final PE import absence as standalone proof - misses the WDF
  function-table dispatch limitation.
* Require Release final symbols to expose allowed owner calls - incompatible
  with the existing `/GL`/LTCG evidence path.
* Keep manifest commands as summaries only - insufficient for independent
  reproduction of a documentation/evidence correction.

**Consequences:** Future owner-initialization audits must verify the retained
artifact chain and proof limits, not just search final driver imports. Evidence
manifests for corrected retained logs should preserve exact command text,
working directory, path, hash, configuration, mode, and result.

## 2026-07-02 - Use one WPP provider for offline runtime diagnostics

**Decision:** Implement offline runtime diagnostics with one WPP software
tracing provider, GUID `{1B3D3598-9D78-4F3E-9DB2-95BB9344A731}`, schema
version `1`, and the accepted 73-event catalogue shared by `ChatpadFilter` and
`ChatpadKmdfRequestOwnerContext`.

**Rationale:** The first controlled load needs Release-capable, structured,
per-attempt evidence for driver entry, device creation, owner initialization,
orchestration, readiness, lifecycle, rollback, cleanup, invariant, prohibited
counter, and terminal outcomes. A single provider keeps correlation and static
validation simple while preserving existing `KdPrintEx` as a fallback.

**Alternatives rejected:**

* `KdPrintEx` only - not sufficiently structured or independently auditable.
* Multiple providers - unnecessary correlation complexity for one driver
  checkpoint.
* TraceLogging or event-log writes - broader runtime surface than required for
  this offline instrumentation gate.

**Consequences:** WPP preprocessing is enabled for the driver, request-owner
context, and direct compile-check project; generated trace outputs stay under
ignored `artifacts/`. The implementation remains offline-only and does not
authorize signing, packaging, installation, driver loading, trace collection,
target discovery, request execution, or hardware interaction.

## 2026-07-02 - Require canonical flat stop-condition linkage arrays

**Decision:** Stop-condition implementation linkage values are direct,
one-dimensional arrays of normalized repository-relative `.ps1` paths.
Validation reads the property value directly, rejects nested arrays instead of
flattening them, and verifies string shape, containment, existence, approved
type, and normalized uniqueness.

**Rationale:** `Get-ChatpadProperty` preserves an array-valued property by
returning it with unary-comma enumeration suppression. Wrapping that return in
`@(...)` creates an outer array whose only item is the original array. The
previous stop-linkage validator therefore failed to recognize each valid
single-item runtime-observer linkage.

**Alternatives rejected:**

* Silently flatten nested arrays - would allow malformed external input to
  become valid and hide producer or parameter-boundary defects.
* Compare stringified array values - would weaken type, path, and duplicate
  validation.
* Special-case only the five observer IDs - would leave executable linkage
  paths without the same canonical contract.

**Consequences:** All executable and runtime-observer linkage paths use
`tools/...` repository-relative names. Double-wrapped and deeper arrays fail
as `STOP_LINKAGE_INVALID`; all five runtime-only conditions link to
`tools/Test-ChatpadRuntimeObservation.ps1` and remain unevaluated offline.

## 2026-07-03 - Gate future native mutations with module-private capability sentinels

**Decision:** Future SetupAPI/Newdev mutation operations must require a
module-private native mutation capability sentinel. Public functions may expose
read-only design probes and contract inspection, but public callers cannot
construct a live mutation capability or authorize native binding, restoration,
restart, or reboot.

**Rationale:** The exact-instance framework needs a future native composition
root without creating a caller-controlled execution switch. A module-private
sentinel keeps authorization tied to audited composition code instead of
strings, Booleans, elevation, or command-line intent.

**Alternatives rejected:**

* Caller-provided flags or strings - spoofable and difficult to audit.
* Public capability constructors - allow test or caller code to grant itself
  mutation authority.
* Implementing native API calls during this phase - outside the authorized
  design-only scope.

**Consequences:** Live readiness remains blocked with
`BLOCKED_LIVE_ADAPTER_NOT_IMPLEMENTED`. Future implementation must add an
audited composition root that creates the sentinel internally, prove exact
instance and driver-node identity before mutation, and keep read-only probes
separate from mutation authority.

## 2026-07-03 - Do not treat PowerShell object possession as native mutation authority

**Decision:** Native adapter mutation authorization must not be represented by
any caller-supplied PowerShell capability, token, sentinel, secret, object, or
equivalent value accepted by a public/exported function. Public native adapter
gate functions may classify, plan, validate, and reject, but they must not
accept an object that can activate a mutation-authorized path.

**Rationale:** Independent audit showed that module script-scope variables are
not private from same-process callers. A caller can inspect imported module
session state, recover the exact object reference, and pass it back to a
reference-equality gate. Same-process PowerShell module state, module-context
invocation, and function discovery are introspection surfaces, not security
boundaries.

**Alternatives rejected:** Renaming the sentinel, moving it to another
script-scope variable, replacing it with another object/string/GUID/secure
string/custom type, adding wrapper or reference-equality layers, relying on
callers not using `Get-Module` or module session state, or suppressing only the
specific audit probe.

**Consequences:** The native adapter operation gate no longer has a
`Capability` parameter and always remains blocked while the native adapter is
unimplemented. G16-G25 permanently cover module-state extraction,
module-context invocation, non-exported function discovery, wrapper/object
spoofing, serialization, scalar values, legacy capability parameters, exported
API shape, and zero mutation counters. The gate is
`BLOCKED_PENDING_INDEPENDENT_REAUDIT` until independent re-audit accepts the
remediation.

## 2026-07-03 - Treat native adapter composition root as wiring, not authority

**Decision:** The production native adapter composition root may select stable
adapter metadata and map operations to deterministic blocked results, but it
must not be treated as authorization, a security boundary, or evidence that
native SetupAPI/Newdev execution exists.

**Rationale:** The accepted capability-boundary remediation established that
PowerShell object possession and module state are not trustworthy authorization
mechanisms. The next useful production scaffold is therefore explicit
dependency selection and result mapping, while native interop remains absent
and independently auditable.

**Alternatives rejected:**

* Reintroduce a private mutation sentinel inside the composition root - same
  PowerShell trust-boundary defect as the rejected capability model.
* Auto-fallback from production to synthetic adapter - would blur production
  identity and test identity.
* Add a native declaration or P/Invoke stub now - outside the authorized
  non-live scaffold scope.

**Consequences:** The production adapter identity is
`chatpad-windows-exact-instance-adapter-v1`, recognized operations return
`BLOCKED_NATIVE_ADAPTER_EXECUTION_NOT_IMPLEMENTED`, and the final readiness
gate is `BLOCKED_PENDING_INDEPENDENT_NATIVE_ADAPTER_SCAFFOLD_AUDIT` until an
independent scaffold audit accepts the wiring.
