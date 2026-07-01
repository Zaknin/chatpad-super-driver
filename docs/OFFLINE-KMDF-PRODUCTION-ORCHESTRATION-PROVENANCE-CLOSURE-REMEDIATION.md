# Offline KMDF Production Orchestration Provenance Closure Remediation

> Independent audit result: **FAIL for remaining provenance completeness**.
> Production source was not defective, but the schema-`1.5.0` checkpoint did
> not yet include the final independent raw-TLOG validator source binding,
> exact-root negative-test evidence, PDB binding inventory, and complete
> final-remediation guard coverage. Acceptance is superseded by
> [Offline KMDF Production Orchestration Provenance Final Remediation](OFFLINE-KMDF-PRODUCTION-ORCHESTRATION-PROVENANCE-FINAL-REMEDIATION.md).

## Purpose and Scope

This evidence-only checkpoint closes the independent provenance audit defects in commit `499f6eae4b0e8a6fd4dbf3186c44906b5e6d4201`. Production implementation `efb729502a0527ac70e2d20fa31a323c3beb2920` remains frozen. No runtime, target/request, signing, packaging, installation, loading, or hardware behavior is added or exercised.

## Contracts

- Production runtime/link contract: 26 tracked paths. It covers `ChatpadFilter`, its linked context library, direct tracked source/header/build inputs, and one explicitly packaging-only prototype INF.
- A/B wrapper-build contract: 32 tracked paths. It covers every repository input consumed by the accepted wrapper, including `ChatpadProtocol.vcxproj`, `ChatpadActivationExecutor.c`, `ChatpadKeyboardParser.c/.h`, `ChatpadProtocolStateMachine.c/.h`, and `ChatpadProtocolTypes.h`.

Both contracts bind every path to implementation commit, Git blob, SHA-256, role, consuming project, configuration, classification, four-set presence, and supporting retained TLOG reference.

## Frozen Producer and Generation

- Producer: `tools/New-ChatpadProductionOrchestrationAbProvenanceEvidence.ps1`
- Size: 111,989 bytes
- SHA-256: `17AD4A2F409147E93BD7D85F2F12FA637AB305B5FF51C882A23CBE2134F96688`
- Git blob: `0c6926804a6ee8bffa5f58d1193d23eb59682d10`
- Freeze UTC: `2026-07-01T15:07:39.6032226Z`
- Final identity verification UTC: `2026-07-01T15:09:15.9740485Z`

The producer has LF-only endings, exactly one final newline, and no EOF whitespace defect. Producer and contract identities pass before clean, before build, after capture, and after all four sets.

## Retained Evidence Results

Each Debug A/B and Release A/B set has a disjoint root and retains:

- 22 exactly enumerated raw TLOGs;
- 15 generated object copies;
- 2 emitted generated library copies;
- the final SYS/PDB and offline PE, symbol, import, disassembly, WDF, retention, and absence evidence;
- complete build transcript and input inventory.

Debug parser totals are 684 raw records, 662 parsed nonempty records, and 22 retained empty records per set. Release totals are 688, 666, and 22. Unparseable, discarded, and unexplained records are zero.

Every object has one primary compile source plus retained CL command/read/write provenance. Both generated libraries are hash- and producer-bound. The `ChatpadFilter.lib` command-line path is explicitly classified as a declared import-library path not emitted because the driver exports no symbols; it is neither a generated nor consumed library. All same-set producer, consumer, external-identity, contamination, unproduced-path, and unexplained-output counters are zero.

## A/B Results

- Debug inputs: 130. Canonical B SHA-256: `9650D7059A8183E28B0CB883D61F63BD4C88DB62D8B613645D77B3514632D5B8`.
- Release inputs: 132. Canonical B SHA-256: `0A9AE86BE72EEE431462B4F9D943EF9A48718974AA6C4C5E7D8FCE9BDA18E643`.
- Debug normalized SHA-256: `18656A2A1EC059E1D84F353B386400D7B79E3C4C37B6407364609DEB09433E50`.
- Release normalized SHA-256: `F87A4B3FB662D245856104AFB53027502B54AAE2018A596491521160A98B9A6C`.

Input paths/hashes, commands, objects, generated libraries, external/toolchain identities, executable sections, imports, WDF references, retention boundaries, target/request and D0/removal absence, and Authenticode state match A/B. Raw hashes differ only in the documented PE metadata fields.

## Manifest, Guard, and Limitations

Manifest schema `1.5.0` declares 99 mandatory IDs and 99 entries. Full Debug and Release guards independently enforce contract identity, exact root enumeration, freshness, parser losslessness, retained bytes, object/library closure, same-set closure, complete transcripts, safety counters, and three-way mandatory-ID equality. Every explicit defect counter is zero.

The manifest cannot embed its own containing commit, and each Full transcript cannot validate its own final hash. Each Full run skips only its own changing hash; independent audit remains responsible for final commit, manifest, both Full logs, contracts, producer, evidence hashes, and clean synchronized state.

No production source, signing, packaging, certificate/key creation, installation, loading, Windows mutation, device query, hardware access, controller action, or Chatpad interaction occurred.
