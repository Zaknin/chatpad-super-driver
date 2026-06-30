# Next Task

## Current continuation point

Branch `feature/offline-inf2cat-package-validation` records completed unsigned
offline package/catalog closure and its documentation correction. The reviewed
package-validation documentation baseline is
`946f6feeb920e096663f757725ddb51ddd18a84d`.

See [Offline Inf2Cat Package Validation](OFFLINE-INF2CAT-PACKAGE-VALIDATION.md)
for the original validation and
[Offline Inf2Cat Checkpoint Review](OFFLINE-INF2CAT-CHECKPOINT-REVIEW.md) for
the later independent read-only review and corrected findings.

InfVerif proved static INF validity. Inf2Cat proved unsigned offline
package/catalog closure. The CAT remains unsigned and untrusted; Windows
acceptance, effective placement beneath `xusb22`, controller preservation,
Chatpad behavior, and a usable production driver remain unproven.

## Future objective selection

Two separate future technical paths are possible:

1. signing, recovery, and deployment-readiness design;
2. continued offline KMDF bridge/runtime implementation.

Neither path is selected or authorized by this file. A later task must name one
bounded objective and provide its own explicit authorization and stop boundary.

## Required branch and starting commit

- Use `feature/offline-inf2cat-package-validation` or an explicitly named
  descendant branch.
- Obtain the exact final starting commit from the external reviewed handoff, or
  verify it from the synchronized branch before work begins.
- Require local HEAD to equal the specified start and its upstream.
- Require a clean tracked tree and index.
- Require prohibited commit `6502452` not to be an ancestor.

The reviewed baseline above is historical review identity, not a
self-referential promise of the correction commit's final hash.

## Evidence availability

The retained directories
`artifacts/inf2cat-validation/20260629T220548Z/` and
`artifacts/inf-validation/20260629T220549Z/`, together with earlier retained
validation evidence such as
`artifacts/inf-validation/20260629T214908Z/`, are ignored, machine-local
evidence and are absent from a normal fresh clone.

If required retained evidence is absent, stop. Request a controlled evidence
handoff or a separately authorized regeneration/verification task. Do not
silently reconstruct, download, or trust missing evidence.

## Preconditions

- Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, this file, the package
  validation report, checkpoint review, and installation/recovery design.
- Verify the exact branch, start commit, upstream, clean state, and evidence
  availability required by the selected future task.
- Treat historical command/timing claims as retained-log evidence unless a
  separate task explicitly authorizes repetition.

## Safety restrictions

- No signing, certificate, trust-store, Secure Boot/HVCI/BCD, staging, Driver
  Store, registry, service, installation, driver loading, device restart,
  elevation, network, or hardware action without a later task explicitly
  authorizing that exact bounded stage.
- Target matching never authorizes attachment, restart, binding, or load.
- Driver loading never authorizes USB or Chatpad interaction.
- No generated package, CAT, SYS, certificate, key, binary, or log may be
  tracked.
- Do not modify `legacy/` or retained evidence.

## Acceptance criteria for the next authorized task

- Its exact branch, start commit, scope, authorization, and stop boundary are
  verified before work.
- It preserves the distinctions between static INF validity, unsigned offline
  package closure, signing trust, staging, post-staging package identity,
  target matching, attachment/load, passive observation, and active hardware
  interaction.
- It leaves all untested runtime and hardware claims explicitly unproven.

## Inspect first

- `docs/OFFLINE-INF2CAT-PACKAGE-VALIDATION.md`
- `docs/OFFLINE-INF2CAT-CHECKPOINT-REVIEW.md`
- `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md`
- `docs/PROJECT-STATE.md`
- the machine-local evidence directories, only when present and required
