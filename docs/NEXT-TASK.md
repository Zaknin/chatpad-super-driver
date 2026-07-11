# TASK 8I-P1B-2 — Build, catalog, sign, validate, and freeze the canonical Windows 11 driver package and immutable APPLY candidate contract

## Exact current state

TASK 8F-R2 and TASK 8I-P1A-R2R1 passed as accepted read-only external audits; neither has a closure commit. TASK 8I-P1B-1-C1 defines and statically validates the canonical source package, but it is not built, cataloged, signed, staged, installable, or independently audited.

The canonical inputs are:

- production project `src/driver/ChatpadFilter/ChatpadFilter.vcxproj`;
- output name `ChatpadFilter.sys`;
- production INF `src/driver/ChatpadFilter/package/ChatpadFilterExtension.inf`;
- source plan `tools/ExactInstance/contracts/chatpad-live-apply-package-source-plan.json`;
- strict validator `tools/ExactInstance/ChatpadLiveApplyPackageSourceContract.psm1`;
- focused test `tools/Test-ChatpadLiveApplyPackageSourceContract.ps1`.

## Required branch and starting commit

- Branch: `feature/native-adapter-live-apply-package-source`.
- Starting commit: the commit with parent `e5c456efdf5d34863084be5558859a4884bd6a83` and subject `feat: define canonical live apply package source`; derive and verify the exact hash from Git.
- Require clean index/worktree, no untracked files, upstream `0/0`, and the remote branch resolving to the same commit.

## Preconditions

1. Independently audit the P1B-1-C1 source contract before treating it as an accepted build input.
2. Revalidate the canonical INF and every driver-source identity from the plan.
3. Select and document the Microsoft attestation or WHCP production signing route and required release authority.
4. Keep the accepted exact physical-node, lower-filter, `xusb22`-preservation, and candidate-selection rules unchanged.

## Safety restrictions

Do not stage, install, bind, load, restart, query the live device, invoke SetupAPI/Newdev, issue or consume live authorization, or mutate Windows. Do not enable test mode, change boot policy or Secure Boot, install temporary trust, or read private signing material outside a separately authorized signing boundary.

## Acceptance criteria

Produce and freeze the exact SYS, INF, and CAT byte identities; signer and signature-chain results; package date/version; provider/description/rank/node identity; SetupAPI package identity; exact one-match candidate result; restart/reboot policy; build provenance and tool versions; and reproducibility result. Keep zero- and multiple-match outcomes fail-closed. Preserve the prototype and P1A source identities.

## Inspect first

1. `AGENTS.md`
2. `docs/PROJECT-STATE.md`
3. `docs/DECISIONS.md`
4. this file
5. the latest `docs/WORKLOG.md` entry
6. `tools/ExactInstance/contracts/chatpad-live-apply-package-source-plan.json`
7. `tools/ExactInstance/ChatpadLiveApplyPackageSourceContract.psm1`
8. `src/driver/ChatpadFilter/package/ChatpadFilterExtension.inf`

TASK 8I remains blocked by `BLOCKED_NATIVE_ADAPTER_CANONICAL_DRIVER_PACKAGE_NOT_BUILT_CATALOGED_SIGNED_AND_INDEPENDENTLY_AUDITED`. Do not proceed to executor integration or live execution.
