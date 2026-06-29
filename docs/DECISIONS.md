# Decisions

Durable technical or workflow decisions only. Each entry includes date, decision, rationale, alternatives rejected, and consequences.

---

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
