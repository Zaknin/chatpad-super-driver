# Offline KMDF Production Orchestration Evidence Finalization

## Purpose

This evidence-only record now includes the input-identity remediation that
closed the final independent audit's two remaining findings: the incomplete
eight-file A/B input claim and mismatched A/B equivalence manifest metrics.
The remediation starts from finalization commit
`d22867f86917a6c81574b5f82d19aacd9984b213` and preserves implementation
commit `efb729502a0527ac70e2d20fa31a323c3beb2920` unchanged.

The containing remediation commit uses subject
`test: complete production orchestration input identity evidence` on branch
`feature/offline-kmdf-production-orchestration-input-identity-remediation`.
Its hash is obtained from Git after commit; it is not embedded here.

## Failed-Audit Findings

The second evidence audit did not find a production-source defect. It rejected
the prior checkpoint because:

1. the manifest did not independently declare the mandatory 42-ID set;
2. retention commands abbreviated paths and collapsed separate invocations;
3. KMDF semantic transcripts omitted explicit passed/total and warning/error
   counts;
4. repository-safety evidence omitted explicit signing, packaging,
   certificate-generation, and key-generation counters; and
5. the earlier binary pair was not retained, so its equivalence could not be
   independently reconstructed.

This checkpoint changes guards, manifest metadata, evidence, and continuity
documents only. It opens no runtime or deployment scope.

## Frozen Production Source

The production implementation remains exactly:

- implementation parent:
  `4ba0de15420e0b66287a501918de694c8b6fd720`;
- implementation commit:
  `efb729502a0527ac70e2d20fa31a323c3beb2920`; and
- production source:
  `src/driver/ChatpadFilter/device.c`.

The final A/B input proof no longer uses the rejected eight-file subset. It
uses a complete pre-build input inventory derived from actual build dependency
data:

- explicit solution/project/`Directory.Build.props` inputs;
- `ChatpadFilter` compiler and linker tracking logs;
- `ChatpadKmdfRequestOwnerContext` project-reference producer compiler and
  librarian tracking logs;
- consumed repo-local source/header inputs;
- external SDK/WDK/MSVC headers, libraries, and system reads; and
- toolchain executable identity and build command digests.

Generated repo-local `.obj` and `.lib` intermediates are accounted for through
their producer tlog closure rather than treated as pre-build source inputs.
The final retained inventories report 116 Debug inputs and 118 Release inputs,
with zero unresolved inputs and zero duplicate normalized paths.

## Manifest and Mandatory Evidence

The manifest schema is `1.3.0`. Its top level now declares the exact ordered
mandatory-ID array and count. The guard independently compares:

- its compiled mandatory set;
- the manifest top-level declaration; and
- the manifest evidence-entry IDs.

The final set contains 62 mandatory IDs and 62 unique evidence paths. The
original 42 remain, and 20 dedicated A/B IDs cover four builds, four complete
input inventories, two input comparisons, four binary inspections, four
retention inspections, and two equivalence reports.

The guard requires exactly one populated `command` or `commands` property per
entry and compares the manifest value to the transcript literally, except for
line-ending trimming.

## Exact Retention Commands

Debug and Release retention evidence each records five ordered invocations:

1. `dumpbin.exe /SYMBOLS` against the configuration-specific
   `ChatpadKmdfRequestOwnerContext.obj`;
2. `dumpbin.exe /DISASM` against the exact retained SYS;
3. `dumpbin.exe /SYMBOLS` against that SYS;
4. `dumpbin.exe /IMPORTS` against that SYS; and
5. `Get-Content` against the configuration-specific
   `link.command.1.tlog`.

Every manifest `commands` array preserves the executable name, complete
repository-relative quoted path, arguments, configuration, and order.
Separate invocations are not represented as one pseudo-command.

## KMDF Semantic Metrics

Dedicated Debug and Release semantic transcripts report:

| Configuration | Passed | Total | Warnings | Errors | Build exit | Guard exit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Debug | 62 | 62 | 0 | 0 | 0 | 0 |
| Release | 62 | 62 | 0 | 0 | 0 | 0 |

The production orchestration guard parses these lines, requires a positive
total, requires passed to equal total, and cross-checks the manifest counts.
The entries point to semantic/build transcripts, not compile-only logs.

## Repository-Safety Counters

The dedicated repository-safety transcript identifies the exact command,
non-deployment execution mode, starting commit, finalization branch, and UTC
time. It reports zero for:

- deployment actions;
- signing actions;
- packaging actions;
- certificate creation;
- key creation;
- Windows mutation;
- device queries;
- hardware access;
- unexpected tracked artifacts;
- tracked evidence files; and
- non-ignored evidence files.

It also reports `ExitCode=0` and `Result=PASS`. The guard requires every
counter and rejects a missing or nonzero value.

## Historical Binary Limitation

The earlier implementation-checkpoint binaries were not retained. Their
reported hashes remain historical observations:

- Debug:
  `826700E0556840D79D5A18A6C7CFA739FAF8ADEC6A9A3CF37F544187FBEAA821`;
- Release:
  `D0983260B9CAD00CD72EE3F2AE4697110AA5C13DF01F7BC2B39C0FEF891F4CB3`;
- first-remediation Debug:
  `DD33388A3905A4C5AFCFD3FF4E3443308CC9A280BCDD094FB7ACED7478880F83`;
  and
- first-remediation Release:
  `72B30B0523B07F91A21FE8711ED846F4B355652F0E2B0FEA691F894A4304CAC5`.

Those earlier files and raw inspection outputs are no longer available for
independent byte or semantic comparison. Their exact equivalence to later
binaries cannot be retroactively proven. Acceptance therefore relies on the
new retained complete-input-identity A/B experiment, not inference about the
historical pair.

## Retained A/B Rebuild

The accepted Community/WDK toolchain produced clean Debug A, Release A, Debug
B, and Release B builds from complete tlog-derived pre-build input closures.
The evidence root is:

`artifacts/logs/production-orchestration-ab-rebuild/`

That ignored directory retains:

- all four exact build transcripts;
- four machine-readable complete input inventories;
- two A/B input-comparison logs;
- all four SYS files;
- matching PDB files used only to capture comparable symbolized disassembly;
- PE headers, imports, raw and normalized hashes for all four binaries;
- complete context symbols, driver symbols, disassembly, imports, and link
  commands for all four binaries; and
- one equivalence transcript per configuration.

No binary, PDB, dump, or log is tracked.

## Normalization Rules

Normalization zeroes only:

- `COFF.TimeDateStamp`;
- `OptionalHeader.CheckSum`;
- `DebugDirectory.TimeDateStamp`; and
- `CodeView.RSDS.Guid`.

The A/B experiment demonstrates that these are the only differing fields. The
PE checksum is derived from the image, timestamps are linker/debug metadata,
and the CodeView GUID identifies a particular PDB build. No executable field,
section metadata, import, symbol, disassembly instruction, retention result,
target/request-absence result, or signature field is excluded.

## A/B Results

| Configuration | Set | Size | Raw SHA-256 | Normalized PE SHA-256 |
| --- | --- | ---: | --- | --- |
| Debug | A | 32,256 | `9973846C71C7A934535849357C98302377F479A317EBA82305C912B109AE6F72` | `18656A2A1EC059E1D84F353B386400D7B79E3C4C37B6407364609DEB09433E50` |
| Debug | B | 32,256 | `F05357700DCC71125CFA2583867B422E2E8E5A8E26FD3FA0AFCE5370AF5F8D7B` | `18656A2A1EC059E1D84F353B386400D7B79E3C4C37B6407364609DEB09433E50` |
| Release | A | 20,480 | `5684A05AF1B5568F20F47A0D470E5FCF44FEA778CF28F802A778C814E99F9815` | `F87A4B3FB662D245856104AFB53027502B54AAE2018A596491521160A98B9A6C` |
| Release | B | 20,480 | `5313E60CB503EBB4FA129D21CB26E1832E32FDE7E1F923D5C8E802D1D74D3905` | `F87A4B3FB662D245856104AFB53027502B54AAE2018A596491521160A98B9A6C` |

Debug differs in 22 raw bytes and Release differs in 22. For each
configuration:

- A/B input path sets, input hashes, build configuration digests, and
  toolchain identity digests match;
- size, x64 machine, and Native subsystem match;
- section names, virtual sizes, raw sizes, and characteristics match;
- normalized PE and normalized section hashes match;
- executable-section raw hashes match without normalization;
- imports and WDF function-table evidence match;
- normalized symbol and disassembly hashes match;
- orchestration, helper, rollback, and validator retention boundaries match;
- target/request-operation evidence remains absent; and
- Authenticode remains `NotSigned`.

Any executable-section or retention difference would have blocked acceptance.

## Canonical Candidate

Set B is the final canonical pair:

- Debug: 32,256 bytes,
  `F05357700DCC71125CFA2583867B422E2E8E5A8E26FD3FA0AFCE5370AF5F8D7B`;
  and
- Release: 20,480 bytes,
  `5313E60CB503EBB4FA129D21CB26E1832E32FDE7E1F923D5C8E802D1D74D3905`.

Both are x64 Native images and `NotSigned`.

## Validation Matrix

- Production orchestration SourceOnly: PASS in Debug and Release.
- Production orchestration Full: PASS in Debug and Release with 62 guard,
  declaration, and entry IDs; zero missing, unexpected, duplicate, metadata,
  path, or non-self hash defects.
- KMDF semantic/build guard: PASS 62/62 with zero warnings/errors in Debug and
  Release.
- Repository safety: PASS with all action and containment counters zero.
- A/B builds: PASS for Debug A/B and Release A/B.
- A/B input identity: PASS with Debug 116/116 inputs and Release 118/118
  inputs, zero missing, extra, hash mismatch, unresolved, duplicate,
  configuration mismatch, or toolchain mismatch counts.
- A/B PE and retained behavior comparison: PASS for Debug and Release.
- Immutable implementation scope and whitespace checks: PASS.
- Existing request-owner, protocol, transport, lifecycle, control-setup,
  compatibility, Community solution, and expected Build Tools baseline
  evidence remains retained; it was not weakened or recast as a fresh run.

## Self-Reference Limitation

A Full guard transcript cannot validate its own final hash while it is being
written. Each Full run validates all metadata and every non-self evidence hash,
then names its one skipped self hash. The final independent audit must rehash
both committed Full transcript entries.

Staged and candidate evidence similarly records its exact capture point and
does not claim to describe later insertions of its own hash, final Full hashes,
or worklog closeout.

## Remaining Limitations and Safety

The driver has not been loaded. `EvtDeviceAdd` and dormant WDF object creation
have not executed at runtime. No target discovery, request formatting,
submission, completion, cancellation, D0/removal owner observation, signing,
package creation, certificate/key creation, staging, installation, Windows
mutation, device query, USB/XUSB/controller access, or Chatpad interaction
occurred.

The next task is an independent read-only audit of the frozen implementation,
this input-identity remediation checkpoint, schema-`1.3.0` manifest, all 62
ignored evidence files, containing commit, and final upstream state.
