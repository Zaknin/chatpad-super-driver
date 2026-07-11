# Next Task

## Exact current state

- Branch: `feature/native-adapter-live-apply-package-build`.
- Starting package-source commit: `4510e1f2f8a4b4e31ac40672261cf4ad94ec27c5`.
- Expected single build commit subject: `build: freeze unsigned canonical live apply package`; use the exact committed hash from Git after finalization.
- Unsigned SYS: `ChatpadFilter.sys`, 40,960 bytes, SHA-256 `E4E7BCA837F6B0C662A24CFDDC260D781FDA85E0B37CAE470D65A9716DB174BB`.
- Canonical INF: 1,581 bytes, SHA-256 `0200FCF5E1B26F4A594ECEF936DAAEC4B8F2BC5743A9DDAE212AD8F99D05E2FC`.
- Unsigned CAT: `ChatpadFilterExtension.cat`, 1,202 bytes, SHA-256 `6F0ABF84AE68010008A0360D4DDF716E644DD8D63E669F3AA96F27047EF613FD`.
- Package status: built and cataloged, unsigned, not production-signed, not staged, not installable, not independently audited.
- Blocker: `BLOCKED_NATIVE_ADAPTER_CANONICAL_DRIVER_PACKAGE_NOT_PRODUCTION_SIGNED_AND_INDEPENDENTLY_AUDITED`.
- No live authorization phrase is active or carried forward.

## Next recommended objective

TASK 8I-P1B-2B — Obtain and validate the externally production-signed canonical Windows 11 driver package.

## Required branch and starting commit

- Start from the pushed `feature/native-adapter-live-apply-package-build` commit whose parent is `4510e1f2f8a4b4e31ac40672261cf4ad94ec27c5` and subject is `build: freeze unsigned canonical live apply package`.
- Require a clean worktree, upstream `0/0`, and exact remote identity before changes.

## Preconditions

- Read `AGENTS.md`, the four continuity documents, and the latest worklog entry.
- Validate `docs/evidence/canonical-live-apply-package-build-task-8i-p1b-2a.json` and `tools/ExactInstance/contracts/chatpad-live-apply-unsigned-package-plan.json` in both PowerShell runtimes.
- Match the external lab handoff to the frozen INF, SYS, CAT, and build-A PDB identities.
- Require an externally created and EV-signed WHCP/HLK `.hlkx` submission from an authorized lab; do not substitute attestation or test signing.

## Safety restrictions

- Do not stage, install, bind, load, query devices or the driver store, invoke SetupAPI/Newdev, execute the TASK 8I native path, issue/consume authorization, restart, re-enumerate, roll back, restore, or mutate Windows.
- Do not create/install certificates, access private keys, enable test mode, change boot configuration or Secure Boot, or accept a test-signed package.
- Portal access and external coordination require explicit authorization and credentials outside this repository task.

## Acceptance criteria

- Returned INF and SYS match the frozen pre-sign identities unless authoritative WHCP evidence explicitly proves and explains an allowed transformation.
- Returned catalog replaces the unsigned catalog, covers exactly the frozen INF and SYS member identities, and passes Microsoft production signer, chain, EKU, and kernel-policy verification.
- Freeze the returned signed hashes, signer/chain evidence, WHCP submission identity, and independent audit boundary without claiming staging or live candidate readiness.
- Keep every staging, installation, native, device, binding, authorization, and Windows-mutation counter at zero.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
git ls-remote origin refs/heads/feature/native-adapter-live-apply-package-build
pwsh -NoProfile -File tools/Test-ChatpadLiveApplyPackageSourceContract.ps1 -UnsignedPackage
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test-ChatpadLiveApplyPackageSourceContract.ps1 -UnsignedPackage
```
