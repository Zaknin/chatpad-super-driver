# Next Task

## TASK 8I-P1B-LD-S2 — Independent signed-package audit

### Exact current state

- Branch `feature/native-adapter-self-test-signed-package`; required starting commit is the single `build: finalize recovered self-test-signed package` child of `f0ca3a0e2c73aa1309812f94721f190fa7af835d` published on that branch.
- The ignored final package contains exact `ChatpadFilter.sys`, `ChatpadFilterExtension.cat`, and `ChatpadFilterExtension.inf`. The signed catalog has exact required casing, one signer, no timestamp, and exact INF/SYS membership.
- The public certificate is tracked; the private key remains only in the untrusted CurrentUser Personal certificate store and was not exported.
- Final evidence and contract record the unavailable generated-CAT pre-sign ordinary hash as `NOT_AVAILABLE` with reconstruction false.
- Readiness is `READY_FOR_SELF_TEST_SIGNED_PACKAGE_INDEPENDENT_AUDIT_ONLY`; staging, installation, loading, reboot, trust installation, device access, and native execution remain prohibited.

### Objective

Independently re-derive and audit the final signed-package identities, CAT CMS/Authenticode state and membership, public-CER metadata, evidence/contract agreement, exact cumulative counters, recovery-only source boundary, manifest binding, and the explicit pre-sign-identity limitation.

### Preconditions

- Verify exact branch, commit subject, parent `f0ca3a0e2c73aa1309812f94721f190fa7af835d`, changed-path inventory, and clean tracked state.
- Treat the final commit and filesystem contents as source of truth; do not trust this completion report without re-derivation.
- Require exactly one matching CurrentUser Personal certificate and no trusted-store copy before making any current certificate-state claim.

### Safety restrictions

- Audit only: no file edits, staging, commit, push, catalog regeneration, Inf2Cat, signing, certificate/private-key mutation or export, trust installation, BCD/security change, reboot, package staging/install/load, device/driver-store/candidate/service query, SetupAPI/Newdev invocation, native execution, binding, or live APPLY.
- Do not reconstruct or fabricate the unavailable raw pre-sign CAT hash.
- Do not treat TESTSIGNING configuration as effective current-boot Test Mode before the separately controlled reboot and verification task.

### Acceptance criteria

- Independently confirm every final file identity, signature/signer/timestamp fact, catalog member, public certificate field, evidence/contract/manifest binding, and recovery counter.
- Confirm CAT bytes and signature were unchanged by the two-step case-only rename.
- Confirm the limitation `RAW_PRE_SIGN_CATALOG_BYTE_IDENTITY_CANNOT_BE_INDEPENDENTLY_REPRODUCED_FROM_RETAINED_STATE` is explicit and no unsupported pre-sign hash exists.
- Report PASS/FAIL without modifying the repository. A later separately authorized task may design certificate trust, reboot, and post-boot verification only after S2 passes.

### Inspect first

```powershell
git branch --show-current
git rev-parse HEAD HEAD^
git show -s --format='%H%n%P%n%s' HEAD
git diff-tree --no-commit-id --name-status -r HEAD
git status --porcelain=v1 --untracked-files=all
pwsh -NoProfile -File .\tools\Test-ChatpadLocalDevelopmentTestSigning.ps1
```
