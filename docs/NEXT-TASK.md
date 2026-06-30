# Next Task

## Current continuation point

Branch `feature/offline-inf2cat-package-validation` records completed unsigned
offline package/catalog closure for the exact validated extension INF and
unsigned Release SYS. The checkpoint report is
[Offline Inf2Cat Package Validation](OFFLINE-INF2CAT-PACKAGE-VALIDATION.md).

InfVerif static validation, Inf2Cat package closure, and repository safety pass.
The independent audit result is **AUDIT PASS WITH LIMITATIONS** because it
inspected retained evidence without rerunning historical tools. Generated
package evidence remains ignored and untracked.

## Recommended objective

Conduct an independent read-only review of the unsigned package-closure report
and recovery prerequisites. Resolve review questions before deciding whether a
separate signing-policy design task should be authorized.

This continuation point does not authorize signing, certificate operations,
staging, installation, loading, device access, or runtime integration.

## Required branch and starting commit

- Start from the final pushed
  `feature/offline-inf2cat-package-validation` documentation checkpoint.
- Require local HEAD to equal
  `origin/feature/offline-inf2cat-package-validation`.
- Require a clean tracked tree and index.
- Require prohibited commit `6502452` not to be an ancestor.

## Preconditions

- Re-read `AGENTS.md`, `docs/PROJECT-STATE.md`, this file, the package
  validation report, and the installation/recovery design.
- Verify retained evidence paths remain ignored and untracked.
- Treat historical command/timing claims as retained-log evidence unless a
  separate task explicitly authorizes repetition.

## Safety restrictions

- Read-only documentation and evidence review only.
- No generated package, CAT, SYS, certificate, key, binary, or log may be
  tracked.
- No Inf2Cat, InfVerif, build, signing, certificate, trust-store, Secure
  Boot/HVCI/BCD, staging, Driver Store, registry, service, installation, load,
  device restart, elevation, network, or hardware action.
- Do not modify `legacy/`, runtime driver behavior, or retained evidence.

## Acceptance criteria

- Review distinguishes static INF validity from offline package closure.
- Review distinguishes package closure from signing trust and Windows
  staging/installation acceptance.
- All runtime, attachment, controller-preservation, and Chatpad behavior claims
  remain explicitly unproven.
- Tracked state remains documentation-only and generated evidence remains
  ignored.

## Inspect first

- `docs/OFFLINE-INF2CAT-PACKAGE-VALIDATION.md`
- `docs/WINDOWS11-DEVICE-FILTER-INSTALL-RECOVERY.md`
- `docs/PROJECT-STATE.md`
- `artifacts/inf2cat-validation/20260629T220548Z/`
- `artifacts/inf-validation/20260629T220549Z/`
