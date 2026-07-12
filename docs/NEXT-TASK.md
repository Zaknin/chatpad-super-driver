# Next Task

## Exact current state

- Branch: `feature/native-adapter-local-host-readiness-observation`.
- Starting commit for continuation: the pushed commit with parent `c70d1b94c9fdc14de598df8326b6e0e912dc811d` and subject `docs: record local driver signing host readiness`; derive its exact hash from Git.
- Status: `LOCAL_DEVELOPMENT_HOST_READINESS_OBSERVED_TESTSIGNING_CONFIGURED_REBOOT_PENDING_HVCI_ACTIVE_PACKAGE_UNSIGNED_UNSTAGED_UNINSTALLED_UNLOADED`.
- Readiness: `READY_FOR_SELF_TEST_SIGNED_LOCAL_DEVELOPMENT_PACKAGE_PREPARATION_ONLY`.
- Host evidence: `docs/evidence/local-development-host-readiness-observation-task-8i-p1b-ld-o1.json`, 8,467 bytes, SHA-256 `019D59504588384DDD48B90B2315A261AE891030113C7953DF6EA2778F3E651C`.
- Secure Boot is disabled; BitLocker protection is off; HVCI is active. TESTSIGNING is configured in BCD, but no reboot occurred after configuration and effective current-boot Test Mode remains `NOT_CONCLUSIVELY_OBSERVED`.
- Canonical package remains unsigned, unstaged, uninstalled, and unloaded. No test certificate or trust installation exists.
- Blocker: `BLOCKED_NATIVE_ADAPTER_SELF_TEST_SIGNED_PACKAGE_NOT_CREATED_AND_CONFIGURED_TESTSIGNING_NOT_EFFECTIVE_UNTIL_REBOOT`.

## Next recommended objective

TASK 8I-P1B-LD-S1 — Create and freeze the self-test-signed local-development package.

## Preconditions

- Require the exact pushed O1B commit, clean worktree, upstream `0/0`, and matching remote identity.
- Preserve the canonical unsigned INF/SYS/CAT inputs and their recorded hashes.
- Use the accepted host-readiness evidence as the only host-fact source; do not repeat host observation.
- Define fixed certificate identity, bounded creation/trust scope, embedded SYS signing, catalog regeneration/signing, and deterministic package evidence before any reboot or installation.

## Safety restrictions

- Do not reboot during package preparation. Do not change or repeat BCD configuration, disable HVCI, stage/install the INF, query devices or driver store, load/bind the driver, or execute native APPLY.
- Certificate creation, private-key handling, trust installation, SYS/CAT signing, or other host mutation requires exact separate authorization if not explicitly included in the S1 task.
- Keep local installation method, published INF, driver-store package, candidate fields, target device, service/filter result, rollback identity, and restoration verification unobserved.

## Acceptance criteria

- Freeze an internally consistent self-test-signed local-development package plan and exact package identities while retaining HVCI compatibility and the embedded SYS signature requirement.
- Preserve the current-boot/next-boot distinction: configured TESTSIGNING is not yet effective until a later controlled reboot and verification.
- Do not claim readiness for trust installation, reboot verification, staging, installation, loading, binding, or native APPLY.

## Inspect first

```powershell
git branch --show-current
git rev-parse HEAD
git status --short --branch
git ls-remote origin refs/heads/feature/native-adapter-local-host-readiness-observation
Get-FileHash docs/evidence/local-development-host-readiness-observation-task-8i-p1b-ld-o1.json -Algorithm SHA256
```
