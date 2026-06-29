# Decisions

Durable technical or workflow decisions only. Each entry includes date, decision, rationale, alternatives rejected, and consequences.

---

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
