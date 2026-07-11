# Next Task

## Exact current state

- Branch: `feature/native-adapter-local-development-package-route`.
- Starting commit: `11d1053db4fd35f9515c6884953057f2687385fb` (`build: freeze unsigned canonical live apply package`).
- Expected single remediation commit subject: `fix: define local development package route`; use the exact committed hash after finalization.
- Deployment scope: `LOCAL_DEVELOPMENT_ONLY`; production distribution signing is optional future work and `OUT_OF_SCOPE_FOR_CURRENT_LOCAL_DEVELOPMENT_OBJECTIVE`.
- Canonical SYS: `ChatpadFilter.sys`, 40,960 bytes, SHA-256 `E4E7BCA837F6B0C662A24CFDDC260D781FDA85E0B37CAE470D65A9716DB174BB`, unsigned.
- Canonical INF: 1,581 bytes, SHA-256 `0200FCF5E1B26F4A594ECEF936DAAEC4B8F2BC5743A9DDAE212AD8F99D05E2FC`.
- Canonical CAT: `ChatpadFilterExtension.cat`, 1,202 bytes, SHA-256 `6F0ABF84AE68010008A0360D4DDF716E644DD8D63E669F3AA96F27047EF613FD`, unsigned.
- Package state: unstaged, uninstalled, unloaded, and not independently audited. Local installation method and signature-enforcement state are `NOT_YET_OBSERVED`; no published INF, driver-store identity, rank, or candidate has been observed.
- Blocker: `BLOCKED_NATIVE_ADAPTER_LOCAL_DEVELOPMENT_PACKAGE_NOT_INDEPENDENTLY_AUDITED_AND_LOCAL_INSTALLATION_PATH_NOT_OBSERVED`.
- No live authorization phrase is active or carried forward.

## Next recommended objective

TASK 8I-P1B-LD-R2 — Independent read-only audit of the unsigned canonical package and local-development deployment contract.

## Required branch and starting commit

- Start from the pushed `feature/native-adapter-local-development-package-route` commit whose parent is `11d1053db4fd35f9515c6884953057f2687385fb` and subject is `fix: define local development package route`.
- Require a clean worktree, upstream `0/0`, and exact remote identity before audit work.

## Preconditions and audit scope

- Re-derive the result from Git and file contents; do not trust the completion report.
- Verify the exact SYS/INF/CAT identities, package membership, unsigned states, frozen source/build provenance, local-only deployment policy, 28-field future observation inventory, candidate-selection fail-closed rules, focused validator coverage, readiness entry count, and zero operational counters.
- Keep the repository immutable during the independent audit unless a separate remediation task is explicitly authorized.

## Safety restrictions

- Read repository files and the exact canonical artifact root only. Do not build, regenerate the catalog, sign, create/install certificates, access private keys, change BCD or Secure Boot, stage/install the INF, invoke `pnputil`, `devcon`, SetupAPI, or Newdev, query devices/driver store/registry/services, load, bind, restart, issue/consume authorization, execute the native bridge, or mutate Windows.
- Do not infer a local installation method, test-signing state, signature-enforcement state, published INF, driver-store package, driver rank, or matching candidate from prior operator experience.

## Acceptance criteria

- The package and build provenance remain unchanged and the local-development contract is internally consistent across source plan, evidence, unsigned plan, readiness manifest, validators, and continuity documents.
- WHCP/HLK and Partner Center are optional future distribution work, not current blockers or next steps.
- The package remains explicitly unsigned, unstaged, uninstalled, unloaded, and not claimed ordinarily production-loadable.
- The exact blocker and next task are present, validators pass in PowerShell 7 and Windows PowerShell 5.1, readiness reports 57 entries and zero defects, and all prohibited counters remain zero.
- Only after LD-R2 passes, recommend a separate read-only host-readiness observation to determine the exact known-working local installation path; do not stage or install in the audit.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
git ls-remote origin refs/heads/feature/native-adapter-local-development-package-route
pwsh -NoProfile -File tools/Test-ChatpadLiveApplyPackageSourceContract.ps1 -UnsignedPackage
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/Test-ChatpadLiveApplyPackageSourceContract.ps1 -UnsignedPackage
```
